# 01 — Architecture, mapping AWS, Terraform, flux et identité

> **Périmètre (2026-09-18)** : un seul vertical est construit — la transmission, spécialiste `estate`. L'agent `tax`, l'agent `extractor`, la Lambda `documents` et tout ce qui est marqué V2+ sont spécifiés ici mais **différés** (`07-roadmap.md`, « Périmètre »). L'infrastructure, elle, est construite en entier.

## 1. Vue en couches

```
Navigateur (Next.js)
        │  session Cognito (JWT)
        ▼
BFF : routes serveur Next.js (Amplify Hosting)
        │  JWT transmis tel quel                     │  JWT
        ▼                                            ▼
AgentCore Runtime (services/agent_runtime)      API profil (API Gateway + Lambda)
  pipeline en code :                              profil, confirmations, documents,
  périmètre → plan → complétude → spécialistes    conversations, recommandations, back-office
  → vérification → conformité → réponse
        │  invocation Lambda (IAM), contexte injecté par le code
        ▼
Outils (Lambdas) : profile · calc · legal · documents · usage
        │
        ▼
Données : Aurora PostgreSQL (profils, historique, calculs, RAG pgvector, audit) · S3 (documents, audit immuable, corpus brut)
        │
Contrôle humain : Step Functions de validation conseiller · back-office (routes /advisor du frontend)
Transverse : AgentCore Observability / CloudWatch, évaluations, journal d'audit
```

## 2. Mapping des composants sur AWS

