output "aws_vpc_id" {
  value = aws_vpc.proj4_vpc.id
}

output "aws_subnet_1_id" {
  value = aws_subnet.proj4_subnet_1.id
}

output "aws_subnet_2_id" {
  value = aws_subnet.proj4_subnet_2.id
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_name" {
  value = module.eks.cluster_name
}

output "namespaces" {
  value = [for ns in kubernetes_namespace.namespaces : ns.metadata[0].name]
}

output "rds_endpoint" {
  value     = aws_db_instance.postgres.address
  sensitive = true
}

output "rds_db_name" {
  value = aws_db_instance.postgres.db_name
}

output "rds_username" {
  value     = aws_db_instance.postgres.username
  sensitive = true
}
