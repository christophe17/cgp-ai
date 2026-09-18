# Couche agents de l'environnement prod : modules agents.

module "agents" {
  source = "../../../modules/agents"

  project = local.project
  env     = local.env
  tags    = local.tags
}
