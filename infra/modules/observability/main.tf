# Module `observability` : Dashboards CloudWatch versionnés en JSON, alarmes et alarmes composites, canal d'astreinte SNS, export horaire du journal d'audit vers S3 Object Lock.
# Les ressources arrivent en phase 3 (docs/07-roadmap.md) ; le module expose déjà son préfixe et ses tags.

locals {
  name_prefix = "${var.project}-${var.env}"
  tags        = var.tags
}
