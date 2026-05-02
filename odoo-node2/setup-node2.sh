#!/bin/bash
# ============================================================
# TP2 - Setup NODE2 (Local)
# Exécuter sur votre machine locale
# ============================================================

set -e

NODE1_IP="10.78.152.1"
NODE2_IP="10.78.152.3"
DB_PORT="5432"
DB_USER="odoo"
DB_NAME="odoo"
REPL_USER="replicator"
REPL_PASS="ReplicaPass@2024"

echo "======================================================"
echo "  NODE2 - Configuration pglogical (Local)"
echo "======================================================"

# ---- ÉTAPE 1 : Nœud 2 comme provider --------------------
echo "[1/2] Configuration du nœud 2 (provider)..."
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

# ---- ÉTAPE 2 : Nœud 2 s'abonne au nœud 1 ---------------
echo "[2/2] Création subscription nœud2 ← nœud1..."
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
echo "  ✓ Subscription nœud2 ← nœud1 créée"

echo ""
echo "======================================================"
echo "  ✅ Réplication Master-Master configurée !"
echo ""
echo "  Vérification :"
echo "  docker exec odoo_db2 psql -U odoo -d odoo -c \\"
echo "    \"SELECT subscription_name, status FROM pglogical.show_subscription_status();\""
echo "======================================================"
