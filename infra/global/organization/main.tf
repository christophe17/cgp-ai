# Organisation AWS, unités d'organisation et comptes membres.
#
# Structure : racine > workloads > { dev, protected }. Les SCP « régions UE » et « garde-fous de base »
# s'appliquent à workloads ; la SCP « services de sécurité protégés » s'applique à protected (staging,
# prod) seulement, pour que dev reste destructible pendant la construction.

resource "aws_organizations_organization" "this" {
  feature_set          = "ALL"
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "sso.amazonaws.com",
    "backup.amazonaws.com",
  ]

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "workloads"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "dev" {
  name      = "dev"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_organizational_unit" "protected" {
  name      = "protected"
  parent_id = aws_organizations_organizational_unit.workloads.id
}

locals {
  account_parent = {
    dev     = aws_organizations_organizational_unit.dev.id
    staging = aws_organizations_organizational_unit.protected.id
    prod    = aws_organizations_organizational_unit.protected.id
  }
}

resource "aws_organizations_account" "member" {
  for_each = var.member_accounts

  name                       = "${var.project}-${each.key}"
  email                      = each.value.email
  parent_id                  = local.account_parent[each.key]
  role_name                  = "OrganizationAccountAccessRole"
  iam_user_access_to_billing = "ALLOW"
  close_on_deletion          = false

  tags = {
    env = each.key
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [role_name]
  }
}

module "tfstate" {
  source = "../modules/tfstate"

  bucket_name = "${var.project}-tfstate-mgmt-${var.management_account_id}"
  kms_alias   = "alias/${var.project}-mgmt-tfstate"
}

module "identity_center" {
  count  = var.identity_center_enabled ? 1 : 0
  source = "../modules/identity-center"

  project               = var.project
  management_account_id = var.management_account_id
  member_account_ids    = { for env, account in aws_organizations_account.member : env => account.id }
  operator              = var.operator
  operator_break_glass  = var.operator_break_glass
}
