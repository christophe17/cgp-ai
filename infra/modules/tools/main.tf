# Module `tools` : Lambdas d'outils (profile, calc, legal, usage ; documents différé) en VPC, ARM64, un rôle par fonction, DLQ SQS, timeouts, retries, concurrence réservée.
# Les ressources arrivent en phase 3 (docs/07-roadmap.md) ; le module expose déjà son préfixe et ses tags.

locals {
  name_prefix = "${var.project}-${var.env}"
  tags        = var.tags
}
