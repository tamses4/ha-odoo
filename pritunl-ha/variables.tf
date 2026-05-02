variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI ID (get from AWS console for your region)"
  type        = string
  # Example eu-west-1: ami-0905a3c97561e0b69
  # Find yours: aws ec2 describe-images --owners amazon --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" --query 'Images[0].ImageId' --output text
}

variable "key_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM Certificate ARN for HTTPS (must match your domain)"
  type        = string
  default     = ""
}

variable "db_username" {
  description = "RDS master username"
  type        = string
  default     = "pritunl"
  sensitive   = true
}

variable "db_password" {
  description = "RDS master password (min 8 chars)"
  type        = string
  sensitive   = true
}

variable "allowed_admin_cidr" {
  description = "CIDR allowed to access Pritunl admin UI (your IP)"
  type        = string
  default     = "0.0.0.0/0"  # Restrict this to your IP in production!
}
