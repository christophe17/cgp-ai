# 09 — Méthode d'apprentissage : notebooks, guides d'infrastructure, carte des compétences AWS

Ce projet est un **portfolio en production** et, en même temps, **le support d'apprentissage** de son auteur. Les deux ne se contredisent pas : le code livré est du code de production ; le matériel d'apprentissage l'explique, l'exécute et le mesure, sans jamais le réécrire. Ce document est le contrat de ce matériel. Il complète `07-roadmap.md` (qui dit *quand* chaque livrable d'apprentissage arrive) et `06-evals-mlops.md` (qui dit *ce qu'on mesure*).

## 1. Principe

- **J'apprends en lisant du code expliqué, pas en écrivant du code.** Claude Code écrit 100 % du code, de l'infrastructure et du matériel d'apprentissage. Mon travail est de lire, comprendre, questionner, arbitrer, et lancer des expériences en changeant des paramètres.
- Deux objectifs distincts, deux supports distincts :
  - **la technique LLM en production** (agents, outils, RAG, évaluation, observabilité, sécurité) → des **notebooks** qui exécutent le vrai code du dépôt ;
  - **l'infrastructure AWS** → des **guides de lecture** du Terraform réel, un par domaine, conçus pour vérifier qu'il n'y a pas de trou dans ce que je crois déjà savoir. Je maîtrise Kubernetes, Terraform, CI/CD et l'observabilité classique : les guides ne réexpliquent pas ces bases, ils s'arrêtent sur ce qui est **spécifique au service AWS** ou **nouveau pour moi** (AgentCore, Bedrock, Aurora Serverless v2, Amplify, Cognito, Step Functions, Object Lock…).
- Chaque phase de `07-roadmap.md` livre **du code, et le matériel d'apprentissage correspondant**. Une phase sans son notebook ou son guide n'est pas terminée.

## 2. Contrat des notebooks (`notebooks/`)

1. **Le notebook n'implémente rien.** Il importe depuis `packages/` et `services/` et exécute le code réel du projet. Une version simplifiée réécrite dans le notebook est un échec : je dois apprendre le code qui tourne, pas un jouet parallèle.
2. Pour montrer le code : `inspect.getsource()` sur les fonctions et classes réelles, ou affichage d'extraits de fichiers avec leur chemin, puis explication bloc par bloc.
3. Structure imposée :
   - **Le problème** : ce qu'on résout, pourquoi la solution naïve ne suffit pas.
   - **Les options** : deux ou trois approches, pourquoi celle-là.
   - **Lecture guidée du code réel**, commentée quand c'est subtil.
   - **Exécution avec les sorties intermédiaires visibles** : le `CalcResult` pas à pas, le passage renvoyé par `legal.search`, le prompt final envoyé à Bedrock, la sortie structurée brute et sa validation, la trace, le rapport de vérification. Je veux voir ce qui se passe, pas seulement le résultat.
   - **Les pièges** : ce qui casse en vrai, ce que les tutoriels ne disent pas.
   - **Expérimentations guidées** : deux ou trois cellules de configuration en tête que je modifie pour relancer et observer, sans écrire de code.
   - **Les chiffres** : impact mesuré sur la qualité, la latence, le coût, avec l'intervalle de confiance quand il y a un aléa.
   - **Questions d'entretien** : quatre à six, réponses attendues en cellule repliée.
   - **Ce qu'on n'a pas fait, et pourquoi.**
4. **Le notebook s'exécute de bout en bout.** `nbmake` dans la CI : un notebook cassé casse le build. Deux modes pilotés par une variable d'environnement :
   - `CGP_NB_MODE=sample` (CI) : `LocalToolInvoker`, PostgreSQL du `docker compose`, **réponses Bedrock enregistrées** (cassettes versionnées dans `notebooks/cassettes/`, sans PII, profils fictifs) ; aucun appel réseau, quelques secondes ;
   - `CGP_NB_MODE=full` (à la main, compte `dev`) : vrais appels Bedrock, vraies Lambdas via `LambdaToolInvoker`, chiffres complets archivés dans `notebooks/results/<date>/`. Les chiffres publiés dans le README viennent toujours d'une exécution `full` datée.
5. Prose en **français**, identifiants et code en anglais. Environ 40 cellules au maximum, sinon découper.
6. Aucun profil réel, aucune donnée personnelle, aucune clé dans un notebook. Les sorties commitées sont celles du mode `sample`.

### Liste des notebooks

