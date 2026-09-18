# Module `review` : Step Functions de validation conseiller (task token, relances, expiration, SLA), Lambdas, identités SES.
# Les ressources arrivent en phase 6 (docs/07-roadmap.md) ; le module expose déjà son préfixe et ses tags.

locals {
  name_prefix = "${var.project}-${var.env}"
  tags        = var.tags
}
