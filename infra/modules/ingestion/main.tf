# Module `ingestion` : Step Functions d'ingestion du corpus juridique, Lambdas, planification EventBridge Scheduler hebdomadaire.
# Les ressources arrivent en phase 4 (docs/07-roadmap.md) ; le module expose déjà son préfixe et ses tags.

locals {
  name_prefix = "${var.project}-${var.env}"
  tags        = var.tags
}
