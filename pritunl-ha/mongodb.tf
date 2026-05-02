################################
# Security Group - MongoDB
################################
resource "aws_security_group" "mongodb" {
  name        = "pritunl-mongodb-sg"
  description = "MongoDB dedicated instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MongoDB depuis instances Pritunl"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "mongodb-sg" }
}

################################
# Instance MongoDB dédiée
################################
resource "aws_instance" "mongodb" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.mongodb.id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail
    exec > /var/log/mongodb-install.log 2>&1

    # MongoDB 6.0 repo
    cat > /etc/yum.repos.d/mongodb-org-6.0.repo << 'REPO'
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
REPO

    yum install -y mongodb-org

    # Écouter sur toutes les interfaces (réseau VPC uniquement via SG)
    sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf

    systemctl enable mongod
    systemctl start mongod

    echo "MongoDB installé et démarré"
  EOF
  )

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name    = "pritunl-mongodb"
    Project = "pritunl-ha"
  }
}

################################
# Output IP privée MongoDB
################################
output "mongodb_private_ip" {
  description = "IP privée de l'instance MongoDB"
  value       = aws_instance.mongodb.private_ip
}