| # | Notebook | Phase | Ce que j'apprends |
|---|---|---|---|
| 00 | `00_visite_guidee.ipynb` | 0 | L'architecture cible, le trajet d'une question, où vit chaque règle non négociable dans le code |
| 01 | `01_calcul_deterministe.ipynb` | 2 | Pourquoi le LLM ne calcule jamais : `CalcResult` pas à pas, `inputs_origin`, `replay`, hash des paramètres, tests de propriété, test AST |
| 02 | `02_anatomie_d_un_outil.ipynb` | 3 | `ToolContext` construit par le code, même handler en local et en Lambda, isolation par `user_id`, idempotence, DLQ ; un test d'accès croisé joué en direct |
| 03 | `03_du_texte_de_loi_au_passage.ipynb` | 4 | Découpage par article, métadonnées temporelles, embeddings Bedrock, recherche hybride ; **l'ablation BM25 / dense / hybride / reranker chiffrée** avec intervalles |
| 04 | `04_anatomie_du_pipeline.ipynb` | 5 | Les 16 étapes, sortie structurée par appel d'outil forcé, budgets, itérations, Guardrails ; le prompt final et la sortie brute de chaque agent |
| 05 | `05_le_harness_d_evaluation.ipynb` | 5 | Golden cases, N exécutions, bootstrap, métriques déterministes vs juge, **calibration du juge (kappa)**, gate de régression, rapport HTML |
| 06 | `06_anatomie_d_une_trace.ipynb` | 5 | D'où viennent les millisecondes et les euros : spans OTel, attributs de version, coût par agent, TTFT, décomposition p50/p95 |
| 07 | `07_validation_et_audit.ipynb` | 6 | Le task token Step Functions, l'expiration sur changement de profil, `audit_events` en ajout seul et l'export Object Lock lus depuis Python |
| 08 | `08_trafic_derive_shadow.ipynb` | 8 | Le générateur de trafic, le coût extrapolé, la dérive injectée et le nombre de requêtes avant détection, **l'évaluation shadow d'un changement de modèle ou de prompt** |
| 09 | `09_securite_mesuree.ipynb` | 8 | Les attaques d'injection fabriquées (message, passage RAG, document), le taux de blocage avant et après chaque contrôle |
| 10 | `10_choisir_un_modele.ipynb` | 8 | Comparaison de deux ou trois modèles Bedrock sur le golden set : qualité × coût × latence, et le cas où le modèle rapide suffit |
| 11 | `11_l_agent_est_la_mauvaise_reponse.ipynb` | 9 (optionnel) | Le classifieur de conformité en trois bras : règles, TF-IDF + linéaire, LLM ; qualité et coût pour mille |
| 12 | `12_gateway_ou_lambda.ipynb` | 5 | Le même outil appelé en direct et via AgentCore Gateway en MCP : ce que la passerelle ajoute (découverte, authentification entrante et sortante, identité), ce qu'elle coûte en latence et en euros ; le test d'accès croisé joué sur les deux ; le tableau qui tranche |

## 3. Contrat des guides d'infrastructure (`docs/infra/`)

Un guide par domaine Terraform, écrit au moment où le module est livré, relu avec le `plan` sous les yeux. Structure imposée :

