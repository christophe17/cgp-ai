# Couche foundation de l'environnement prod : modules network security data.

module "network" {
  source = "../../../modules/network"

  project = local.project
  env     = local.env
  tags    = local.tags
}

module "security" {
  source = "../../../modules/security"

  project = local.project
  env     = local.env
  tags    = local.tags
}

module "data" {
  source = "../../../modules/data"

  project = local.project
  env     = local.env
  tags    = local.tags
}
