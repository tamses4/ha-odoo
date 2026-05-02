#!/bin/bash
set -euo pipefail
exec > /var/log/pritunl-install.log 2>&1
echo "=== Début installation Pritunl : $(date) ==="

# ---- MongoDB 6.0 ----
cat > /etc/yum.repos.d/mongodb-org-6.0.repo << 'EOF'
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF

# ---- Pritunl ----
cat > /etc/yum.repos.d/pritunl.repo << 'EOF'
[pritunl]
name=Pritunl Repository
baseurl=https://repo.pritunl.com/stable/yum/amazonlinux/2/
gpgcheck=1
enabled=1
EOF

amazon-linux-extras install epel -y 2>/dev/null || true
gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 7568D9BB55FF9E5287D586017AE645C0CF8E292A 2>/dev/null || \
gpg --keyserver hkp://keys.gnupg.net --recv-keys 7568D9BB55FF9E5287D586017AE645C0CF8E292A || true
gpg --armor --export 7568D9BB55FF9E5287D586017AE645C0CF8E292A > /tmp/pritunl.asc
rpm --import /tmp/pritunl.asc

yum -y install pritunl mongodb-org

# ---- MongoDB local (démarrage pour compatibilité) ----
systemctl enable mongod
systemctl start mongod

for i in {1..30}; do
  mongosh --eval "db.adminCommand({ping:1})" --quiet 2>/dev/null && break
  sleep 2
done

# ---- Configuration Pritunl avec MongoDB dédié ----
# MONGODB_URI est injecté par Terraform via templatefile()
cat > /etc/pritunl.conf << CONF
{
    "debug": false,
    "bind_addr": "0.0.0.0",
    "port": 443,
    "log_path": "/var/log/pritunl.log",
    "temp_path": "/tmp/pritunl_%r",
    "local_address_interface": "auto",
    "mongodb_uri": "${mongodb_uri}",
    "reverse_proxy": true
}
CONF

systemctl enable pritunl
systemctl start pritunl

echo "=== Installation terminée : $(date) ==="
