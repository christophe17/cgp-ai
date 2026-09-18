provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.account_id]

  assume_role {
    role_arn     = "arn:aws:iam::${var.account_id}:role/OrganizationAccountAccessRole"
    session_name = "cgp-bootstrap-prod"
  }

  default_tags {
    tags = {
      project             = var.project
      env                 = "prod"
      layer               = "global"
      owner               = var.owner
      data_classification = "internal"
    }
  }
}
