#!/bin/bash
# ============================================================
# TP2 - Vérification Réplication et Haute Disponibilité
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================================"
echo "  TP2 - Diagnostic Réplication Master-Master Odoo"
echo "======================================================"

# ---- Vérifier l'état des conteneurs --------------------
echo ""
echo "📦 État des conteneurs :"
for container in odoo_db1 odoo_app1 odoo_db2 odoo_app2; do
  STATUS=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
  if [ "$STATUS" = "running" ]; then
    echo -e "  ${GREEN}✓${NC} $container : running"
  else
    echo -e "  ${RED}✗${NC} $container : ${STATUS:-non trouvé}"
  fi
done

# ---- Vérifier pglogical sur nœud 1 --------------------
echo ""
echo "🔄 État réplication - Nœud 1 :"
docker exec odoo_db1 psql -U odoo -d odoo -c "
  SELECT subscription_name,
         status,
         provider_node
  FROM pglogical.show_subscription_status();
" 2>/dev/null || echo -e "  ${RED}✗ Impossible de contacter db1${NC}"

# ---- Vérifier pglogical sur nœud 2 --------------------
echo ""
echo "🔄 État réplication - Nœud 2 :"
docker exec odoo_db2 psql -U odoo -d odoo -c "
  SELECT subscription_name,
         status,
         provider_node
  FROM pglogical.show_subscription_status();
" 2>/dev/null || echo -e "  ${RED}✗ Impossible de contacter db2${NC}"

# ---- Test de réplication (écriture croisée) -----------
echo ""
echo "🧪 Test réplication croisée..."
TIMESTAMP=$(date +%s)
TEST_TABLE="repl_test_$TIMESTAMP"

# Écrire sur nœud 1
docker exec odoo_db1 psql -U odoo -d odoo -c "
  CREATE TABLE IF NOT EXISTS _tp2_repl_test (id SERIAL, val TEXT, ts TIMESTAMP DEFAULT NOW());
  INSERT INTO _tp2_repl_test(val) VALUES ('written_on_node1_$TIMESTAMP');
" > /dev/null 2>&1

sleep 3  # Attendre propagation

# Lire depuis nœud 2
COUNT=$(docker exec odoo_db2 psql -U odoo -d odoo -t -c "
  SELECT COUNT(*) FROM _tp2_repl_test WHERE val LIKE 'written_on_node1_%';
" 2>/dev/null | tr -d ' ')

if [ "$COUNT" -gt "0" ] 2>/dev/null; then
  echo -e "  ${GREEN}✓ Réplication nœud1→nœud2 : OK ($COUNT ligne(s))${NC}"
else
  echo -e "  ${RED}✗ Réplication nœud1→nœud2 : ÉCHEC${NC}"
fi

# Nettoyage
docker exec odoo_db1 psql -U odoo -d odoo -c "DROP TABLE IF EXISTS _tp2_repl_test;" > /dev/null 2>&1

# ---- Vérifier les endpoints Odoo ----------------------
echo ""
echo "🌐 Santé des applications Odoo :"
for port in 8069; do
  if curl -sf "http://localhost:$port/web/health" > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Odoo sur port $port : OK"
  else
    echo -e "  ${RED}✗${NC} Odoo sur port $port : INJOIGNABLE"
  fi
done

echo ""
echo "======================================================"

# ---- Test de résilience (simulation panne) ------------
echo ""
echo -e "${YELLOW}💡 Pour tester la résilience :${NC}"
echo "  1. Arrêter le nœud 1 : docker stop odoo_app1 odoo_db1"
echo "  2. Vérifier que le nœud 2 répond toujours"
echo "  3. Redémarrer : docker start odoo_db1 odoo_app1"
echo "  4. Vérifier la resynchronisation"
