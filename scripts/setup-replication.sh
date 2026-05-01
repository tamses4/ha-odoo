#!/bin/bash
# ============================================================
# TP2 - Configuration Réplication Master-Master (pglogical)
# À exécuter UNE SEULE FOIS après le démarrage des 2 nœuds
# et après l'initialisation de la base Odoo
# ============================================================

set -e

# ---- VARIABLES - ADAPTER SELON VOTRE ENVIRONNEMENT --------
NODE1_IP="${NODE1_IP:-<EC2_NODE1_IP>}"       # IP publique ou VPN du nœud 1
NODE2_IP="${NODE2_IP:-<NODE2_VPN_IP>}"       # IP VPN du nœud 2 (local)
DB_PORT="5432"
DB_USER="odoo"
DB_PASS="${DB_PASSWORD:-OdooSecure@2024}"
DB_NAME="odoo"
REPL_USER="replicator"
REPL_PASS="ReplicaPass@2024"

echo "======================================================"
echo "  Configuration Réplication Master-Master pglogical"
echo "======================================================"
echo "Nœud 1 : $NODE1_IP"
echo "Nœud 2 : $NODE2_IP"
echo ""

# ---- ÉTAPE 1 : Configurer le nœud 1 comme provider --------
echo "[1/4] Configuration du nœud 1 (provider)..."
docker exec odoo_db1 psql -U "$DB_USER" -d "$DB_NAME" <<-EOSQL
  -- Créer le nœud pglogical local
  SELECT pglogical.create_node(
    node_name := 'node1',
    dsn := 'host=$NODE1_IP port=$DB_PORT dbname=$DB_NAME user=$REPL_USER password=$REPL_PASS'
  );

  -- Créer un replication set avec toutes les tables
  SELECT pglogical.create_replication_set(
    set_name := 'odoo_master_set',
    replicate_insert := true,
    replicate_update := true,
    replicate_delete := true,
    replicate_truncate := false
  );

  -- Ajouter toutes les tables au replication set
  SELECT pglogical.replication_set_add_all_tables(
    set_name := 'odoo_master_set',
    schema_names := ARRAY['public'],
    synchronize_data := true
  );
EOSQL
echo "  ✓ Nœud 1 configuré comme provider"

# ---- ÉTAPE 2 : Configurer le nœud 2 comme provider --------
echo "[2/4] Configuration du nœud 2 (provider)..."
docker exec odoo_db2 psql -U "$DB_USER" -d "$DB_NAME" <<-EOSQL
  SELECT pglogical.create_node(
    node_name := 'node2',
    dsn := 'host=$NODE2_IP port=$DB_PORT dbname=$DB_NAME user=$REPL_USER password=$REPL_PASS'
  );

  SELECT pglogical.create_replication_set(
    set_name := 'odoo_master_set',
    replicate_insert := true,
    replicate_update := true,
    replicate_delete := true,
    replicate_truncate := false
  );

  SELECT pglogical.replication_set_add_all_tables(
    set_name := 'odoo_master_set',
    schema_names := ARRAY['public'],
    synchronize_data := true
  );
EOSQL
echo "  ✓ Nœud 2 configuré comme provider"

# ---- ÉTAPE 3 : Nœud 1 s'abonne au nœud 2 -----------------
echo "[3/4] Création subscription nœud1 → nœud2..."
docker exec odoo_db1 psql -U "$DB_USER" -d "$DB_NAME" <<-EOSQL
  SELECT pglogical.create_subscription(
    subscription_name := 'sub_from_node2',
    provider_dsn := 'host=$NODE2_IP port=$DB_PORT dbname=$DB_NAME user=$REPL_USER password=$REPL_PASS',
    replication_sets := ARRAY['odoo_master_set'],
    synchronize_structure := false,
    synchronize_data := false,
    forward_origins := '{}'
  );
EOSQL
echo "  ✓ Subscription nœud1←nœud2 créée"

# ---- ÉTAPE 4 : Nœud 2 s'abonne au nœud 1 -----------------
echo "[4/4] Création subscription nœud2 → nœud1..."
docker exec odoo_db2 psql -U "$DB_USER" -d "$DB_NAME" <<-EOSQL
  SELECT pglogical.create_subscription(
    subscription_name := 'sub_from_node1',
    provider_dsn := 'host=$NODE1_IP port=$DB_PORT dbname=$DB_NAME user=$REPL_USER password=$REPL_PASS',
    replication_sets := ARRAY['odoo_master_set'],
    synchronize_structure := false,
    synchronize_data := false,
    forward_origins := '{}'
  );
EOSQL
echo "  ✓ Subscription nœud2←nœud1 créée"

echo ""
echo "======================================================"
echo "  ✅ Réplication Master-Master configurée !"
echo ""
echo "  Vérification : exécutez scripts/check-replication.sh"
echo "======================================================"
