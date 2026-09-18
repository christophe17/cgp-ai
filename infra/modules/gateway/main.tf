# Module `gateway` : AgentCore Gateway (Lambdas d'outils exposées en MCP, autorisation JWT Cognito entrante), AgentCore Identity (authentification sortante vers les Lambdas), Policy in AgentCore (moteur de politiques Cedar associé à la passerelle), rôle de la passerelle.
# Les ressources arrivent en phase 5 (docs/07-roadmap.md) ; le module expose déjà son préfixe et ses tags.

locals {
  name_prefix = "${var.project}-${var.env}"
  tags        = var.tags
}
