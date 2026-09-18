# 08 — Exigences de qualité production

Ce document fixe ce que « production ready » veut dire pour ce projet. Il s'applique **dès la phase 0** : il n'y a pas de version jetable suivie d'une réécriture. Chaque phase de `07-roadmap.md` coche les points qui la concernent ; la Definition of Done y renvoie.

Les données traitées (patrimoine, famille, revenus, fiscalité) et le cadre réglementaire imposent un niveau d'exigence équivalent à celui d'un service financier, y compris pour l'environnement de démonstration.

## 1. Comptes et environnements

- Trois comptes AWS distincts (`dev`, `staging`, `prod`) dans une organisation AWS. Aucune ressource partagée entre environnements.
- SCP au niveau de l'organisation : régions UE uniquement, interdiction de créer des clés d'accès IAM utilisateur, interdiction de désactiver CloudTrail, KMS ou les sauvegardes.
- Accès humain via IAM Identity Center (SSO) avec MFA, rôles en lecture seule par défaut. Aucun accès en écriture à `prod` hors procédure break-glass journalisée et revue après coup.
- `staging` est iso-`prod` : mêmes modules, mêmes garde-fous, mêmes alarmes, tailles réduites (scale-to-zero de la base). C'est là que se jouent la démonstration, les golden cases, les tests de charge et de restauration.

## 2. Terraform

- Version de Terraform et des providers épinglées (`required_version`, `required_providers` avec contraintes `~>`) ; `.terraform.lock.hcl` commité ; montée de version par PR dédiée.
- Backend S3 par compte : chiffrement KMS, versionnement, verrouillage natif (`use_lockfile`, Terraform ≥ 1.10). Accès au bucket d'état limité au rôle CI et au rôle break-glass.
- Un état par environnement **et** par couche (`01-architecture.md` §3). Pas d'état monolithique.
- Modules internes uniquement ; aucun module communautaire. Chaque module a un `README`, des variables typées avec `validation`, des outputs documentés.
- Toute ressource porte les tags `project`, `env`, `layer`, `owner`, `data_classification`.
- `terraform plan` publié en commentaire de PR ; `apply` par la CI uniquement pour `staging` et `prod`, en appliquant l'artefact de plan relu.
- Analyse statique bloquante : `terraform fmt -check`, `terraform validate`, tflint, trivy (config). Aucun finding critique ou élevé sans justification inline reliée à un ticket.
- Détection de dérive nocturne (`terraform plan -detailed-exitcode`) sur `staging` et `prod` ; toute dérive déclenche une alarme.
- Interdits : ressource créée à la main, `-target` en CI, `-auto-approve` hors `dev`, secret dans une variable ou dans l'état.
- Ressource AgentCore non couverte par `aws` ni `awscc` : script idempotent exécuté par la CI, avec date de réévaluation dans le code ; jamais d'action manuelle en console.

## 3. Données, sauvegardes et reprise

