# Module `frontend`

Amplify Hosting (Next.js SSR, branche par environnement, domaine, CloudFront), association WAF, variables d'environnement par branche.

- **Couche** : `frontend` (`docs/01-architecture.md` §3).
- **Phase de livraison** : 7 (`docs/07-roadmap.md`).
- **Guide de lecture** : `docs/infra/09-frontend.md`, écrit avec le module.

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