1. **Ce que c'est, en deux phrases**, et **pourquoi ici** (quelle règle non négociable ou quelle exigence de `08-production-readiness.md` il sert).
2. **Ce que je sais déjà, ce qui est nouveau** : une ligne par ressource du module, classée *connu* (rien à lire, un rappel d'une phrase), *à vérifier* (une idée reçue possible, le guide la tranche), *nouveau* (le guide explique). C'est l'outil de détection des trous : je relis cette liste et je corrige la classification à la main.
3. **Lecture guidée du HCL réel**, fichier par fichier, avec les choix qui ne sont pas évidents (pourquoi cet endpoint, pourquoi `awscc` ici, pourquoi une clé KMS par domaine de données).
4. **Vérifier après `apply`** : les commandes `aws` CLI exactes qui prouvent que la ressource fait ce qu'on croit (l'authentification IAM sur RDS Proxy fonctionne, la SCP refuse une région hors UE, l'Object Lock refuse une suppression, le JWT est validé par le runtime).
5. **Coût** : estimation mensuelle du module en `dev`, en `staging` allumé, et ce qui coûte quand tout est éteint.
6. **Pièges** : ce qui a cassé pendant la construction (tiré de `JOURNAL.md`), et ce que la documentation AWS ne dit pas.
7. **Questions d'entretien** : trois à cinq.

### Liste des guides

| # | Guide | Module(s) | Ressources exercées |
|---|---|---|---|
| 00 | `00-bootstrap.md` | `infra/global/` | Organisation AWS, trois comptes, SCP (régions UE, pas de clés IAM utilisateur, CloudTrail/KMS/sauvegardes non désactivables), IAM Identity Center + MFA, bucket d'état S3 chiffré et verrouillé, rôle OIDC GitHub par compte, AWS Budgets, break-glass |
| 01 | `01-network.md` | `network` | VPC sans IP publique, sous-réseaux privés, endpoints d'interface (Bedrock Runtime, Secrets Manager, CloudWatch Logs, Lambda, STS) et de passerelle (S3), groupes de sécurité, coût des endpoints contre NAT |
| 02 | `02-security.md` | `security` | KMS clés gérées client (une par domaine de données, politiques de clé), rôles IAM de base, Cognito (user pool, MFA TOTP, fonctions de sécurité avancées, groupe `advisors`, client applicatif, invitation), WAF (règles gérées, rate limiting) |
| 03 | `03-data.md` | `data` | Aurora PostgreSQL Serverless v2 (scale-to-zero, PITR, `deletion_protection`), pgvector, RDS Proxy avec authentification IAM, S3 (versionnement, KMS, blocage public, Object Lock mode conformité, réplication), AWS Backup avec second coffre |
| 04 | `04-tools.md` | `tools` | Lambda en VPC (Python, conteneur ou zip, ARM64), un rôle par fonction, DLQ SQS, timeouts et retries, concurrence réservée, idempotence |
| 05 | `05-api.md` | `api` | API Gateway HTTP, autorisateur JWT Cognito, quotas et throttling, journaux d'accès, intégration Lambda |
| 06 | `06-agents.md` | `agents`, `gateway` | ECR (scan, digest immuable), Bedrock AgentCore Runtime (image ARM64, autorisation JWT entrante, sessions, streaming), AgentCore Gateway (cibles Lambda en MCP, autorisation JWT entrante, découverte des outils, tarification), AgentCore Identity (fournisseur de credentials, authentification sortante), Bedrock Guardrails, profils d'inférence UE, quotas Bedrock, provider `awscc` et ce qu'il ne couvre pas, rôle d'exécution à moindre privilège |
| 07 | `07-workflows.md` | `review`, `ingestion` | Step Functions (task token, attente, expiration, relances), SES (identités, sandbox, envoi transactionnel), EventBridge Scheduler, Lambdas d'orchestration |
| 08 | `08-observability.md` | `observability` | OpenTelemetry Strands → AgentCore Observability, CloudWatch (logs structurés, métriques, alarmes composites, dashboards en JSON versionnés), X-Ray, SNS astreinte, budgets, export horaire d'audit vers Object Lock |
| 09 | `09-frontend.md` | `frontend` | Amplify Hosting (Next.js SSR, branche par environnement, domaine custom, CloudFront), Amplify Auth sur Cognito, association WAF, variables d'environnement par branche |
| 10 | `10-ci-cd.md` | `.github/workflows/` | OIDC GitHub → AWS sans clé, environnements GitHub protégés, `plan` en commentaire de PR, `apply` de l'artefact de plan, promotion `dev` → `staging` → `prod`, drift nocturne, rollback exécuté en `staging`, SBOM et scans |
| 11 | `11-exploitation.md` | transverse | Runbooks (`docs/runbooks/`), restauration PITR jouée et chronométrée (RPO/RTO), kill switch SSM, rotation de secrets, procédure break-glass, feature flags SSM, tableau de coûts par module |

## 4. Carte des compétences AWS — la vérification des trous

Grille à relire à la fin de chaque guide. La colonne « Ce que le projet exerce » est remplie par Claude Code ; la colonne « Moi » est remplie **à la main** par moi (`connu` / `à vérifier` / `nouveau`), jamais par Claude Code. Un service dont la case reste vide à la fin du projet est un trou identifié.

| Service | Ce que le projet exerce | Guide | Moi |
|---|---|---|---|
| Organizations, SCP | Trois comptes, SCP régions UE et interdictions | 00 | … |
| IAM Identity Center | SSO, MFA, rôles lecture seule par défaut, break-glass | 00 | … |
| IAM | Rôles par Lambda/Step Functions/runtime, OIDC GitHub, moindre privilège sans wildcard sur les données | 00, 02, 04, 10 | … |
| S3 | État Terraform, documents, corpus brut, export d'audit Object Lock, réplication, URL présignées | 00, 03 | … |
| KMS | Clés gérées client par domaine, politiques de clé, chiffrement base/S3/journaux/secrets | 02 | … |
| VPC, endpoints | Réseau privé sans NAT, endpoints d'interface et de passerelle | 01 | … |
| Cognito | User pool, MFA, groupes, autorisateur JWT, invitation, révocation | 02, 05, 09 | … |
| WAF | Règles gérées, rate limiting, association Amplify et API Gateway | 02, 09 | … |
| Aurora Serverless v2 | PostgreSQL, pgvector, scale-to-zero, PITR, sauvegardes, restauration | 03 | … |
| RDS Proxy | Authentification IAM, pooling pour Lambda | 03 | … |
| AWS Backup | Plans, second coffre, test de restauration | 03 | … |
| Lambda | VPC, conteneur ARM64, DLQ, retries, idempotence, concurrence | 04 | … |
| SQS | DLQ | 04 | … |
| API Gateway HTTP | Autorisateur JWT, quotas, journaux d'accès | 05 | … |
| ECR | Scan à la poussée, digest immuable, politique de rétention | 06 | … |
| Bedrock | API Converse, sortie structurée, profils d'inférence UE, embeddings, quotas, throttling, tarification | 06 | … |
| Bedrock AgentCore Runtime | Déploiement d'un conteneur d'agent, autorisation JWT, sessions, streaming | 06 | … |
| Bedrock AgentCore Gateway | Lambdas exposées en MCP, autorisation JWT entrante, découverte d'outils, propagation des claims, second backend mesuré | 06 | … |
| Bedrock AgentCore Identity | Fournisseur de credentials pour l'authentification sortante de la passerelle | 06 | … |
| Policy in AgentCore | Moteur de politiques Cedar associé à la passerelle, contrôle de chaque appel d'outil | 06 | … |
| Bedrock AgentCore Observability | Traces OTel des agents, coût par session | 08 | … |
| Bedrock AgentCore Evaluations | Évaluation en ligne échantillonnée | 08 | … |
| Bedrock Guardrails | Filtres PII, sujets interdits, journalisation | 06 | … |
| Step Functions | Task token, attente humaine, expiration, orchestration d'ingestion | 07 | … |
| SES | Notifications transactionnelles, sortie de sandbox | 07 | … |
| EventBridge Scheduler | Planification hebdomadaire | 07 | … |
| CloudWatch | Logs structurés, métriques, alarmes composites, dashboards JSON, rétention | 08 | … |
| X-Ray / OpenTelemetry | Propagation de contexte, spans par agent et outil | 08 | … |
| SNS | Canal d'astreinte | 08 | … |
| AWS Budgets | Alarmes 50/80/100 %, dépense anormale | 00, 08 | … |
| CloudTrail | Journal d'API, protégé par SCP | 00 | … |
| Secrets Manager, SSM Parameter Store | Secrets avec rotation ; kill switch et feature flags | 02, 11 | … |
| Amplify Hosting, Amplify Auth | Next.js SSR, branches, domaine, CloudFront, auth Cognito | 09 | … |
| Terraform `aws` et `awscc` | Couverture AgentCore, `import`, états par couche, `use_lockfile`, drift | 00, 06, 10 | … |
| GitHub Actions + OIDC | Rôle par compte, environnements protégés, promotion, artefact de plan | 10 | … |

Services **volontairement absents du projet** — ni dans le code, ni dans l'infrastructure, ni dans l'apprentissage ; à connaître de nom seulement, avec la raison de l'absence :

- **AgentCore Memory** : un second stockage de données personnelles hors de la base que la suppression RGPD maîtrise ; l'historique reste en PostgreSQL (`01-architecture.md` §6).
- **EKS** : mon quotidien ; l'architecture est Lambda + AgentCore, rien à y gagner.
- **SageMaker, Kinesis, MSK** : aucun besoin à ce volume ; les ajouter serait de l'empilement.
- **OpenSearch** : pgvector suffit à ce volume ; l'ablation du notebook 03 le chiffre.

À l'inverse, **AgentCore Gateway et Identity sont dans le projet** (décision du 2026-09-18) comme second backend d'outils mesuré contre l'invocation directe des Lambdas (`04-tools-and-data.md` §5, notebook 12, guide 06). **Policy in AgentCore** l'est aussi (vérification du 2026-09-18, `infra/README.md`) : moteur Cedar associé à la passerelle, il contrôle chaque appel d'outil et rejoint le module `gateway`.

## 5. Règles de conversation et de phase

- **Explique avant de coder.** Pour toute décision non triviale : deux options et l'arbitrage, en dix lignes, avant d'écrire.
- **Contredis-moi.** Si je demande une mauvaise idée, dis-le.
- Pas de flatterie, pas de récapitulatif de politesse.
- Si un choix m'engage (coût récurrent, service AWS non couvert par Terraform, modèle), **pose la question et attends**.
- **Debrief de phase** en dix lignes : ce qui est fait, ce que je dois lire en priorité, où je me ferai piéger en entretien, ce qui reste faible dans notre implémentation.
- **`JOURNAL.md`** à la racine : une entrée datée par session de travail — contexte, fait, **incidents et surprises**, suite. Les incidents y sont notés au fil de l'eau ; ils nourrissent la section « ce qui a cassé » du README et les histoires d'entretien. On ne les reconstitue pas après coup.
- **`STATE.md`** à la racine : phase en cours, chiffres actuels, décisions en attente. Relu avec `CLAUDE.md` et `JOURNAL.md` à chaque nouvelle session.
