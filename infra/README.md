# Infrastructure

Tout est en Terraform (`CLAUDE.md` règle 9). Règles de qualité : `docs/08-production-readiness.md` §2.
Découpage : `docs/01-architecture.md` §3. Guides de lecture : `docs/infra/`.

## Arborescence

```
infra/
├── global/                      # bootstrap, appliqué en local depuis le compte de gestion (guide 00)
│   ├── organization/            # organisation, OU, comptes, SCP, CloudTrail, budgets, Identity Center
│   ├── accounts/<env>/          # par compte membre : bucket d'état, OIDC GitHub, rôles CI, budget
│   └── modules/                 # tfstate, budget, identity-center, account-bootstrap
├── modules/<domaine>/           # 11 modules internes (network … gateway), un README chacun
└── envs/<env>/<couche>/         # 12 racines = 12 états : foundation, platform, agents, frontend
```

| Couche | Modules | Change |
|---|---|---|
| `foundation` | network, security, data | rarement |
| `platform` | tools, api, gateway, review, ingestion, observability | parfois |
| `agents` | agents | à chaque release |
| `frontend` | frontend | souvent |

## Conventions

- **Un état par environnement et par couche**, dans le bucket du compte : `cgp-tfstate-<env>-<compte>`,
  clé `envs/<env>/<couche>.tfstate`, verrou natif `use_lockfile`, chiffrement par la clé
  `alias/cgp-<env>-tfstate`. Les états de `global/*` vivent dans le bucket du compte de gestion.
- `backend.tf` ne contient qu'un backend partiel ; `backend.hcl` porte bucket, clé et chiffrement
  (`terraform init -backend-config=backend.hcl`). Les identifiants de comptes sont reportés dans
  `backend.hcl` et `terraform.tfvars` après le bootstrap ; la validation de `account_id` refuse la
  valeur de remplissage `000000000000`, et `allowed_account_ids` refuse tout autre compte.
- Une couche lit les sorties d'une couche inférieure par `terraform_remote_state`, ajouté au moment où
  une sortie est consommée (jamais de source de données inutilisée).
- Tags obligatoires sur toute ressource : `project`, `env`, `layer`, `owner`, `data_classification`
  (posés par `default_tags` du provider et repris par la variable `tags` des modules).
- Providers : `hashicorp/aws ~> 6.65` ; `hashicorp/awscc` en réserve pour une ressource AgentCore
  non couverte (aucune à ce jour, voir ci-dessous). Terraform `>= 1.15`.
- `make tf-check` (fmt, validate, tflint, trivy), `make tf-plan ENV=dev LAYER=…`,
  `make tf-apply ENV=dev LAYER=…` (dev uniquement ; staging et prod par la CI).

## Vérification de disponibilité régionale (2026-09-18)

Région retenue : **`eu-central-1`** (Francfort), inchangée. Vérifications faites avec la CLI AWS depuis
le compte 749020018778 et la documentation AWS (`docs/bedrock-agentcore/latest/devguide/agentcore-regions.html`).

| Service | Disponible en `eu-central-1` | Preuve |
|---|---|---|
| AgentCore Runtime | oui | `aws bedrock-agentcore-control list-agent-runtimes --region eu-central-1` répond |
| AgentCore Gateway | oui | `aws bedrock-agentcore-control list-gateways --region eu-central-1` répond |
| AgentCore Identity | oui | tableau des régions AWS |
| AgentCore Observability | oui | tableau des régions AWS |
| AgentCore Evaluations | oui, disponibilité générale | notes de version AgentCore |
| Policy in AgentCore | oui, disponibilité générale | notes de version AgentCore ; s'attache à une Gateway, filtre chaque appel d'outil en Cedar |
| AgentCore Memory | oui (non utilisé, `docs/01` §2) | tableau des régions AWS |
| Bedrock, Claude en profils UE | oui : `eu.anthropic.claude-opus-5`, `eu.anthropic.claude-sonnet-5`, `eu.anthropic.claude-haiku-4-5-20251001-v1:0`, `eu.anthropic.claude-opus-4-8`, `eu.anthropic.claude-sonnet-4-6` | `aws bedrock list-inference-profiles --region eu-central-1` |
| Bedrock, modèle non-Claude en profil UE | oui : `eu.amazon.nova-pro-v1:0`, `eu.amazon.nova-2-lite-v1:0`, `eu.mistral.pixtral-large-2502-v1:0` | idem |
| Bedrock, embeddings | oui : `cohere.embed-v4:0` (profil `eu.cohere.embed-v4:0`), `cohere.embed-multilingual-v3`, `amazon.titan-embed-text-v2:0` | `aws bedrock list-foundation-models --by-output-modality EMBEDDING` |
| Bedrock, reranker | oui : `cohere.rerank-v3-5:0`, `amazon.rerank-v1:0` | `aws bedrock list-foundation-models` |
| Bedrock Guardrails | oui | `aws bedrock list-guardrails --region eu-central-1` répond |
| Aurora PostgreSQL Serverless v2 | oui, versions 17.10 et 18.x en `db.serverless` | `aws rds describe-orderable-db-instance-options` |
| Amplify Hosting | oui | `aws amplify list-apps --region eu-central-1` répond |
| Cognito, Step Functions, EventBridge Scheduler | oui (services établis dans la région) | documentation AWS |
| SES | oui, **en sandbox** (200 envois/jour, destinataires vérifiés) ; sortie de sandbox à demander en phase 6 | `aws sesv2 get-account --region eu-central-1` |

Les identifiants de modèles ci-dessus sont une **liste de disponibilité**, pas un choix : la sélection
se fait en phase 5 dans `packages/agents/config/models.yaml` (`docs/01` §8) et la comparaison en phase 8.

Paris (`eu-west-3`) ne porte que Gateway, Identity et Memory ; Irlande (`eu-west-1`) n'a ni Evaluations
ni Policy. Francfort est la seule région de l'UE qui porte tout.

## Couverture Terraform d'AgentCore (2026-09-18)

`hashicorp/aws` v6.65 couvre : `aws_bedrockagentcore_agent_runtime`, `_agent_runtime_endpoint`,
`_gateway`, `_gateway_target`, `_gateway_rule`, `_workload_identity`, `_oauth2_credential_provider`,
`_api_key_credential_provider`, `_policy_engine`, `_policy`, `_evaluator`,
`_online_evaluation_config`, `_resource_policy`, ainsi que `aws_bedrock_guardrail` et
`aws_bedrock_inference_profile`. `hashicorp/awscc` v1.102 couvre les mêmes familles. Aucune ressource
prévue par `docs/01` n'est hors couverture : l'exception « script idempotent exécuté par la CI » n'a
pas lieu d'être. À revérifier au début de la phase 5.

## Décision : Policy in AgentCore

Policy couvre exactement le besoin énoncé dans `docs/01` §2 (contrôle des appels d'outils) : moteur de
politiques Cedar associé à une Gateway, chaque invocation d'outil évaluée hors du code de l'agent,
décisions journalisées dans CloudWatch. **Retenu** dans le module `gateway` (phase 5), comme troisième
contrôle mesuré aux côtés de la liste d'outils fermée et de la vérification déterministe.
