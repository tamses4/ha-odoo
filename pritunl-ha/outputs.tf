output "alb_dns_name" {
  description = "DNS du Load Balancer (accès à l'UI Pritunl)"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID de l'ALB (pour Route53)"
  value       = aws_lb.main.zone_id
}

output "rds_endpoint" {
  description = "Endpoint RDS PostgreSQL"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "s3_bucket_name" {
  description = "Nom du bucket S3 des configs"
  value       = aws_s3_bucket.configs.id
}

output "lambda_function_name" {
  description = "Nom de la fonction Lambda"
  value       = aws_lambda_function.processor.function_name
}

output "vpc_id" {
  description = "ID du VPC"
  value       = aws_vpc.main.id
}

output "nat_gateway_ip" {
  description = "IP publique du NAT Gateway"
  value       = aws_eip.nat_a.public_ip
}

output "pritunl_access_url" {
  description = "URL d'accès à l'interface Pritunl"
  value       = "https://${aws_lb.main.dns_name}"
}
