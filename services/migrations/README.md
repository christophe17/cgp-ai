# migrations — exécution des migrations Alembic

Lambda invoquée par la CI avant chaque déploiement applicatif ; joue les migrations de `cgp-storage` contre la base de l'environnement via RDS Proxy.

## Règles

- Migrations réversibles, exécutées par la CI uniquement.

## État

- **Phase 0** : squelette installable (`services/migrations`), test de fumée.
- **Implémentation** : phase 3.

## Tests

Intégration : migration à l'aller et au retour en `dev`.
