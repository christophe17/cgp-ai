provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.management_account_id]

  default_tags {
    tags = {
      project             = var.project
      env                 = "management"
      layer               = "global"
      owner               = var.owner
      data_classification = "internal"
    }
  }
}
