# Couche frontend de l'environnement staging : modules frontend.

module "frontend" {
  source = "../../../modules/frontend"

  project = local.project
  env     = local.env
  tags    = local.tags
}
