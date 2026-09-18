# Couche platform de l'environnement prod : modules tools api gateway review ingestion observability.

module "tools" {
  source = "../../../modules/tools"

  project = local.project
  env     = local.env
  tags    = local.tags
}

module "api" {
  source = "../../../modules/api"

  project = local.project
  env     = local.env
  tags    = local.tags
}

module "gateway" {
  source = "../../../modules/gateway"

  project = local.project
  env     = local.env
  tags    = local.tags
}

module "review" {
  source = "../../../modules/review"

  project = local.project
  env     = local.env
  tags    = local.tags
}

module "ingestion" {
  source = "../../../modules/ingestion"

  project = local.project
  env     = local.env
  tags    = local.tags
}

module "observability" {
  source = "../../../modules/observability"

  project = local.project
  env     = local.env
  tags    = local.tags
}
