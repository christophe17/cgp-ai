# 07 — Plan d'implémentation par phases

Claude Code : travaille une phase à la fois. À la fin de chaque phase, vérifie les critères d'acceptation, coche les cases, mets à jour le rapport de validation, `STATE.md` et `JOURNAL.md`, et livre le debrief (`09-learning-method.md` §5). Ne commence pas la phase suivante tant que l'acceptation n'est pas remplie.

## Périmètre : un seul vertical, une infrastructure complète

**Décision du 2026-09-18.** Le projet est un **portfolio en production**, sans associés. Il ne s'ouvrira pas à de vrais clients : le mode démonstration (`05-safety-compliance.md` §10) est son état final, dans tous les environnements. Tout contenu métier reste `draft` ; le rapport de validation est produit quand même, parce qu'il montre comment une relecture professionnelle se brancherait.

Le périmètre fonctionnel est réduit à **un vertical** : **la transmission** — succession, donation, assurance-vie au décès, démembrement — porté par le seul spécialiste `estate`. La question de référence est : *« Si je décède, que paieront mes enfants ? »* sur un profil fictif. Sont **différés** (spécifiés dans les documents, non construits) : l'agent `tax` et les fonctions d'impôt sur le revenu et de PER, l'agent `extractor` et l'upload de documents, tout ce qui est marqué V2 et au-delà.

L'**infrastructure, elle, n'est pas réduite** : trois comptes, toutes les couches Terraform, la chaîne de promotion complète, la validation conseiller, l'ingestion planifiée, l'observabilité, les sauvegardes et la restauration. C'est le terrain d'apprentissage AWS (`09-learning-method.md` §3-4) et la preuve d'exploitation du portfolio. Le compte `prod` existe pour exercer la promotion et les garde-fous ; il reste en mode démonstration et sans utilisateur.

Ce qui fait la valeur du portfolio n'est pas la largeur fonctionnelle mais **la mesure** : chaque phase à partir de la 4 produit des chiffres avec leur incertitude (`06-evals-mlops.md`), et le README s'ouvre sur ce tableau (phase 9).

## Definition of Done (toutes phases)

Une tâche n'est « faite » que si :

