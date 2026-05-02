################################
# DB Subnet Group
################################
resource "aws_db_subnet_group" "main" {
  name       = "pritunl-db-subnet"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = { Name = "pritunl-db-subnet-group" }
}

################################
# RDS PostgreSQL Multi-AZ
################################
resource "aws_db_instance" "main" {
  identifier             = "pritunl-db"
  engine                 = "postgres"
  engine_version         = "15.8"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  max_allocated_storage  = 100  # autoscaling storage
  storage_type           = "gp3"
  storage_encrypted      = true

  db_name  = "pritunl"
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az               = true
  publicly_accessible    = false
  deletion_protection    = false  # mettre true en production

  backup_retention_period = 0
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  skip_final_snapshot       = true
  
  performance_insights_enabled = false

  tags = { Name = "pritunl-rds" }
}
