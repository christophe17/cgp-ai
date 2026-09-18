# cgp-storage — accès PostgreSQL

Dépôts typés (`ProfileRepository`, `ConversationRepository`…), schéma de `docs/02-domain-model.md` §7, migrations Alembic, accès via RDS Proxy avec authentification IAM et `psycopg` 3.

## Règles

- Toute requête sur des données utilisateur prend `user_id` en paramètre obligatoire.
- `audit_events` en ajout seul : `UPDATE` et `DELETE` révoqués pour le rôle applicatif.
- Suppression RGPD en une transaction, testée de bout en bout.

## État

- **Phase 0** : squelette installable (`packages/storage`), test de fumée.
- **Implémentation** : phase 3.

## Tests

testcontainers (PostgreSQL + pgvector) ; migrations jouées à l'aller et au retour.
