# Module `agents` : Dépôt ECR (scan à la poussée, digest immuable), Bedrock AgentCore Runtime (image ARM64 construite par la CI, autorisation JWT Cognito entrante), Bedrock Guardrails, rôle d'exécution à moindre privilège, paramètres SSM (kill switch, feature flags).
# Les ressources arrivent en phase 5 (docs/07-roadmap.md) ; le module expose déjà son préfixe et ses tags.

locals {
  name_prefix = "${var.project}-${var.env}"
  tags        = var.tags
}
