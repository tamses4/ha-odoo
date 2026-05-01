# TP2 – Déploiement Applicatif Automatisé en HA

## Architecture

```
Internet
    │
    ▼
[ALB AWS]  ◄──── Distribue le trafic HTTP/HTTPS
    │
    ├──────────────────────────────┐
    ▼                              ▼
[EC2 AZ1 - Nœud 1]          [EC2 AZ2 - Nœud 2]
 ┌─────────────────┐          ┌─────────────────┐
 │  HAProxy :80    │          │  HAProxy :80    │
 │  Odoo :8069     │          │  Odoo :8069     │
 │  PostgreSQL     │◄────────►│  PostgreSQL     │
 │  (Master)       │ pglogical │  (Master)       │
 └─────────────────┘          └─────────────────┘
         │                              │
         └──────── VPN Pritunl ─────────┘
                       │
                  [Réseau Local]
                  Machine locale
                  (Docker)
```

## Prérequis

- TP1 terminé : infrastructure AWS déployée (VPC, EC2, ALB, RDS, Pritunl)
- Docker + Docker Compose installés sur la machine locale
- Client Pritunl VPN disponible

## Structure des fichiers

```
tp2/
├── odoo-node1/             # Nœud 1 (EC2 AZ1)
│   ├── docker-compose.yml
│   ├── odoo.conf
│   ├── init-db.sql
│   └── haproxy.cfg
├── odoo-node2/             # Nœud 2 (Local / EC2 AZ2)
│   ├── docker-compose.yml
│   ├── odoo.conf
│   ├── init-db.sql
│   └── haproxy.cfg
├── scripts/
│   ├── setup-replication.sh    # Configure pglogical Master-Master
│   └── check-replication.sh    # Vérifie l'état de la réplication
├── pritunl/
│   └── setup-vpn-client.sh     # Installation client VPN
├── .env.example
└── README.md
```

---

## Étape 1 – Connexion VPN (Hybridation)

Le VPN Pritunl a été déployé sur EC2 au TP1. Il faut maintenant connecter la machine locale.

### 1.1 Installer le client Pritunl

```bash
chmod +x pritunl/setup-vpn-client.sh
./pritunl/setup-vpn-client.sh
```

### 1.2 Télécharger le profil VPN

1. Ouvrez `https://<EC2_IP>/` dans votre navigateur
2. Connectez-vous avec vos identifiants Pritunl
3. Allez dans **Users** → cliquez sur l'icône ⬇ de votre utilisateur
4. Téléchargez le fichier `.tar` ou `.ovpn`

### 1.3 Importer et connecter

```bash
# Importer le profil
pritunl-client add ~/Downloads/user.tar

# Lister les profils disponibles
pritunl-client list

# Se connecter (remplacer <ID> par l'ID affiché)
pritunl-client start <ID>

# Vérifier la connexion
ping <NODE1_VPN_IP>
```

> **Security Group AWS** : Assurez-vous que le port **UDP 1194** (ou celui configuré pour Pritunl) est ouvert dans votre Security Group EC2.

---

## Étape 2 – Déploiement des conteneurs

### 2.1 Configurer les variables d'environnement

```bash
cp .env.example .env
nano .env  # Remplir NODE1_IP et NODE2_IP
```

### 2.2 Déployer le Nœud 1 (sur EC2 AZ1)

```bash
# Se connecter à l'instance EC2 (via SSH ou VPN)
ssh ec2-user@<EC2_NODE1_IP>

# Cloner le dépôt et déployer
https://github.com/tamses4/ha-odoo.git
git clone https://github.com/tamses4/ha-odoo.git && cd tp2/odoo-node1
docker compose up -d

# Vérifier le démarrage
docker compose ps
docker compose logs -f odoo1
```

Attendez qu'Odoo soit accessible sur `http://<EC2_NODE1_IP>:8069`.  
Créez la base de données Odoo via l'interface web (premier démarrage).

### 2.3 Déployer le Nœud 2 (machine locale)

```bash
cd tp2/odoo-node2

# Adapter haproxy.cfg : remplacer NODE2_VPN_IP par l'IP VPN locale
# (visible dans pritunl-client list ou ip addr show tun0)

docker compose up -d
docker compose logs -f odoo2
```

> ⚠️ Sur le nœud 2, pointez Odoo vers la **même base de données** que le nœud 1 (via le tunnel VPN), ou configurez pglogical pour la réplication bi-directionnelle (étape 3).

---

## Étape 3 – Configuration Master-Master (pglogical)

> **Important** : exécuter seulement APRÈS que les deux instances Odoo sont démarrées et que la base de données est initialisée.

```bash
# Configurer les IPs
export NODE1_IP=<EC2_NODE1_VPN_IP>
export NODE2_IP=<LOCAL_VPN_IP>

# Lancer le script de réplication
chmod +x scripts/setup-replication.sh
./scripts/setup-replication.sh
```

Le script configure pglogical en mode **bi-directionnel** :
- Nœud 1 s'abonne aux changements du nœud 2
- Nœud 2 s'abonne aux changements du nœud 1

---

## Étape 4 – Vérification et Test de Résilience

### 4.1 Vérifier l'état de la réplication

```bash
chmod +x scripts/check-replication.sh
./scripts/check-replication.sh
```

Sortie attendue :
```
✓ odoo_db1 : running
✓ odoo_app1 : running
✓ odoo_db2 : running
✓ odoo_app2 : running
✓ Réplication nœud1→nœud2 : OK
✓ Réplication nœud2→nœud1 : OK
```

### 4.2 Test de résilience (panne d'un master)

```bash
# Simuler la panne du nœud 1
docker stop odoo_app1 odoo_db1

# Vérifier que le nœud 2 répond toujours
curl http://<NODE2_IP>:8069/web/health

# Créer un enregistrement sur le nœud 2 pendant la panne
# (via l'interface Odoo du nœud 2)

# Redémarrer le nœud 1
docker start odoo_db1 && sleep 10 && docker start odoo_app1

# Vérifier la resynchronisation (l'enregistrement doit apparaître)
./scripts/check-replication.sh
```

---

## Commandes utiles

```bash
# Voir les logs Odoo
docker logs -f odoo_app1

# Accéder au shell PostgreSQL
docker exec -it odoo_db1 psql -U odoo -d odoo

# État de la réplication pglogical
docker exec odoo_db1 psql -U odoo -d odoo -c \
  "SELECT * FROM pglogical.show_subscription_status();"

# Redémarrer un service
docker compose restart odoo1

# Stats HAProxy
open http://localhost:8404/stats  # admin / haproxy@stats
```

---

## Livrables

- [x] `odoo-node1/docker-compose.yml` – Nœud 1 AWS EC2
- [x] `odoo-node2/docker-compose.yml` – Nœud 2 Local/EC2
- [x] `odoo-node1/odoo.conf` – Configuration Odoo
- [x] `odoo-node1/haproxy.cfg` – Load Balancer
- [x] `scripts/setup-replication.sh` – Réplication Master-Master
- [x] `scripts/check-replication.sh` – Vérification HA
- [x] `pritunl/setup-vpn-client.sh` – Client VPN
- [x] `README.md` – Cette documentation
