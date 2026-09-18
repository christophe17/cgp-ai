locals {
  project = "cgp"
  env     = "prod"
  layer   = "frontend"

  tags = {
    project             = local.project
    env                 = local.env
    layer               = local.layer
    owner               = var.owner
    data_classification = "internal"
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.tags
  }
}
