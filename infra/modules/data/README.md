# Module `data`

Aurora PostgreSQL Serverless v2 avec pgvector (scale-to-zero en dev et staging, PITR, deletion_protection), RDS Proxy avec authentification IAM, buckets S3 (documents, corpus brut, export d'audit avec Object Lock), AWS Backup avec second coffre.

- **Couche** : `foundation` (`docs/01-architecture.md` §3).
- **Phase de livraison** : 3 (`docs/07-roadmap.md`).
- **Guide de lecture** : `docs/infra/03-data.md`, écrit avec le module.

## Entrées

| Variable | Description |
|---|---|
| `project` | Nom court du projet, préfixe des ressources. |
| `env` | Environnement cible (`dev`, `staging`, `prod`). |
| `tags` | Tags communs ; `project`, `env`, `layer`, `owner`, `data_classification` obligatoires. |

## Sorties

| Sortie | Description |
|---|---|
| `name_prefix` | Préfixe de nommage `projet-environnement`. |
| `tags` | Tags appliqués. |

En phase 0 le module ne crée aucune ressource : il fixe le contrat (variables typées avec validation, sorties documentées, README) que les phases suivantes remplissent.
