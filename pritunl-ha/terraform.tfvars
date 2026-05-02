# Copiez ce fichier en "terraform.tfvars" et remplissez les valeurs

region = "us-east-1"

# Obtenez l'AMI Amazon Linux 2 pour votre région :
# aws ec2 describe-images --owners amazon \
#   --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
#             "Name=state,Values=available" \
#   --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
#   --output text --region eu-west-1
ami_id = "ami-0d05471b100e9083f"

# Nom de votre Key Pair EC2 (créé dans la console AWS)
key_name = "pritunl-key"

# Laissez vide pour un test sans HTTPS, ou mettez l'ARN ACM :
# acm_certificate_arn = "arn:aws:acm:eu-west-1:123456789:certificate/xxxx"
acm_certificate_arn = ""

# Identifiants RDS (utilisez des valeurs sécurisées !)
db_username = "pritunl_admin"
db_password = "Gabriella2026!"

# Votre IP publique pour SSH (trouvez-la sur https://ifconfig.me)
allowed_admin_cidr = "0.0.0.0/0"
#acm_certificate_arn = "arn:aws:acm:us-east-1:218908192938:certificate/9e8595fc-0af2-4c81-9243-607cdc1fe607"
