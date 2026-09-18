# Carte des compétences AWS — copie de travail

Copie de `docs/09-learning-method.md` §4, à remplir **à la main** dans la colonne « Moi » à la fin de
chaque guide (`connu` / `à vérifier` / `nouveau`). Claude Code ne remplit jamais cette colonne. Une
case vide à la fin du projet est un trou identifié.

| Service | Ce que le projet exerce | Guide | Livré | Moi |
|---|---|---|---|---|
| Organizations, SCP | Trois comptes, OU `workloads/{dev,protected}`, SCP régions UE, garde-fous de base, services de sécurité protégés | 00 | phase 0 | |
| IAM Identity Center | Instance, opérateur, groupes admins/readers/break-glass, permission sets, MFA | 00 | phase 0 | |
| IAM | Rôles OIDC plan et apply, deny explicite de lecture des objets, rôles par Lambda/Step Functions/runtime | 00, 02, 04, 10 | phase 0 (OIDC) | |
| S3 | Bucket d'état (versionnement, KMS, `use_lockfile`), CloudTrail, documents, corpus, export d'audit Object Lock | 00, 03 | phase 0 (état, CloudTrail) | |
| KMS | Clés gérées client par usage, politiques de clé (CloudTrail), rotation | 02 | phase 0 (état, CloudTrail) | |
| VPC, endpoints | Réseau privé sans NAT, endpoints d'interface et de passerelle | 01 | phase 3 | |
| Cognito | User pool, MFA, groupes, autorisateur JWT, invitation | 02, 05, 09 | phase 3 | |
| WAF | Règles gérées, rate limiting, Amplify (us-east-1) et API Gateway | 02, 09 | phase 3 | |
| Aurora Serverless v2 | PostgreSQL, pgvector, scale-to-zero, PITR, restauration | 03 | phase 3 | |
| RDS Proxy | Authentification IAM, pooling pour Lambda | 03 | phase 3 | |
| AWS Backup | Plans, second coffre, test de restauration | 03 | phase 3 | |
| Lambda | VPC, conteneur ARM64, DLQ, retries, idempotence, concurrence | 04 | phase 3 | |
| SQS | DLQ | 04 | phase 3 | |
| API Gateway HTTP | Autorisateur JWT, quotas, journaux d'accès | 05 | phase 5 | |
| ECR | Scan à la poussée, digest immuable, rétention | 06 | phase 5 | |
| Bedrock | Converse, sortie structurée, profils UE, embeddings, quotas, tarification | 06 | phase 5 | |
| Bedrock AgentCore Runtime | Conteneur d'agent, autorisation JWT, sessions, streaming | 06 | phase 5 | |
| Bedrock AgentCore Gateway | Lambdas en MCP, autorisation JWT entrante, découverte, propagation des claims, second backend mesuré | 06 | phase 5 | |
| Bedrock AgentCore Identity | Credentials pour l'authentification sortante de la passerelle | 06 | phase 5 | |
| Policy in AgentCore | Moteur Cedar associé à la passerelle, contrôle de chaque appel d'outil | 06 | phase 5 | |
| Bedrock AgentCore Observability | Traces OTel des agents, coût par session | 08 | phase 5 | |
| Bedrock AgentCore Evaluations | Évaluation en ligne échantillonnée | 08 | phase 8 | |
| Bedrock Guardrails | Filtres PII, sujets interdits, journalisation | 06 | phase 5 | |
| Step Functions | Task token, attente humaine, expiration, ingestion | 07 | phases 4 et 6 | |
| SES | Notifications, sortie de sandbox | 07 | phase 6 | |
| EventBridge Scheduler | Planification hebdomadaire | 07 | phase 4 | |
| CloudWatch | Logs structurés, métriques, alarmes composites, dashboards JSON | 08 | phases 3 et 8 | |
| X-Ray / OpenTelemetry | Propagation de contexte, spans par agent et outil | 08 | phase 5 | |
| SNS | Canal d'astreinte | 08 | phase 3 | |
| AWS Budgets, Cost Explorer | Budgets 50/80/100 %, prévision, détection d'anomalies | 00, 08 | phase 0 | |
| CloudTrail | Journal d'organisation, KMS, validation d'intégrité, protégé par SCP | 00 | phase 0 | |
| Secrets Manager, SSM Parameter Store | Secrets avec rotation ; kill switch et feature flags | 02, 11 | phases 3 et 5 | |
| Amplify Hosting, Amplify Auth | Next.js SSR, branches, domaine, CloudFront, auth Cognito | 09 | phase 7 | |
| Terraform `aws` et `awscc` | Couverture AgentCore, `import`, états par couche, `use_lockfile`, dérive | 00, 06, 10 | phase 0 | |
| GitHub Actions + OIDC | Rôle par compte, environnements protégés, promotion, artefact de plan chiffré, dérive nocturne | 10 | phase 0 | |
