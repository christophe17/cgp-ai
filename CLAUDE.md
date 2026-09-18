# CLAUDE.md — Plateforme de conseil patrimonial multi-agents

Ce fichier est lu en premier par Claude Code. Il donne le contexte, les règles non négociables et l'ordre de lecture de la documentation. Le dossier `docs/` décrit intégralement ce qui doit être construit : c'est la spécification vivante du projet.

## 1. Le projet en une phrase

Une application B2C qui aide des particuliers à analyser leur patrimoine grâce à un système **multi-agents spécialisés** déployé sur **AWS (Amazon Bedrock + Bedrock AgentCore)**, avec des calculs déterministes, des sources juridiques datées et une validation humaine par un conseiller pour toute recommandation personnalisée. Dans cette version, **un seul vertical est construit : la transmission** (succession, donation, assurance-vie au décès, démembrement).

## 2. Contexte de réalisation

- **Ce projet est un portfolio en production, sans associés** (décision du 2026-09-18). Il ne s'ouvrira pas à de vrais clients ; le mode démonstration (`docs/05-safety-compliance.md` §10) est son état final dans tous les environnements. Sa valeur est double : un système multi-agents **déployé, exploité et mesuré** au niveau production, et le **support d'apprentissage** de son auteur (`docs/09-learning-method.md`).
- Le projet est construit par Claude Code, seul. Aucun professionnel n'est disponible et aucune relecture professionnelle n'est prévue. Tout contenu métier (paramètres fiscaux, règles de conformité, cas de référence, prompts, textes réglementaires) est produit **à partir de sources officielles consultées au moment de l'écriture**, marqué `draft`, et le reste. Le rapport de validation (`docs/06-evals-mlops.md` §8) est produit quand même : il montre comment une relecture se brancherait.
- **Périmètre fonctionnel réduit, infrastructure complète** (`docs/07-roadmap.md`, « Périmètre ») : un seul spécialiste (`estate`), une question de référence, mais trois comptes AWS, toutes les couches Terraform, la chaîne de promotion, la validation conseiller, l'ingestion, l'observabilité, les sauvegardes. L'agent `tax`, les documents et tout ce qui est marqué V2+ sont spécifiés dans `docs/` mais **différés**.
- **L'argument du portfolio est la mesure** : ablation du retrieval, juge calibré, intervalles de confiance, coût et latence par question, trafic synthétique, dérive, évaluation shadow, attaques mesurées, comparaison de modèles (`docs/06-evals-mlops.md`). Une phase sans ses chiffres n'est pas terminée.
- **J'apprends en lisant du code expliqué** : Claude Code écrit 100 % du code, et pour chaque phase le notebook ou le guide d'infrastructure qui l'explique (`docs/09-learning-method.md`). Une phase sans son matériel d'apprentissage n'est pas terminée.
- L'infrastructure est gérée **exclusivement en Terraform** et chaque livrable, dès la phase 0, est de **qualité production** (`docs/08-production-readiness.md`). Il n'y a pas de version jetable.

## 3. Ordre de lecture obligatoire

Avant d'écrire du code pour une tâche, lis les documents pertinents :

1. `docs/01-architecture.md` — architecture, mapping AWS, découpage Terraform, flux d'une question, identité
2. `docs/02-domain-model.md` — modèle de données patrimonial, règles de complétude et de périmètre, persistance
3. `docs/03-agents.md` — pipeline d'exécution et spécification de chaque agent
4. `docs/04-tools-and-data.md` — moteur de calcul, référentiel de paramètres, RAG juridique, outils
5. `docs/05-safety-compliance.md` — conformité, sécurité, modèle de menaces, RGPD, garde-fous, mode démonstration
6. `docs/06-evals-mlops.md` — tests, évaluations, CI/CD, observabilité, rapport de validation
7. `docs/07-roadmap.md` — Definition of Done, phases et critères d'acceptation
8. `docs/08-production-readiness.md` — exigences de qualité production
9. `docs/09-learning-method.md` — contrat des notebooks et des guides d'infrastructure, carte des compétences AWS, règles de conversation

Travaille **phase par phase** selon `docs/07-roadmap.md`. Ne commence pas une phase tant que les critères d'acceptation de la précédente ne sont pas remplis.

**Reprise de session** : relis `CLAUDE.md`, `STATE.md` (phase en cours, chiffres actuels, décisions en attente) et `JOURNAL.md` (historique daté, incidents) avant de répondre.

