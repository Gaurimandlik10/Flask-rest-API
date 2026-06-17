resource "aws_security_group" "rds_sg" {
  name        = "rds_security_group"
  description = "Allows Postgres access from inside the VPC only"
  vpc_id      = aws_vpc.proj4_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.proj4_vpc.cidr_block]   # was 0.0.0.0/0 on all ports - scoped to the VPC + the DB port only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rds_sg" }
}

resource "aws_db_subnet_group" "main" {
  name       = "main_db_subnet_group"
  subnet_ids = [aws_subnet.proj4_subnet_1.id, aws_subnet.proj4_subnet_2.id]   # needs subnets in 2+ AZs

  tags = {
    Name = "main-db-subnet-group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier     = "flask-postgres-db"
  engine         = "postgres"
  engine_version = "15.3"
  instance_class = "db.t3.micro"
  allocated_storage = 20

  db_name  = "flaskdb"
  username = "postgres"
  password = var.db_password

  db_subnet_group_name  = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot = true
  publicly_accessible = false

  backup_retention_period = 7
  deletion_protection     = false

  tags = {
    Name        = "flask-postgres-db"
    Environment = "production"
  }
}
