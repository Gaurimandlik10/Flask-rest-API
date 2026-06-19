variable "region" {
  default = "ap-southeast-2"
}

variable "db_password" {
  description = "RDS PostgreSQL password. Pass via -var, TF_VAR_db_password, or CI secret - never commit a real value."
  type        = string
  sensitive   = true
  default     = "MyPassword123"
}

