# Module `tfstate`

Bucket d'état Terraform d'un compte : clé KMS gérée client avec rotation, versionnement, chiffrement
forcé, accès public bloqué, transport TLS obligatoire, verrouillage natif (`use_lockfile`, aucune
table DynamoDB). Utilisé par `infra/global/organization` (compte de gestion) et par
`infra/global/modules/account-bootstrap` (chaque compte membre).

Exigences servies : `docs/08-production-readiness.md` §2 (backend S3 par compte, chiffrement KMS,
versionnement, verrouillage natif).
