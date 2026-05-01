#!/bin/bash
# ============================================================
# TP2 - Configuration Pritunl VPN (Hybridation Cloud/Local)
# À exécuter sur la machine locale (nœud 2)
# ============================================================
# Prérequis : Pritunl server déjà déployé sur EC2 (TP1)

set -e

echo "======================================================"
echo "  Configuration VPN Pritunl - Environnement Hybride"
echo "======================================================"

OS=$(uname -s)

install_pritunl_client_linux() {
  echo "[1/3] Installation du client Pritunl sur Linux..."

  # Ubuntu/Debian
  if command -v apt-get &>/dev/null; then
    sudo tee /etc/apt/sources.list.d/pritunl.list <<EOF
deb https://repo.pritunl.com/stable/apt $(lsb_release -cs) main
EOF
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 7568D9BB55FF9E5287D586017AE645C0CF8E292A
    sudo apt-get update -qq
    sudo apt-get install -y pritunl-client-electron 2>/dev/null || \
    sudo apt-get install -y pritunl-client

  # RHEL/CentOS
  elif command -v yum &>/dev/null; then
    sudo tee /etc/yum.repos.d/pritunl.repo <<EOF
[pritunl]
name=Pritunl Stable Repository
baseurl=https://repo.pritunl.com/stable/yum/centos/8/
gpgcheck=1
enabled=1
EOF
    sudo rpm -import https://raw.githubusercontent.com/pritunl/pritunl/master/key/pritunl.asc
    sudo yum install -y pritunl-client
  fi

  echo "  ✓ Client Pritunl installé"
}

configure_vpn_profile() {
  echo "[2/3] Import du profil VPN..."
  echo ""
  echo "  📋 Instructions :"
  echo "  1. Connectez-vous à l'interface Pritunl Server :"
  echo "     https://pritunl-nlb-bca6d0718259437e.elb.us-east-1.amazonaws.com  (admin / mot de passe TP1)"
  echo ""
  echo "  2. Allez dans 'Users' → sélectionnez votre utilisateur"
  echo "  3. Cliquez sur l'icône de téléchargement (.tar ou .ovpn)"
  echo "  4. Importez le fichier :"
  echo ""
  echo "     Via GUI : ouvrir pritunl-client → Import Profile → sélectionner .tar"
  echo "     Via CLI :"
  echo "       pritunl-client add C:\Users\DELL\Downloads\tp2_complet\pritunl\tp-aws_tpodoo_tp-aws-server.ovpn"
  echo "       pritunl-client list"
  echo "       pritunl-client start <PROFILE_ID>"
  echo ""
}

verify_vpn_connection() {
  echo "[3/3] Vérification de la connexion VPN..."
  echo ""

  NODE1_VPN_IP="${NODE1_VPN_IP:-52.70.217.74}"   # À remplacer par l'IP VPN du nœud 1

  # Vérifier l'interface VPN
  if ip link show | grep -q "tun\|pritunl"; then
    echo "  ✓ Interface tunnel VPN détectée"
  else
    echo "  ⚠ Aucune interface tunnel - VPN peut-être non connecté"
  fi

  # Ping vers le nœud AWS
  echo ""
  echo "  Test de connectivité vers $NODE1_VPN_IP :"
  if ping -c 3 -W 2 "$NODE1_VPN_IP" &>/dev/null; then
    echo "  ✓ Ping vers nœud 1 OK - VPN fonctionnel !"
  else
    echo "  ✗ Impossible de joindre $NODE1_VPN_IP"
    echo "    Vérifiez : client connecté, Security Groups AWS (UDP 1194 ouvert)"
  fi

  echo ""
  echo "  Test de connectivité PostgreSQL (nœud 1) :"
  if nc -z -w3 "$NODE1_VPN_IP" 5432 2>/dev/null; then
    echo "  ✓ Port PostgreSQL 5432 accessible"
  else
    echo "  ✗ Port 5432 inaccessible - vérifiez Security Group EC2"
  fi
}

# ---- Main -----------------------------------------------
case "$OS" in
  Linux)
    install_pritunl_client_linux
    configure_vpn_profile
    verify_vpn_connection
    ;;
  Darwin)
    echo "  macOS détecté."
    echo "  Installez le client via : https://client.pritunl.com/#install"
    configure_vpn_profile
    ;;
  *)
    echo "  Système non supporté. Voir : https://client.pritunl.com"
    configure_vpn_profile
    ;;
esac

echo ""
echo "======================================================"
echo "  ✅ Une fois le VPN connecté, lancez :"
echo "     cd ../odoo-node2 && docker compose up -d"
echo "     ../scripts/setup-replication.sh"
echo "======================================================"
