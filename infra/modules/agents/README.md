# Module `agents`

Dépôt ECR (scan à la poussée, digest immuable), Bedrock AgentCore Runtime (image ARM64 construite par la CI, autorisation JWT Cognito entrante), Bedrock Guardrails, rôle d'exécution à moindre privilège, paramètres SSM (kill switch, feature flags).

- **Couche** : `agents` (`docs/01-architecture.md` §3).
- **Phase de livraison** : 5 (`docs/07-roadmap.md`).
- **Guide de lecture** : `docs/infra/06-agents.md`, écrit avec le module.

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