| Composant | Service AWS | Notes |
|---|---|---|
| Frontend + BFF | Amplify Hosting (Next.js SSR) | Domaine custom, CloudFront inclus, WAF attaché. Les routes serveur relaient le flux SSE du runtime |
| Authentification | Amazon Cognito (un user pool) | MFA obligatoire pour tous. Groupe `advisors` attribué uniquement par un administrateur. Inscription sur invitation en mode démonstration |
| Exécution des agents | Bedrock AgentCore Runtime | Image conteneur ARM64 construite par la CI ; autorisation JWT entrante (Cognito) ; une session par conversation ; streaming |
| Framework d'agents | Strands Agents | Un agent Strands par étape LLM ; le pipeline qui les enchaîne est du code Python |
| Modèles | Amazon Bedrock (Claude, API Converse) | Deux niveaux : `capable` (planification, spécialistes, vérificateur) et `fast` (collecte, extraction, classification). Profils d'inférence UE |
| Embeddings | Amazon Bedrock (modèle d'embedding multilingue) | Identifiant et dimension en configuration ; réindexation complète si le modèle change |
| Garde-fous contenu | Bedrock Guardrails | Appliqués à l'entrée utilisateur et à la sortie finale |
| Outils | AWS Lambda (Python, VPC) | Une Lambda par famille (`profile`, `calc`, `legal`, `documents`, `usage`), invoquées par le runtime et par l'API avec IAM ; contexte utilisateur injecté par le code appelant. Backend de référence |
| Passerelle d'outils | Bedrock AgentCore Gateway + AgentCore Identity | Second backend : les mêmes Lambdas exposées en MCP par la passerelle, autorisation JWT entrante (Cognito), authentification sortante vers les Lambdas gérée par Identity. Sélection par feature flag SSM ; mesuré contre l'invocation directe (`06-evals-mlops.md` §13) |
| Base de données | Aurora PostgreSQL Serverless v2 + pgvector | Profils versionnés, mises à jour en attente, documents, conversations, appels de calcul, recommandations, validations, usage, audit, corpus juridique indexé. RDS Proxy, authentification IAM |
| Documents clients (**différé**) | S3 (KMS) + extraction par Claude (vision, sortie structurée) | Upload par URL présignée ; extraction vers un schéma Pydantic ; confirmation champ par champ par l'utilisateur |
| Validation conseiller | Step Functions (task token) + Lambdas | Notification SES au conseiller ; décision via le back-office ; expiration si le profil change |
| Ingestion juridique | EventBridge Scheduler → Step Functions → Lambdas | Détection de changement par hash, découpage par article, indexation pgvector |
| Journal d'audit | Table PostgreSQL en ajout seul + export horaire vers S3 Object Lock (mode conformité) | Conservation réglementaire |
| Observabilité | AgentCore Observability, CloudWatch (logs, métriques, alarmes), X-Ray via OpenTelemetry | Spans par session, agent, outil ; aucune PII |
| Évaluations | Suite pytest `evals/` (CI) ; AgentCore Evaluations en ligne à partir de la phase 8 | |
| Secrets et chiffrement | KMS (clés gérées client, une par domaine de données), Secrets Manager | |
| IaC / CI-CD | Terraform + GitHub Actions (OIDC vers AWS) | Un compte AWS par environnement ; état S3 chiffré et verrouillé ; voir §3 |

Services AgentCore utilisés : **Runtime**, **Observability**, **Evaluations**, **Gateway** et **Identity**. Gateway et Identity forment le second backend d'outils (décision du 2026-09-18) : les mêmes Lambdas, exposées en MCP, avec l'identité propagée par la passerelle ; l'invocation directe (§5) reste le backend de référence tant que la mesure ne dit pas le contraire. **Memory** n'est pas utilisé : l'historique vit en base (§6) pour que la suppression RGPD reste maîtrisée dans un seul stockage. **Policy** (vérifié le 2026-09-18, `infra/README.md`) : s'attache à une Gateway et évalue chaque appel d'outil contre des politiques Cedar, hors du code de l'agent ; disponible en `eu-central-1` en disponibilité générale et couvert par `aws_bedrockagentcore_policy_engine` et `aws_bedrockagentcore_policy`. **Retenu** dans le module `gateway` (phase 5).

> ⚠️ AgentCore évolue rapidement. Avant toute implémentation, vérifier dans la documentation AWS : les noms d'API, la disponibilité régionale de chaque service, et la couverture de chaque ressource par le provider Terraform `aws`, sinon `awscc`. Si une ressource n'est couverte par aucun des deux, l'exception est un script idempotent exécuté par la CI, jamais une action manuelle, avec une date de réévaluation dans le code.

## 3. Découpage Terraform

### Modules (`infra/modules/<domaine>/`)

1. `network` — VPC, sous-réseaux privés, endpoints (Bedrock Runtime, S3, Secrets Manager, CloudWatch Logs, Lambda, STS), groupes de sécurité
2. `security` — clés KMS (une par domaine : base, documents, audit, journaux), rôles IAM de base, Cognito (user pool, MFA, groupe `advisors`, client applicatif), WAF
3. `data` — cluster Aurora Serverless v2 (PostgreSQL, pgvector), RDS Proxy, buckets S3 (documents, corpus brut, export d'audit avec Object Lock), sauvegardes AWS Backup
4. `tools` — Lambdas d'outils, DLQ, rôles par Lambda
5. `api` — API Gateway HTTP + Lambdas de l'API profil, autorisation JWT Cognito, quotas
6. `agents` — AgentCore Runtime, dépôt ECR, Guardrails, rôle d'exécution
7. `review` — Step Functions de validation, Lambdas, SES
8. `ingestion` — Step Functions d'ingestion, Lambdas, planification EventBridge
9. `observability` — dashboards, alarmes, canal d'astreinte SNS, budgets, export d'audit
10. `frontend` — Amplify Hosting (application, branche par environnement, domaine, association WAF)
11. `gateway` — AgentCore Gateway (cibles Lambda des outils exposées en MCP, autorisation JWT entrante Cognito), AgentCore Identity (fournisseur de credentials pour l'authentification sortante vers les Lambdas), rôle de la passerelle

### Racines et états (`infra/envs/<env>/<couche>/`)

Un état Terraform par environnement **et** par couche, pour limiter le rayon d'impact d'un `apply` :

| Couche | Modules | Fréquence de changement |
|---|---|---|
| `foundation` | network, security, data | rare |
| `platform` | tools, api, gateway, review, ingestion, observability | moyenne |
| `agents` | agents | fréquente (chaque release) |
| `frontend` | frontend | fréquente |

Une couche lit les sorties d'une couche inférieure via `terraform_remote_state` ; jamais de dépendance circulaire ni vers une couche supérieure. `infra/global/` contient le bootstrap exécuté une fois par compte : bucket d'état, rôle OIDC GitHub, budgets, SCP.

### Règles

- Providers `hashicorp/aws` en priorité ; `hashicorp/awscc` pour les ressources AgentCore non couvertes. Versions épinglées, `.terraform.lock.hcl` commité.
- Les images conteneur (runtime, Lambdas conteneurisées) sont construites et poussées par la CI ; Terraform reçoit le digest immuable en variable.
- Les données (paramètres fiscaux, corpus juridique, fixtures) ne sont pas gérées par Terraform : elles sont embarquées dans les packages ou chargées par des pipelines applicatifs.
- Aucune ressource créée à la main. Une ressource découverte hors Terraform est importée (bloc `import`) ou détruite.

## 4. Flux d'une question

Tout le flux est du code (`services/agent_runtime/pipeline.py`). Les agents LLM sont des étapes typées. Chaque étape est journalisée dans une trace avec ses versions (prompt, modèle, moteur, millésime, profil).

1. **Entrée** : le BFF appelle le runtime avec le JWT Cognito, l'identifiant de session et le message. Le runtime valide le JWT (autorisation entrante) ; `user_id` = claim `sub`.
2. **Quota** : `usage.consume(user_id)` ; si le quota journalier est atteint, réponse d'attente, fin.
3. **Garde-fou d'entrée** : Bedrock Guardrails sur le message.
4. **Chargement** : profil courant (`profile.get`) et les N derniers messages de la conversation.
5. **Périmètre** (déterministe, `packages/compliance/scope.py`) : si le profil ou la question sort du périmètre (`05-safety-compliance.md` §9), réponse de redirection vers un conseiller, fin.
6. **Planification** (agent `planner`, niveau `capable`) : intention, domaines concernés, questions à traiter, sortie `Plan`.
7. **Complétude** (déterministe, `packages/domain/completeness.py`) : champs bloquants manquants pour ce plan. S'il en manque : agent `collector` formule au plus 3 questions, réponse, fin. Les réponses de l'utilisateur au tour suivant passent par `collector`, qui produit des propositions de mise à jour ; l'utilisateur les confirme dans l'interface.
8. **Spécialistes** (agents `tax`, `estate`, … selon le plan, en parallèle) : chacun renvoie un `SpecialistFinding`.
9. **Vérification déterministe** (`packages/verification`) sur chaque finding : montants, références de calcul, sources, faits utilisés, entrées de calcul cohérentes avec le profil. En cas d'échec, le finding retourne au spécialiste avec la liste des problèmes (au plus 2 itérations), puis réponse prudente sans le finding.
10. **Consolidation** (agent `consolidator`, niveau `capable`) : `DraftRecommendation` avec conflits entre spécialistes explicités.
11. **Vérificateur LLM** (agent `verifier`, modèle différent du consolidateur si possible) : cohérence sémantique, hypothèses, promesses, oublis. Rejet → retour au consolidateur (au plus 2 itérations).
12. **Conformité** (`packages/compliance` + agent `classifier` niveau `fast`) : classification `information_generale` / `recommandation_personnalisee` (union conservatrice des deux avis), formulations interdites, mentions obligatoires ajoutées par le code.
13. **Sortie** :
    - information générale : garde-fou de sortie, réponse diffusée en streaming ;
    - recommandation personnalisée : enregistrement `pending_review`, démarrage du workflow de validation, réponse d'attente composée par le code (accusé de réception, délai, explication pédagogique des règles applicables produite par l'agent `educator` à partir des seuls passages du RAG, sans accès au profil).
14. **Persistance** : messages, findings, rapports, recommandation, événement d'audit.

## 5. Identité et isolation des utilisateurs

- Le même JWT Cognito circule du navigateur au runtime : validé par le BFF (session) puis par le runtime (autorisation entrante).
- Le runtime construit un `ToolContext` (`user_id`, `session_id`, `profile_version`, `env`) **en code** à partir du JWT validé. Chaque appel d'outil transporte ce contexte. Les schémas d'outils exposés au LLM ne contiennent ni `user_id` ni `session_id` : le LLM ne peut pas les fournir.
- Les Lambdas d'outils n'acceptent que des appelants autorisés par IAM (rôle du runtime, rôle de l'API, rôle de la passerelle) et lisent `user_id` uniquement dans le contexte. Tout accès en base est filtré par `user_id`.
- **Backend Gateway** : le runtime appelle la passerelle en MCP avec le JWT de l'utilisateur ; la passerelle valide le JWT et transmet les claims validés à la Lambda cible, dont le handler reconstruit le `ToolContext` — jamais à partir des arguments de l'outil. **À vérifier en phase 5** : si la passerelle ne peut pas transmettre les claims validés à la cible, le backend Gateway est limité aux outils sans donnée utilisateur (`calc`, `legal`, `usage` exclu) et le tableau de comparaison le dit explicitement.
- L'API profil prend `user_id` dans le JWT validé par l'autorisateur d'API Gateway. Les routes back-office exigent le groupe `advisors` et journalisent chaque consultation de dossier.
- Test d'intégration obligatoire : un appel d'outil avec un `user_id` différent de celui du contexte est impossible par construction ; un appel depuis une identité IAM non autorisée est refusé ; un utilisateur sans le groupe `advisors` ne peut pas atteindre les routes back-office.

## 6. Mémoire et historique

| Information | Stockage | Raison |
|---|---|---|
| Faits patrimoniaux | Profil versionné (PostgreSQL) | Source de vérité, auditable, modifiable par l'utilisateur |
| Conversation (messages, findings, traces) | Tables `conversations`, `messages` (PostgreSQL) | Historique consultable par l'utilisateur, suppression RGPD maîtrisée |
| Contexte donné aux agents | Les N derniers messages + profil courant, assemblés par le pipeline | Pas d'extraction automatique de faits par un service de mémoire |
| Préférences (« pas de crypto ») | Profil (`preferences`) | Contraint les recommandations |
| Recommandations et validations | Tables `recommendations`, `reviews` + journal d'audit | Traçabilité |

## 7. Runtime unique

Un seul AgentCore Runtime héberge le pipeline et tous les agents. La séparation des outils par agent est appliquée en code (liste d'outils Strands de chaque agent, `03-agents.md` §12). Le découpage en runtimes séparés n'est envisagé qu'après la V1, si un spécialiste a besoin de son propre rythme de release.

## 8. Modèles

Configuration dans `packages/agents/config/models.yaml`, validée par un schéma Pydantic au démarrage :

```yaml
aws_region: eu-central-1
tiers:
  capable: TODO_VERIFY   # profil d'inférence UE du modèle Claude le plus capable disponible dans la région
  fast: TODO_VERIFY      # profil d'inférence UE d'un modèle Claude rapide
  judge: TODO_VERIFY     # modèle juge, différent des modèles générateurs (06-evals-mlops.md §7)
embedding:
  model_id: TODO_VERIFY  # modèle d'embedding multilingue disponible dans la région
  dimensions: TODO_VERIFY
agents:
  planner:      {tier: capable, temperature: 0, max_tokens: 2000}
  collector:    {tier: fast,    temperature: 0, max_tokens: 1500}
  tax:          {tier: capable, temperature: 0, max_tokens: 6000, max_tool_calls: 12}   # différé
  estate:       {tier: capable, temperature: 0, max_tokens: 6000, max_tool_calls: 12}
  consolidator: {tier: capable, temperature: 0, max_tokens: 6000}
  verifier:     {tier: capable, temperature: 0, max_tokens: 4000}
  classifier:   {tier: fast,    temperature: 0, max_tokens: 500}
  educator:     {tier: fast,    temperature: 0, max_tokens: 2000}
  extractor:    {tier: fast,    temperature: 0, max_tokens: 4000}   # différé
limits:
  max_total_tokens_per_question: 400000
  max_specialist_iterations: 2
  max_verifier_iterations: 2
```

Les `TODO_VERIFY` sont remplis en phase 5 à partir de la sortie de `aws bedrock list-inference-profiles --region <région>` et de `aws bedrock list-foundation-models`. Le démarrage échoue si un `TODO_VERIFY` subsiste.

## 9. Environnements et région

| Environnement | Compte AWS | Usage | Paramètres `draft` acceptés | Accès |
|---|---|---|---|---|
| `dev` | dédié | développement, tests d'intégration | oui | `apply` local autorisé |
| `staging` | dédié | démonstration, golden cases, trafic synthétique, évaluation shadow, tests de charge et de restauration | oui | CI uniquement |
| `prod` | dédié | exerce la promotion, les approbations et les garde-fous ; mode démonstration, aucun utilisateur | non | CI uniquement, approbation manuelle |

Région : `eu-central-1` pour tous les services ; profils d'inférence cross-region UE pour Bedrock (les données restent dans l'UE, ce qui est documenté dans l'analyse d'impact RGPD).
