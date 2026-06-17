FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


FROM python:3.12-slim
WORKDIR /app

# Comment moved to its own line - Dockerfiles treat "# ..." after an
# instruction as extra arguments, not a comment, which broke the build.
# Copies only the installed packages from the builder stage.
COPY --from=builder /install /usr/local
COPY . .

# Run as non-root
RUN useradd --create-home --shell /bin/bash appuser
USER appuser

CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
