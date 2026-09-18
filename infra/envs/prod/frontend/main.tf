# Couche frontend de l'environnement prod : modules frontend.

module "frontend" {
  source = "../../../modules/frontend"

  project = local.project
  env     = local.env
  tags    = local.tags
}