1. le code est typé (mypy strict là où `CLAUDE.md` l'exige), testé (unitaires, propriétés, stockage ou intégration selon le cas) et passe ruff ;
2. l'infrastructure associée est en Terraform, `plan` propre en `dev`, aucune ressource créée à la main ;
3. les journaux sont structurés et sans PII ; les métriques et alarmes utiles existent ;
4. la documentation est à jour (`docs/`, README du module, runbook si composant exploité) ;
5. les points de `08-production-readiness.md` applicables à la phase sont cochés ;
6. tout contenu métier créé porte son statut de validation et apparaît dans le rapport de validation ;
7. **le matériel d'apprentissage de la phase est livré** : notebooks exécutés en mode `sample` dans la CI, guides d'infrastructure relus avec le `plan` ;
8. `JOURNAL.md` et `STATE.md` sont à jour ; la PR a été relue, `terraform plan` joint pour l'infrastructure.

## Phase 0 — Socle du dépôt et des comptes

- [x] Monorepo `uv` avec les packages et services de `CLAUDE.md` §6 (squelettes, `pyproject.toml`, README par package) ; `JOURNAL.md`, `STATE.md`
- [x] ruff, mypy, pytest, `nbmake`, pre-commit (ruff, mypy, `terraform fmt`, `terraform validate`, tflint, détection de secrets)
- [x] `Makefile` : `dev-up`, `test`, `lint`, `notebooks-ci`, `notebooks-full`, `validation-report`, `tf-check`, `tf-plan`, `tf-apply`
- [x] `docker-compose.yml` : PostgreSQL 16 + pgvector
- [x] Vérification de la disponibilité dans `eu-central-1` de : AgentCore Runtime, Observability, Evaluations, Gateway et Identity (et le périmètre exact d'AgentCore Policy, consigné), Bedrock (modèles Claude via profils UE, modèle d'embedding, au moins un modèle non-Claude pour la comparaison de la phase 8), Aurora Serverless v2, Amplify Hosting, Cognito, Step Functions, SES. Résultat consigné dans `infra/README.md` ; si un service manque, région changée dans la variable unique
- [ ] Comptes AWS `dev`, `staging`, `prod` dans une organisation ; SCP (régions UE, pas de clés d'accès IAM utilisateur, pas de désactivation de CloudTrail/KMS/sauvegardes) ; IAM Identity Center avec MFA
  - Exceptions de bootstrap, documentées pas à pas dans le guide `00-bootstrap.md` et exécutées une seule fois : création de l'organisation depuis le compte existant (qui devient le compte de gestion), activation d'IAM Identity Center (console uniquement), enregistrement du premier appareil MFA, puis bascule de l'accès local sur `aws sso login`. Tout le reste (comptes membres, SCP, budgets, rôles) est en Terraform dans `infra/global/`.
  - Prérequis à fournir par moi : trois adresses e-mail distinctes pour les comptes membres (l'adressage `+` fonctionne), le plafond de dépense mensuel, la confirmation que le compte existant devient le compte de gestion.
- [ ] `infra/global/` par compte : bucket d'état S3 chiffré KMS, versionné, verrouillage natif ; rôle OIDC GitHub ; budgets AWS avec alarmes
- [x] Squelette Terraform : modules vides avec variables et outputs, racines `envs/<env>/<couche>/`, versions épinglées
- [x] GitHub Actions : lint + tests + notebooks `sample` ; `fmt`/`validate`/tflint/trivy/`plan` sur chaque PR ; `apply` `dev` à la fusion ; `staging`/`prod` derrière une approbation ; environnements GitHub protégés
- [x] **Apprentissage** : notebook `00_visite_guidee` ; guide `00-bootstrap.md` ; première version du guide `10-ci-cd.md` (partie OIDC et environnements) ; carte des compétences (`09-learning-method.md` §4) initialisée

**Acceptation** : `uv run pytest` et `make notebooks-ci` passent en CI ; `terraform plan` passe sur toutes les couches de `dev` en CI ; un `apply` manuel vers `staging` ou `prod` est impossible (aucun credential local).

## Phase 1 — Domaine et paramètres

- [ ] Modèles Pydantic du profil (`02-domain-model.md` §2), union discriminée des actifs, validateurs, tests unitaires et de propriété — le schéma complet est implémenté, seules les règles de complétude du vertical sont actives
- [ ] Règles de complétude pour `estate`, `gift`, `life_insurance` (§3) et règles de périmètre (§4) avec tests
- [ ] Migration de schéma du profil (`schema_version`) et fixtures de profils fictifs (`fixtures/profiles/`, au moins 10 situations familiales orientées transmission : célibataire, marié sous chaque régime, pacsés, famille recomposée, enfant prédécédé avec descendants, donations antérieures dans et hors délai de rappel, assurance-vie avant/après 70 ans)
- [ ] Package `params` : chargement YAML, validation, `params.get`, `ParamNotAvailable`, `ParamNotValidated`, `params diff`
- [ ] Renseignement des paramètres du vertical (`04-tools-and-data.md` §2, liste « transmission ») depuis les sources officielles, statut `draft`, avec référence, URL et date de consultation
- [ ] Test AST d'absence de littéral réglementaire dans `calc_engine`
- [ ] Générateur du rapport de validation (`make validation-report`) couvrant les paramètres

**Acceptation** : tests verts ; aucun `TODO_SOURCE` pour les paramètres du vertical, ou liste explicite des paramètres non trouvés avec la raison ; rapport de validation généré.

## Phase 2 — Moteur de calcul

- [ ] `estate_devolution`, `inheritance_tax`, `gift_tax`, `dismemberment_value`, `life_insurance_death_tax`, `replay`
- [ ] `CalcResult` avec étapes détaillées et `inputs_origin`
- [ ] Cas unitaires YAML par fonction (au moins 8 par fonction, avec `expected_source` : simulateur officiel daté ou calcul manuel détaillé), statut `draft`
- [ ] Tests de propriété
- [ ] Rapport de validation étendu aux cas du moteur
- [ ] **Apprentissage** : notebook `01_calcul_deterministe`

**Acceptation** : couverture ≥ 95 % ; tous les cas passent ; tests de propriété verts ; pour les droits de succession, au moins 5 cas dont la valeur attendue vient du simulateur officiel de service-public.fr.

## Phase 3 — Données, outils et fondations d'infrastructure

- [ ] Couche `foundation` : modules `network`, `security` (KMS, rôles, Cognito avec MFA obligatoire et groupe `advisors`, WAF), `data` (Aurora Serverless v2 + pgvector, RDS Proxy, S3, AWS Backup, PITR, `deletion_protection`)
- [ ] Package `storage` : schéma PostgreSQL (`02-domain-model.md` §7), migrations Alembic, dépôts typés, `audit_events` en ajout seul, tests testcontainers
- [ ] Service `migrations` (Lambda invoquée par la CI)
- [ ] Contrat d'outils (`04-tools-and-data.md` §5), `ToolInvoker` local et Lambda
- [ ] Lambdas `profile`, `calc`, `usage` : timeouts, retries, DLQ, idempotence, journaux structurés sans PII (la Lambda `documents` est différée)
- [ ] Workflow `gdpr_delete` et export du profil
- [ ] Tests d'intégration en `dev` : isolation entre utilisateurs, refus d'une identité IAM non autorisée, suppression RGPD complète, restauration PITR exécutée et documentée
- [ ] Alarmes de base (erreurs Lambda, DLQ non vide, throttling) reliées au canal d'astreinte
- [ ] **Apprentissage** : notebook `02_anatomie_d_un_outil` ; guides `01-network.md`, `02-security.md`, `03-data.md`, `04-tools.md`

**Acceptation** : les outils répondent en `dev` via `LambdaToolInvoker` et en local via `LocalToolInvoker` avec les mêmes tests ; une tentative d'accès croisé est refusée et journalisée ; la suppression RGPD ne laisse aucune ligne ; une restauration de la base a été exécutée en `dev` et chronométrée.

## Phase 4 — RAG juridique, mesuré

- [ ] Package `legal_rag` : modèles, découpage par article et par paragraphe BOFiP, embeddings Bedrock, tables `legal_documents` et `legal_chunks`, recherche hybride avec filtrage temporel
- [ ] Service `ingestion` : Step Functions + Lambdas, sources open data DILA et BOFiP, détection de changement, rapport de différences ; module Terraform `ingestion`
- [ ] Ingestion initiale du corpus du vertical en `dev` (Code civil livre III, CGI droits de mutation à titre gratuit et assurance-vie, BOFiP ENR-DMTG, fiches service-public.fr correspondantes)
- [ ] Lambda `legal` : `legal.search`, `legal.get_passage`
- [ ] `evals/retrieval/` : au moins 50 questions de transmission avec les références attendues ; rappel@5, rappel@10, MRR ; seuils dans `thresholds.yaml`
- [ ] **Ablation chiffrée** (`06-evals-mlops.md` §9) : plein texte seul, dense seul, hybride RRF, hybride + reranker ; N exécutions, intervalles bootstrap ; la configuration retenue est celle du tableau, pas celle du tutoriel
- [ ] **Apprentissage** : notebook `03_du_texte_de_loi_au_passage` ; partie ingestion du guide `07-workflows.md`

**Acceptation** : tableau d'ablation publié avec intervalles ; seuils fixés à partir de la configuration retenue ; filtrage temporel vérifié par test ; `legal.get_passage` rejette un hash incorrect.

## Phase 5 — Agents, pipeline, runtime et harness d'évaluation

- [ ] Configuration des modèles : identifiants obtenus par la CLI AWS, `TODO_VERIFY` remplacés, validation au démarrage
- [ ] Agents `planner`, `collector` (mode questions et mode extraction depuis les réponses de l'utilisateur), `estate`, `consolidator`, `verifier`, `classifier`, `educator` (Strands) : prompts v1, schémas de sortie, listes d'outils, test d'exposition des outils
- [ ] `packages/verification` : les 6 contrôles déterministes avec tests
- [ ] `packages/compliance` : `rules/classification.yaml`, `rules/forbidden_phrases.yaml`, `rules/mentions.yaml`, `rules/out_of_scope.yaml`, gabarits (`templates/`), tout en `draft`
- [ ] Pipeline (`services/agent_runtime/pipeline.py`) : 16 étapes, budgets, itérations, réponses prudentes, streaming ; tests avec agents simulés
- [ ] CLI `cgp ask` en local contre Bedrock avec outils en processus
- [ ] Module Terraform `agents` : dépôt ECR, AgentCore Runtime (image construite par la CI, autorisation JWT Cognito), Guardrails, rôle d'exécution ; instrumentation OpenTelemetry ; module `api` (API profil minimale nécessaire au pipeline)
- [ ] Module Terraform `gateway` : AgentCore Gateway avec les Lambdas d'outils en cibles MCP, autorisation JWT Cognito, AgentCore Identity pour l'authentification sortante ; `GatewayToolInvoker` ; feature flag SSM de sélection du backend ; mêmes tests d'intégration que le backend Lambda, dont l'accès croisé et la propagation d'identité (`01-architecture.md` §5)
- [ ] **Comparaison des backends d'outils** (`06-evals-mlops.md` §13) : Lambda direct contre Gateway — latence p95 par appel et par question, coût, taux d'erreur, identité ; décision par environnement documentée
- [ ] Quotas Bedrock vérifiés et demandés ; gestion du throttling ; kill switch par agent et global (paramètre SSM), testé
- [ ] **Harness d'évaluation** (`06-evals-mlops.md` §2-6) : exécuteur commun à `evals/agents`, `evals/compliance`, `evals/golden_cases` ; N exécutions par cas, intervalles bootstrap ; historique des runs en base ; rapport HTML ; GitHub Action bloquante sur régression
- [ ] `evals/agents/<agent>/` : au moins 5 cas par agent ; `evals/compliance/` : au moins 40 sorties étiquetées
- [ ] **Juge calibré** (`06-evals-mlops.md` §7) : rubriques, 40 sorties annotées à la main par moi via une CLI, kappa mesuré, biais documentés ; le juge n'entre dans un gate qu'une fois calibré
- [ ] Mesure du coût et de la latence par question sur les cas d'éval, décomposée par agent et par étape ; tableau de bord
- [ ] **Apprentissage** : notebooks `04_anatomie_du_pipeline`, `05_le_harness_d_evaluation`, `06_anatomie_d_une_trace`, `12_gateway_ou_lambda` ; guides `05-api.md`, `06-agents.md` (Runtime, Guardrails, Gateway, Identity), `08-observability.md`

**Acceptation** : la question de référence sur un profil fictif produit, en `dev`, une réponse dont tous les montants proviennent d'appels `calc.*`, toutes les règles sont sourcées, la classification est correcte ; la vérification déterministe rejette un finding volontairement corrompu ; le kill switch coupe le service proprement ; kappa du juge publié ; coût moyen et latence p95 par question documentés avec intervalles.

## Phase 6 — Validation conseiller et back-office

- [ ] Service `review_workflow` : Step Functions (task token, relances, expiration, SLA), Lambdas, notifications SES ; module Terraform `review`
- [ ] API profil (`services/profile_api`) : profil, versions, `confirm_update`, conversations, recommandations, export, suppression ; routes conseiller (file, détail, décision) protégées par le groupe `advisors` ; journalisation des consultations
- [ ] Export horaire de `audit_events` vers S3 Object Lock
- [ ] Tests d'intégration : parcours recommandation → validation → publication ; expiration si le profil change ; refus d'un utilisateur sans le groupe
- [ ] **Apprentissage** : notebook `07_validation_et_audit` ; guide `07-workflows.md` complété

**Acceptation** : parcours complet testé de bout en bout en `dev` ; un utilisateur sans le groupe `advisors` est refusé ; l'export d'audit est immuable (une suppression tentée est refusée et journalisée).

## Phase 7 — Frontend

- [ ] Next.js (App Router) sur Amplify Hosting, Amplify Auth (Cognito, MFA), module Terraform `frontend` avec WAF
- [ ] BFF : routes serveur pour le chat (relais du flux SSE vers le runtime avec le JWT) et pour l'API profil
- [ ] Parcours utilisateur : onboarding précontractuel (`05-safety-compliance.md` §1), questionnaire profil orienté transmission, vue patrimoine, chat avec affichage des calculs pas à pas et des sources, propositions de mise à jour à confirmer champ par champ, historique des conversations, suivi des recommandations en validation, export et suppression du compte (upload de documents différé)
- [ ] Back-office `/advisor` : file de validation, détail complet, approuver/modifier/rejeter, rapport de validation
- [ ] Mode démonstration : bandeau, invitations, avertissements
- [ ] Tests Vitest ; parcours Playwright contre `staging`
- [ ] Accessibilité (navigation clavier, contrastes, labels) et responsive
- [ ] **Apprentissage** : guide `09-frontend.md`

**Acceptation** : un utilisateur de test crée son profil, pose la question de référence, reçoit une réponse d'attente, et le conseiller de démonstration valide la recommandation qui s'affiche ensuite ; parcours Playwright verts en `staging`.

## Phase 8 — Mesure et exploitation

Tout ce qui suppose des utilisateurs se mesure sur un **trafic synthétique** ; le README dit ce que cette simulation ne capture pas (`06-evals-mlops.md` §10).

- [ ] 30 golden cases (`06-evals-mlops.md` §2), N exécutions, intervalles, quality gates bloquants dans le pipeline
- [ ] AgentCore Evaluations en ligne (10 %), dashboards et alarmes complets
- [ ] **Générateur de trafic** : rejeu des golden cases et des cas d'agents selon des profils configurables (débit, rafales, part hors périmètre, dérive de la distribution dans le temps) contre `staging`
- [ ] **Sous charge** : p50/p95/p99 par étape, TTFT ; coût par question par profil de trafic, **extrapolé au mois** pour deux volumes cibles proposés
- [ ] **Dérive** : détection sur la distribution entrante et sur les évals en ligne ; une dérive contrôlée injectée depuis le générateur ; **nombre de requêtes avant déclenchement** publié
- [ ] **Évaluation shadow** (`06-evals-mlops.md` §11) : rejeu du golden set et d'un profil de trafic sur une nouvelle version de prompt et sur un changement de modèle, tableau des écarts, décision go/no-go documentée
- [ ] **Sécurité mesurée** (`06-evals-mlops.md` §12) : au moins 5 attaques fabriquées (message, passage RAG empoisonné, document empoisonné, tentative de faire écrire le profil, tentative d'exfiltration par les citations) ; taux de blocage à chaque contrôle, avant et après Guardrails ; tests d'accès croisé ; test d'absence de PII dans les journaux ; analyse statique Terraform sans finding critique ou élevé
- [ ] **Comparaison de modèles** (`06-evals-mlops.md` §13) : deux ou trois modèles Bedrock disponibles dans la région, dont un non-Claude si possible, sur le golden set : qualité, coût, latence, avec intervalles ; décision par niveau (`capable`, `fast`) documentée
- [ ] Test de charge sur `staging` (profil cible de `08-production-readiness.md` §4) ; test de restauration complète avec RPO/RTO mesurés
- [ ] SLO, alarmes reliées à l'astreinte, runbooks (`08-production-readiness.md` §6, dont les trois obligatoires : fournisseur indisponible, qualité dégradée sans changement de code, coût triplé dans la nuit) ; rollback exécuté en `staging` ; promotion vers `prod` exercée une fois, en mode démonstration
- [ ] `docs/compliance/` : registre des traitements et AIPD en première version ; gabarits réglementaires `draft`
- [ ] Jeu de démonstration : 3 profils fictifs complets, comptes de démonstration (utilisateurs et conseiller), script de démonstration (`docs/demo.md`)
- [ ] Rapport de validation complet, consultable dans le back-office
- [ ] **Apprentissage** : notebooks `08_trafic_derive_shadow`, `09_securite_mesuree`, `10_choisir_un_modele` ; guides `10-ci-cd.md` complété, `11-exploitation.md`

**Acceptation** : pipeline complet vers `staging` avec gates bloquants ; démonstration jouable de bout en bout depuis `docs/demo.md` ; chaque chiffre de la phase publié avec son intervalle et la date de son exécution `full` ; liste de contrôle `08-production-readiness.md` §9 cochée.

## Phase 9 — Packaging du portfolio

- [ ] **README** : ce que le projet fait et ne fait pas (mode démonstration, `draft`, trafic synthétique) → l'architecture (un schéma) → **le tableau maître des chiffres** (ablation RAG, kappa du juge, golden cases avec intervalles, coût et latence par question, coût mensuel extrapolé, requêtes avant détection de dérive, taux de blocage des attaques, comparaison de modèles, Lambda contre Gateway, RPO/RTO mesurés) → les décisions et arbitrages → **ce qui a cassé et ce que j'en ai tiré** (extrait de `JOURNAL.md`) → ce que je ferais différemment à l'échelle 100×
- [ ] Carte des compétences AWS remplie à la main (`09-learning-method.md` §4) ; les trous identifiés listés dans `STATE.md`
- [ ] Un post technique tiré du journal (au choix : le harness et le juge calibré ; ou le coût réel d'une question multi-agents et d'où il vient)
- [ ] Trois histoires d'incident au format situation-action-résultat chiffré, tirées de `JOURNAL.md`
- [ ] Démonstration de 30 secondes : parcours enregistré ou script `docs/demo.md` rejouable
- [ ] Optionnel : notebook `11_l_agent_est_la_mauvaise_reponse` (classifieur de conformité en trois bras : règles, TF-IDF + linéaire, LLM ; qualité et coût pour mille)

**Acceptation** : un lecteur qui ne connaît pas le projet comprend en cinq minutes ce qui a été mesuré, comment, et ce qui n'a pas été fait.

## Différé (spécifié, non construit)

- **Vertical fiscalité** : agent `tax`, `tax_shares`, `income_tax`, `per_deduction_ceiling`, paramètres IR/PER.
- **Documents** : upload S3, Lambda `documents`, agent `extractor`, `TaxNoticeExtraction`.
- **V2** : agent `real_estate`, fiscalité étendue (revenus du capital, IFI, enveloppes).
- **V3** : agents `allocation`, `retirement`, `budget` ; projections.
- **V4** : agrégation bancaire via un partenaire agréé (la passerelle et Identity, déjà en place, reçoivent des cibles externes), suivi dans le temps, alertes lors d'un changement de loi de finances.
- **Ouverture à de vrais clients** : hors projet. Elle supposerait des associés, un statut réglementaire, une AIPD finalisée et un test d'intrusion externe ; la liste reste dans `08-production-readiness.md` §9 pour mémoire.
