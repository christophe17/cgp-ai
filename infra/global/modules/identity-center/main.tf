# IAM Identity Center : un opérateur, trois groupes, trois permission sets.
#   admins      → administrateur sur le compte de gestion et dev
#   readers     → lecture seule (métadonnées et journaux, pas le contenu des données) sur staging et prod
#   break-glass → administrateur d'une heure sur staging et prod, adhésion pilotée par variable
# L'instance elle-même est activée dans la console (exception de bootstrap, guide 00).

data "aws_ssoadmin_instances" "this" {}

locals {
  instance_arn      = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  admin_targets      = { management = var.management_account_id, dev = var.member_account_ids["dev"] }
  protected_targets  = { staging = var.member_account_ids["staging"], prod = var.member_account_ids["prod"] }
  readonly_policies  = ["arn:aws:iam::aws:policy/job-function/ViewOnlyAccess", "arn:aws:iam::aws:policy/CloudWatchLogsReadOnlyAccess"]
  break_glass_member = var.operator_break_glass ? { operator = aws_identitystore_user.operator.user_id } : {}
}

# --- Utilisateur et groupes -----------------------------------------------------------------------

resource "aws_identitystore_user" "operator" {
  identity_store_id = local.identity_store_id
  user_name         = var.operator.user_name
  display_name      = "${var.operator.given_name} ${var.operator.family_name}"

  name {
    given_name  = var.operator.given_name
    family_name = var.operator.family_name
  }

  emails {
    value   = var.operator.email
    primary = true
  }
}

resource "aws_identitystore_group" "admins" {
  identity_store_id = local.identity_store_id
  display_name      = "${var.project}-admins"
  description       = "Administrateurs du compte de gestion et de dev."
}

resource "aws_identitystore_group" "readers" {
  identity_store_id = local.identity_store_id
  display_name      = "${var.project}-readers"
  description       = "Lecture seule sur staging et prod."
}

resource "aws_identitystore_group" "break_glass" {
  identity_store_id = local.identity_store_id
  display_name      = "${var.project}-break-glass"
  description       = "Administrateur d'une heure sur staging et prod ; adhésion temporaire et journalisée."
}

resource "aws_identitystore_group_membership" "operator_admins" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.admins.group_id
  member_id         = aws_identitystore_user.operator.user_id
}

resource "aws_identitystore_group_membership" "operator_readers" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.readers.group_id
  member_id         = aws_identitystore_user.operator.user_id
}

resource "aws_identitystore_group_membership" "break_glass" {
  for_each = local.break_glass_member

  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.break_glass.group_id
  member_id         = each.value
}

# --- Permission sets ------------------------------------------------------------------------------

resource "aws_ssoadmin_permission_set" "admin" {
  name             = "${var.project}-admin"
  description      = "Administrateur (compte de gestion, dev)."
  instance_arn     = local.instance_arn
  session_duration = var.admin_session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_ssoadmin_permission_set" "readonly" {
  name             = "${var.project}-readonly"
  description      = "Lecture seule : métadonnées et journaux, sans lecture du contenu des données."
  instance_arn     = local.instance_arn
  session_duration = var.readonly_session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "readonly" {
  for_each = toset(local.readonly_policies)

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  managed_policy_arn = each.value
}

resource "aws_ssoadmin_permission_set" "break_glass" {
  name             = "${var.project}-break-glass"
  description      = "Administrateur d'une heure sur staging et prod, procédure journalisée."
  instance_arn     = local.instance_arn
  session_duration = var.break_glass_session_duration
}

resource "aws_ssoadmin_managed_policy_attachment" "break_glass" {
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.break_glass.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# --- Affectations ---------------------------------------------------------------------------------

resource "aws_ssoadmin_account_assignment" "admins" {
  for_each = local.admin_targets

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  principal_id       = aws_identitystore_group.admins.group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "readers" {
  for_each = local.protected_targets

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.readonly.arn
  principal_id       = aws_identitystore_group.readers.group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}

resource "aws_ssoadmin_account_assignment" "break_glass" {
  for_each = local.protected_targets

  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.break_glass.arn
  principal_id       = aws_identitystore_group.break_glass.group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}
