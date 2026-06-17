import os
import logging
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy.exc import OperationalError

# ──────────────────────────────────────────────
# App & DB setup
# ──────────────────────────────────────────────
app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# DB credentials are injected as env vars from K8s Secrets / ConfigMap
DB_USER     = os.environ.get("DB_USER",     "postgres")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "postgres")
DB_HOST     = os.environ.get("DB_HOST",     "localhost")
DB_PORT     = os.environ.get("DB_PORT",     "5432")
DB_NAME     = os.environ.get("DB_NAME",     "studentsdb")
ENV         = os.environ.get("APP_ENV",     "development")   # staging | production

DATABASE_URL = (
    f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
)

app.config["SQLALCHEMY_DATABASE_URI"]        = DATABASE_URL
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)


# ──────────────────────────────────────────────
# Model
# ──────────────────────────────────────────────
class Student(db.Model):
    __tablename__ = "students"

    id     = db.Column(db.Integer, primary_key=True)
    name   = db.Column(db.String(120), nullable=False)
    email  = db.Column(db.String(200), unique=True, nullable=False)
    course = db.Column(db.String(120), nullable=False)

    def to_dict(self):
        return {
            "id":     self.id,
            "name":   self.name,
            "email":  self.email,
            "course": self.course,
        }


# ──────────────────────────────────────────────
# DB migration hook  (also called by initContainer)
# ──────────────────────────────────────────────
def run_migrations():
    """Create tables if they don't exist (lightweight migration)."""
    with app.app_context():
        db.create_all()
        logger.info("Database tables verified / created.")


# ──────────────────────────────────────────────
# Health check  –  used by K8s readinessProbe
# Responds 200 only when the DB connection is live
# ──────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    try:
        db.session.execute(db.text("SELECT 1"))
        db_status = "connected"
        status_code = 200
    except OperationalError as exc:
        logger.error("Health-check DB error: %s", exc)
        db_status = "disconnected"
        status_code = 503

    return jsonify({
        "status":      "healthy" if status_code == 200 else "unhealthy",
        "database":    db_status,
        "environment": ENV,
    }), status_code


# ──────────────────────────────────────────────
# Students – CRUD
# ──────────────────────────────────────────────

# CREATE
@app.route("/students", methods=["POST"])
def create_student():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"error": "Request body must be JSON"}), 400

    required = {"name", "email", "course"}
    missing  = required - data.keys()
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    if Student.query.filter_by(email=data["email"]).first():
        return jsonify({"error": "Email already registered"}), 409

    student = Student(
        name=data["name"].strip(),
        email=data["email"].strip().lower(),
        course=data["course"].strip(),
    )
    db.session.add(student)
    db.session.commit()
    logger.info("Created student id=%s", student.id)
    return jsonify(student.to_dict()), 201


# READ ALL
@app.route("/students", methods=["GET"])
def get_students():
    students = Student.query.order_by(Student.id).all()
    return jsonify([s.to_dict() for s in students]), 200


# READ ONE
@app.route("/students/<int:student_id>", methods=["GET"])
def get_student(student_id):
    student = Student.query.get_or_404(student_id, description="Student not found")
    return jsonify(student.to_dict()), 200


# UPDATE
@app.route("/students/<int:student_id>", methods=["PUT"])
def update_student(student_id):
    student = Student.query.get_or_404(student_id, description="Student not found")
    data = request.get_json(silent=True) or {}

    if "name"   in data:
        student.name   = data["name"].strip()
    if "email"  in data:
        existing = Student.query.filter_by(email=data["email"].strip().lower()).first()
        if existing and existing.id != student_id:
            return jsonify({"error": "Email already in use"}), 409
        student.email  = data["email"].strip().lower()
    if "course" in data:
        student.course = data["course"].strip()

    db.session.commit()
    logger.info("Updated student id=%s", student_id)
    return jsonify(student.to_dict()), 200


# DELETE
@app.route("/students/<int:student_id>", methods=["DELETE"])
def delete_student(student_id):
    student = Student.query.get_or_404(student_id, description="Student not found")
    db.session.delete(student)
    db.session.commit()
    logger.info("Deleted student id=%s", student_id)
    return jsonify({"message": f"Student {student_id} deleted"}), 200


# ──────────────────────────────────────────────
# Entry-point
# ──────────────────────────────────────────────
if __name__ == "__main__":
    run_migrations()          # safe to call here for local dev
    app.run(host="0.0.0.0", port=5000, debug=(ENV == "development"))