## 4. Règles non négociables

1. **Aucun calcul financier ou fiscal par le LLM.** Tout montant (impôt, droits de succession, rendement, mensualité, valeur de démembrement…) est produit par le moteur de calcul `packages/calc_engine` (Python pur, testé). Les agents l'appellent via un outil.
2. **Aucun paramètre réglementaire dans les prompts ni dans le code applicatif.** Barèmes, abattements, plafonds, taux : uniquement dans `packages/params`, versionné par millésime. Si une valeur manque, l'outil lève une erreur explicite ; on n'invente jamais de valeur par défaut.
3. **Aucune valeur réglementaire de mémoire.** Chaque valeur du référentiel est recopiée depuis la source officielle consultée au moment de l'écriture (Légifrance, BOFiP, impots.gouv.fr, service-public.fr), avec référence légale, URL, date de consultation et statut `draft`. Une valeur dont la source n'a pas pu être consultée reste `TODO_SOURCE` et fait échouer tout calcul qui en dépend. Seul un professionnel passe une valeur à `validated`.
4. **Toute affirmation juridique ou fiscale d'un agent cite une source** issue du RAG (identifiant de passage, référence, date de version). Sans source, l'agent répond qu'il ne sait pas.
5. **Le profil patrimonial structuré est la source de vérité**, pas la conversation. Les agents lisent le profil via un outil typé et ne l'écrivent jamais directement : ils proposent des mises à jour que l'utilisateur confirme dans l'interface.
6. **Aucune recommandation personnalisée n'atteint l'utilisateur sans** vérification déterministe, agent vérificateur, garde-fou conformité et validation humaine par un conseiller.
7. **Données personnelles** : région AWS européenne uniquement, chiffrement KMS partout, aucune donnée client dans les journaux en clair.
8. **Vérifie les API AWS avant de les utiliser.** Bedrock AgentCore évolue vite. Avant d'écrire du code ou du Terraform pour un service AgentCore, consulte la documentation officielle AWS ou la version installée du SDK. Pour Terraform, vérifie la couverture de la ressource dans le registre du provider `aws`, sinon `awscc`. Ne devine jamais un nom de champ, de ressource ou d'identifiant de modèle : les identifiants de modèles sont obtenus par `aws bedrock list-inference-profiles` et placés en configuration.
9. **Infrastructure uniquement en Terraform.** Toute ressource AWS est déclarée en HCL dans `infra/`. Aucune ressource créée à la main ni par un script hors CI. Pas de CDK, SAM, Serverless Framework ni CloudFormation brut.
10. **Qualité production dès la première ligne.** Chaque livrable respecte `docs/08-production-readiness.md`. Une phase n'est terminée que si la Definition of Done de `docs/07-roadmap.md` est remplie. Pas de « on durcira plus tard ».
11. **Le contrôle du flux est du code, pas du LLM.** L'enchaînement périmètre → planification → complétude → spécialistes → vérification → conformité → validation est implémenté en Python dans le runtime ; les agents LLM sont des étapes appelées par ce code. `user_id`, `session_id`, versions, statuts et transitions ne sont jamais fournis par le LLM.
12. **Tout contenu métier généré porte un statut de validation** (`draft`, et il le reste : aucune validation professionnelle n'est prévue) et apparaît dans le rapport de validation. Ce qui n'est pas validé est présenté comme tel dans l'interface.
13. **Aucune conclusion sur une seule exécution.** Toute comparaison (prompt, modèle, configuration de retrieval) se fait sur N exécutions avec intervalle de confiance ; un écart couvert par l'intervalle est publié comme non significatif (`docs/06-evals-mlops.md` §4).
14. **Le matériel d'apprentissage exécute le vrai code.** Un notebook n'implémente rien ; un guide d'infrastructure lit le HCL réel (`docs/09-learning-method.md`).

## 5. Stack technique

- **Langage** : Python 3.12 pour tout le backend. HCL (Terraform) pour l'infrastructure. TypeScript pour le frontend.
- **Gestion de dépendances** : `uv`, workspace monorepo, `uv.lock` commité.
- **Framework d'agents** : Strands Agents, déployé sur AgentCore Runtime (image conteneur construite par la CI).
- **Outils** : Lambdas, invoquées directement (backend de référence) et via AgentCore Gateway en MCP avec AgentCore Identity (second backend). Les deux sont mesurés (`docs/06-evals-mlops.md` §13) ; la sélection est un feature flag SSM par environnement. AgentCore Memory et Policy ne sont pas utilisés (`docs/09-learning-method.md` §4).
- **Modèles** : Claude via Amazon Bedrock (API Converse), profils d'inférence UE. Identifiants **dans la configuration** (`packages/agents/config/models.yaml`), jamais en dur.
- **Région** : `eu-central-1` par défaut, variable unique `aws_region`. Si un service requis n'y est pas disponible, choisir la région UE la plus proche où tous le sont et changer la variable.
- **Base de données** : Aurora PostgreSQL Serverless v2 (une instance par environnement, scale-to-zero en `dev` et `staging`), extension `pgvector` pour le RAG. Accès depuis les Lambdas via RDS Proxy avec authentification IAM, `psycopg` 3, migrations Alembic.
- **Validation** : Pydantic v2 pour tous les schémas (profil, entrées/sorties d'outils, sorties d'agents, configuration).
- **IaC** : Terraform exclusivement. Providers `hashicorp/aws` en priorité, `hashicorp/awscc` pour les ressources AgentCore non couvertes. Versions épinglées, `.terraform.lock.hcl` commité. Un module par domaine, un état distant S3 par environnement et par couche. Découpage dans `docs/01-architecture.md` §3, règles dans `docs/08-production-readiness.md` §2.
- **Environnements** : trois comptes AWS distincts (`dev`, `staging`, `prod`). `staging` héberge la démonstration. `staging` et `prod` ne sont déployés que par la CI.
- **Tests** : pytest, hypothesis pour le moteur de calcul, testcontainers (PostgreSQL + pgvector) pour le stockage et le RAG, moto pour les appels AWS simples. Infra : `terraform validate`, tflint, trivy (config), `terraform test` quand un module le justifie.
- **Qualité** : ruff ; mypy strict sur `packages/domain`, `packages/calc_engine`, `packages/params`, `packages/compliance`, `packages/verification`.
- **Frontend** : Next.js (App Router, TypeScript), Amplify Hosting (SSR), Amplify Auth (Cognito). Les routes serveur Next.js servent de BFF vers AgentCore Runtime et l'API profil. Vitest pour les tests unitaires, Playwright pour les parcours de bout en bout.
- **Local** : `docker compose` (PostgreSQL + pgvector), CLI `cgp` pour exécuter le pipeline en local contre Bedrock avec les outils en processus.

## 6. Structure du dépôt

```
.
├── CLAUDE.md · STATE.md · JOURNAL.md
├── Makefile                   # cibles dev, test, notebooks-ci, notebooks-full, eval, tf-check, tf-plan, tf-apply, validation-report
├── src/cgp/                   # CLI opérateur `cgp` (ask, eval, traffic, validation-report) ; dépend de tous les packages
├── docs/                      # spécification (ce dossier) ; docs/infra/ : guides d'infrastructure ; docs/runbooks/ ; docs/compliance/
├── packages/
│   ├── domain/                # modèles Pydantic du profil, règles de complétude et de périmètre
│   ├── calc_engine/           # moteur de calcul déterministe (aucune dépendance AWS)
│   ├── params/                # référentiel de paramètres versionnés (YAML embarqués + chargeur)
│   ├── storage/               # accès PostgreSQL (dépôts typés), migrations Alembic
│   ├── legal_rag/             # ingestion et interrogation du corpus juridique (pgvector + plein texte)
│   ├── compliance/            # règles déterministes : classification, formulations, mentions, périmètre
│   ├── verification/          # contrôles déterministes des sorties d'agents
│   └── agents/                # agents Strands, prompts versionnés, pipeline, adaptateurs d'outils, config modèles
├── services/
│   ├── agent_runtime/         # conteneur AgentCore Runtime : point d'entrée, pipeline, streaming
│   ├── tools_lambda/          # Lambdas d'outils : profile, calc, legal, documents, usage
│   ├── profile_api/           # API HTTP pour le frontend et le back-office (API Gateway + Lambda)
│   ├── review_workflow/       # validation conseiller (Step Functions + Lambdas)
│   ├── ingestion/             # pipeline d'ingestion du corpus juridique (Step Functions + Lambdas)
│   └── migrations/            # Lambda d'exécution des migrations Alembic, invoquée par la CI
├── infra/                     # Terraform : modules/<domaine>/, envs/<env>/<couche>/, global/
├── evals/
│   ├── golden_cases/          # cas patrimoniaux de bout en bout (+ inbox/)
│   ├── agents/                # cas par agent
│   ├── retrieval/             # qualité du RAG, ablation/
│   ├── compliance/            # classification et formulations
│   ├── judge/                 # rubriques, annotations humaines, calibration
│   ├── security/              # attaques fabriquées, must_block
│   ├── traffic/               # générateur de trafic, profils, dérive, shadow
│   ├── cassettes/             # réponses Bedrock enregistrées (mode sample)
│   └── runners/               # exécuteur commun, bootstrap, rapport HTML
├── notebooks/                 # matériel d'apprentissage (docs/09) ; cassettes/ et results/<date>/
├── frontend/                  # Next.js
├── fixtures/                  # profils fictifs, documents de test, jeu de démonstration
└── .github/workflows/
```

## 7. Conventions de travail

- Code et identifiants en **anglais**, documentation et textes utilisateur en **français**.
- Packages du workspace : distribution `cgp-<nom>` dans `packages/<nom>` ou `services/<nom>`, module importable `cgp_<nom>` (`src/` layout), pour éviter toute collision avec des paquets tiers (`agents`, `params`, `storage`).
- Commits conventionnels (`feat:`, `fix:`, `chore:`…), une fonctionnalité par PR.
- Chaque fonction du moteur de calcul a : une docstring citant la référence légale et la date qui fait foi (année des revenus, date du décès, date de la donation), des tests unitaires chiffrés avec la source de chaque valeur attendue, des tests de propriété quand c'est pertinent.
- Chaque agent a : un prompt versionné dans `packages/agents/prompts/<agent>/vN.md`, un schéma de sortie Pydantic, au moins 5 cas d'éval.
- Qualité production pour tout code livré : typé, testé, journalisation structurée sans PII, erreurs explicites, outils idempotents, timeouts et retries définis, pas de code mort ni de `TODO` hors `TODO_SOURCE`.
- Toute modification d'infrastructure passe par une PR avec le `terraform plan` en commentaire. `apply` en local uniquement vers `dev`. Aucune ressource créée à la main dans la console.
- **Ambiguïté métier** (règle fiscale, cas limite) : ne t'arrête pas. Choisis l'interprétation la plus prudente (celle qui protège l'utilisateur et évite d'affirmer), implémente-la, documente l'hypothèse dans la docstring et dans le cas de test, marque l'artefact `draft`. L'hypothèse reste visible dans le rapport de validation.
- Les décisions structurantes s'écrivent directement dans `docs/` : les documents sont la spécification à jour, il n'y a pas de journal de décisions séparé.
- Le marqueur **[À VALIDER]** dans `docs/` signale un point qu'un professionnel devrait confirmer si le service s'ouvrait un jour. Il ne bloque pas la construction et n'est pas levé dans ce projet.

## 8. Commandes utiles (à maintenir à jour)

```bash
uv sync                                  # installer
make dev-up                              # PostgreSQL + pgvector en local (docker compose) et migrations
uv run pytest                            # tests unitaires et d'intégration locale
uv run pytest evals/ -m golden           # évals de référence (Bedrock requis)
uv run ruff check . && uv run mypy packages/
uv run cgp ask --profile fixtures/profiles/couple_2_enfants_av.json "Si je décède, que paieront mes enfants ?"
make validation-report                   # liste tout le contenu métier en attente de validation
make eval                                # suite d'évals complète contre Bedrock, rapport HTML comparatif
make notebooks-ci                        # notebooks en mode sample (cassettes, sans réseau), comme la CI
make notebooks-full                      # notebooks contre dev, chiffres archivés dans notebooks/results/<date>/
uv run cgp eval annotate                 # annotation humaine pour la calibration du juge
uv run cgp traffic --profile nominal --env staging   # rejeu de trafic synthétique
make tf-check                            # fmt -check, validate, tflint, trivy sur tout infra/
make tf-plan ENV=dev LAYER=platform      # plan d'une couche (infra/envs/dev/platform)
make tf-apply ENV=dev LAYER=platform     # apply local autorisé pour dev uniquement ; staging/prod via la CI
```
