-- ============================================================
-- TP2 - Initialisation PostgreSQL pour réplication Master-Master
-- Via pglogical (Logical Replication)
-- Ce script s'exécute au premier démarrage du conteneur
-- ============================================================

-- Activer pglogical
CREATE EXTENSION IF NOT EXISTS pglogical;

-- Créer un utilisateur dédié à la réplication
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'replicator') THEN
    CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'ReplicaPass@2024';
  END IF;
END
$$;

-- Accorder les droits nécessaires
GRANT ALL PRIVILEGES ON DATABASE odoo TO replicator;
GRANT USAGE ON SCHEMA public TO replicator;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO replicator;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO replicator;

-- ============================================================
-- NOTE: La configuration du nœud pglogical est faite via
-- le script scripts/setup-replication.sh APRÈS le démarrage
-- des deux conteneurs et l'installation initiale d'Odoo.
-- ============================================================
