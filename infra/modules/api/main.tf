# Module `api` : API Gateway HTTP de l'API profil, autorisateur JWT Cognito, quotas et throttling, journaux d'accès, intégrations Lambda.
# Les ressources arrivent en phase 5 (docs/07-roadmap.md) ; le module expose déjà son préfixe et ses tags.

locals {
  name_prefix = "${var.project}-${var.env}"
  tags        = var.tags
}
