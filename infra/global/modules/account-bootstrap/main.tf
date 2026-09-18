# Bootstrap d'un compte membre, exécuté une fois depuis le compte de gestion :
# bucket d'état, fournisseur OIDC GitHub, rôles de plan et d'apply pour la CI, budget.

locals {
  name_prefix    = "${var.project}-${var.env}"
  github_oidc    = "token.actions.githubusercontent.com"
  plan_subjects  = ["repo:${var.github_repository}:pull_request", "repo:${var.github_repository}:ref:refs/heads/main"]
  apply_subjects = ["repo:${var.github_repository}:environment:${var.env}"]
}

module "tfstate" {
  source = "../tfstate"

  bucket_name = "${var.project}-tfstate-${var.env}-${var.account_id}"
  kms_alias   = "alias/${local.name_prefix}-tfstate"
}

module "budget" {
  source = "../budget"

  name                = "${local.name_prefix}-monthly"
  limit_usd           = var.budget_limit_usd
  notification_emails = var.budget_notification_emails
}

# --- OIDC GitHub : aucune clé statique, confiance limitée à ce dépôt ----------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://${local.github_oidc}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "github_trust_plan" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc}:sub"
      values   = local.plan_subjects
    }
  }
}

data "aws_iam_policy_document" "github_trust_apply" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.github_oidc}:sub"
      values   = local.apply_subjects
    }
  }
}

# Accès à l'état : lecture, écriture du verrou .tflock ; le rôle d'apply écrit aussi l'état.
data "aws_iam_policy_document" "state_access" {
  statement {
    sid       = "ListStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket", "s3:GetBucketVersioning"]
    resources = [module.tfstate.bucket_arn]
  }

  statement {
    sid       = "ReadState"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${module.tfstate.bucket_arn}/*"]
  }

  statement {
    sid       = "WriteLock"
    effect    = "Allow"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${module.tfstate.bucket_arn}/*.tflock"]
  }

  statement {
    sid       = "UseStateKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [module.tfstate.kms_key_arn]
  }

  # Le plan n'a aucune raison de lire le contenu d'un objet hors du bucket d'état.
  statement {
    sid           = "DenyObjectReadsOutsideState"
    effect        = "Deny"
    actions       = ["s3:GetObject", "s3:GetObjectVersion"]
    not_resources = ["${module.tfstate.bucket_arn}/*"]
  }
}

data "aws_iam_policy_document" "state_write" {
  statement {
    sid       = "WriteState"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${module.tfstate.bucket_arn}/*"]
  }
}

resource "aws_iam_role" "github_plan" {
  name                 = "${local.name_prefix}-github-plan"
  description          = "Terraform plan depuis GitHub Actions (PR, main, dérive nocturne) : lecture seule."
  assume_role_policy   = data.aws_iam_policy_document.github_trust_plan.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "aws_iam_role_policy" "github_plan_state" {
  name   = "terraform-state"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.state_access.json
}

resource "aws_iam_role" "github_apply" {
  name                 = "${local.name_prefix}-github-apply"
  description          = "Terraform apply depuis GitHub Actions, uniquement via l'environnement protégé ${var.env}."
  assume_role_policy   = data.aws_iam_policy_document.github_trust_apply.json
  max_session_duration = 3600
}

# Le rôle d'apply gère toute l'infrastructure du compte ; les SCP de l'organisation bornent ce qu'il
# peut faire (régions UE, pas d'utilisateur IAM, journaux et sauvegardes protégés).
resource "aws_iam_role_policy_attachment" "github_apply_admin" {
  role       = aws_iam_role.github_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy" "github_apply_state" {
  name   = "terraform-state-write"
  role   = aws_iam_role.github_apply.id
  policy = data.aws_iam_policy_document.state_write.json
}
