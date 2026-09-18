# Politiques de contrôle des services (SCP). Elles ne s'appliquent jamais au compte de gestion :
# sa protection repose sur Identity Center + MFA et sur la suppression des clés IAM (guide 00).

# Régions UE uniquement. Les services globaux sont exclus de la restriction (leur point d'entrée est
# us-east-1) : IAM, STS, Organizations, Identity Center, facturation, Route 53, CloudFront, ACM et
# WAF (le WAF d'une distribution CloudFront, donc d'Amplify Hosting, vit en us-east-1).
data "aws_iam_policy_document" "eu_regions_only" {
  statement {
    sid    = "DenyOutsideEuropeanUnion"
    effect = "Deny"
    not_actions = [
      "account:*",
      "acm:*",
      "billing:*",
      "budgets:*",
      "ce:*",
      "cloudfront:*",
      "cur:*",
      "freetier:*",
      "health:*",
      "iam:*",
      "invoicing:*",
      "notifications:*",
      "organizations:*",
      "payments:*",
      "pricing:*",
      "route53:*",
      "route53domains:*",
      "shield:*",
      "sso:*",
      "sts:*",
      "support:*",
      "tax:*",
      "trustedadvisor:*",
      "wafv2:*",
    ]
    resources = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = var.eu_regions
    }
  }
}

# Garde-fous de base : aucun utilisateur IAM ni clé d'accès (l'accès humain passe par Identity
# Center, l'accès machine par OIDC) ; aucun compte ne quitte l'organisation.
data "aws_iam_policy_document" "baseline_guardrails" {
  statement {
    sid    = "DenyIamUsersAndAccessKeys"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "iam:UploadSSHPublicKey",
      "iam:CreateServiceSpecificCredential",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DenyLeavingOrganization"
    effect    = "Deny"
    actions   = ["organizations:LeaveOrganization"]
    resources = ["*"]
  }
}

# Services de sécurité protégés (staging, prod) : CloudTrail, clés KMS et sauvegardes ne peuvent
# être ni désactivés ni supprimés, même par le rôle d'apply de la CI.
data "aws_iam_policy_document" "protect_security_services" {
  statement {
    sid    = "ProtectCloudTrail"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
      "cloudtrail:PutEventSelectors",
      "cloudtrail:DeleteEventDataStore",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ProtectKmsKeys"
    effect = "Deny"
    actions = [
      "kms:ScheduleKeyDeletion",
      "kms:DisableKey",
      "kms:DisableKeyRotation",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ProtectBackups"
    effect = "Deny"
    actions = [
      "backup:DeleteBackupVault",
      "backup:DeleteBackupPlan",
      "backup:DeleteBackupSelection",
      "backup:DeleteRecoveryPoint",
      "backup:UpdateRecoveryPointLifecycle",
    ]
    resources = ["*"]
  }
}

resource "aws_organizations_policy" "eu_regions_only" {
  name        = "${var.project}-eu-regions-only"
  description = "Refuse toute action hors des régions de l'Union européenne, services globaux exceptés."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.eu_regions_only.json
}

resource "aws_organizations_policy" "baseline_guardrails" {
  name        = "${var.project}-baseline-guardrails"
  description = "Aucun utilisateur IAM ni clé d'accès ; aucun départ de l'organisation."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.baseline_guardrails.json
}

resource "aws_organizations_policy" "protect_security_services" {
  name        = "${var.project}-protect-security-services"
  description = "CloudTrail, KMS et sauvegardes non désactivables (staging, prod)."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.protect_security_services.json
}

resource "aws_organizations_policy_attachment" "eu_regions_only" {
  policy_id = aws_organizations_policy.eu_regions_only.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "baseline_guardrails" {
  policy_id = aws_organizations_policy.baseline_guardrails.id
  target_id = aws_organizations_organizational_unit.workloads.id
}

resource "aws_organizations_policy_attachment" "protect_security_services" {
  policy_id = aws_organizations_policy.protect_security_services.id
  target_id = aws_organizations_organizational_unit.protected.id
}
