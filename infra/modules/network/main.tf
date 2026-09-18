# Module `network` : VPC privé sans IP publique, sous-réseaux privés, endpoints d'interface (Bedrock Runtime, Secrets Manager, CloudWatch Logs, Lambda, STS) et de passerelle (S3), groupes de sécurité.
# Les ressources arrivent en phase 3 (docs/07-roadmap.md) ; le module expose déjà son préfixe et ses tags.

locals {
  name_prefix = "${var.project}-${var.env}"
  tags        = var.tags
}