- Aurora : PITR, sauvegardes automatiques avec rétention 35 jours, `deletion_protection` en `staging` et `prod`, chiffrement KMS, AWS Backup avec copie dans un second coffre.
- S3 : versionnement, chiffrement KMS, blocage total de l'accès public, Object Lock en mode conformité sur l'export d'audit, réplication de l'export d'audit vers un second bucket UE.
- Objectifs : **RPO 5 minutes** (PITR) et **RTO 4 heures** pour la base ; **RPO 1 heure** pour l'export d'audit ; **RTO 1 heure** pour le frontend et le runtime (redéploiement par la CI). Mesurés en phase 8.
- Test de restauration complet (base + documents + export d'audit) avant la démonstration, puis trimestriel, procédure dans un runbook.
- Rétention par type de donnée selon `05-safety-compliance.md` §6, appliquée par des tâches planifiées ; suppression RGPD testée de bout en bout.
- Migrations : Alembic, réversibles, exécutées par la CI avant le déploiement applicatif ; migration de schéma du profil testée sur les fixtures.

## 4. Fiabilité

- Chaque Lambda : timeout explicite, mémoire dimensionnée, retries avec backoff et jitter, DLQ surveillée, idempotence sur toute écriture.
- Appels Bedrock : quotas (TPM/RPM) vérifiés et augmentés avant la démonstration ; gestion du throttling (backoff, réponse d'attente) ; timeout et plafond de tokens par appel ; plafond de tokens par question.
- Kill switch par agent et global, sans redéploiement (paramètre SSM lu à chaque question) : bascule en mode « information générale seule » ou indisponibilité propre avec message.
- Dégradation contrôlée : si le RAG, les paramètres ou le moteur de calcul sont indisponibles, la réponse dit que l'analyse est impossible. Jamais de repli sur la mémoire du modèle.
- Test de charge sur `staging` avec le profil de trafic cible (10 questions simultanées, 500 par jour) avant la démonstration ; limites de concurrence (Lambda, AgentCore, Bedrock, Aurora) documentées.

## 5. Sécurité opérationnelle

- WAF (règles gérées AWS + limitation de débit) devant le frontend et l'API ; quota de questions par utilisateur et par jour ; alarme sur consommation anormale.
- Cognito : MFA obligatoire, fonctions de sécurité avancées, politique de mots de passe, révocation de sessions ; groupe `advisors` attribué par un administrateur.
- Secrets : Secrets Manager avec rotation ; aucun secret dans le code, les variables Terraform, l'état ou les journaux.
- Chaîne d'approvisionnement : `uv.lock` commité, audit des vulnérabilités en CI (bloquant sur critique), scan des images ECR à chaque push, SBOM par release, images de base épinglées par digest.
- Revue de sécurité avant la démonstration : analyse statique, tests d'injection de prompt mesurés (`06-evals-mlops.md` §12), tests d'accès croisé, test d'absence de PII dans les journaux. Test d'intrusion externe : hors projet (aucune ouverture aux clients).
- Revue trimestrielle des accès humains, des rôles et des politiques IAM.
- Journal d'audit inviolable pour : recommandations, validations, consultations de dossiers, confirmations de profil, suppressions RGPD, accès break-glass.

## 6. Observabilité et exploitation

- SLO avec budgets d'erreur : disponibilité de l'API et du frontend 99,5 % ; latence p95 d'une question complète 120 s ; délai de validation conseiller médian 2 jours ouvrés (mesuré, non garanti en démonstration).
- Chaque alarme a un niveau de gravité, un destinataire d'astreinte (SNS vers le canal d'astreinte) et un runbook.
- Runbooks dans `docs/runbooks/` : incident Bedrock ou throttling, file de validation bloquée, restauration de données, suppression RGPD, rotation de secrets, rollback d'une release, dérive Terraform, activation du kill switch, réindexation du corpus juridique.
- Journaux structurés (JSON), corrélés par `trace_id`, sans PII ; rétention 90 jours ; accès aux traces complètes restreint et journalisé.
- Post-mortem sans blâme pour tout incident de gravité haute, actions suivies jusqu'à clôture.

## 7. Livraison

- Versionnage sémantique des packages, du moteur de calcul (`engine_version`), des prompts et des millésimes ; changelog généré.
- Chaque déploiement enregistre les versions de tous les artefacts (code, image, prompts, paramètres, règles, modules Terraform) ; ces versions figurent dans chaque trace.
- Retour arrière testé à chaque release en `staging` ; procédure documentée et exécutable par la CI.
- Feature flags (paramètres SSM) pour activer un agent ou un outil par environnement sans redéploiement.
- Environnements protégés GitHub : `staging` et `prod` exigent une approbation ; branches protégées, revue obligatoire, CI verte.

## 8. Coûts

- AWS Budgets par compte avec alarmes à 50 %, 80 % et 100 % ; alerte de dépense anormale.
- Coût par question mesuré dès la phase 5 (tokens par agent, appels d'outils, AgentCore) et suivi dans un tableau de bord ; extrapolation mensuelle par profil de trafic en phase 8 (`06-evals-mlops.md` §10).
- Quotas par utilisateur et plafonds de tokens par question comme protection contre l'abus.
- Scale-to-zero de la base en `dev` et `staging`.

## 9. Liste de contrôle avant ouverture en production

- [ ] Comptes, SCP, SSO, break-glass en place
- [ ] Terraform : états séparés, verrouillage, dérive surveillée, aucun finding critique ou élevé
- [ ] Sauvegardes activées, restauration testée, RPO/RTO mesurés
- [ ] Quotas Bedrock obtenus, test de charge passé, kill switch testé
- [ ] WAF, MFA, rotation des secrets, scans de dépendances et d'images verts
- [ ] Revue sécurité interne réalisée, attaques mesurées à 100 % de blocage sur les `must_block` (test d'intrusion externe : hors projet)
- [ ] SLO, alarmes, astreinte, runbooks
- [ ] Rollback testé, versions des artefacts tracées
- [ ] AIPD, registre des traitements, durées de rétention en première version (phase 8)
- [ ] Paramètres, cas de référence, règles et prompts : tous `draft`, listés dans le rapport de validation (aucune validation professionnelle prévue)
