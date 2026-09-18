# Module `security` : Clés KMS gérées client (une par domaine de données : base, documents, audit, journaux), rôles IAM de base, Cognito (user pool, MFA TOTP obligatoire, groupe advisors, client applicatif, inscription sur invitation), WAF.
# Les ressources arrivent en phase 3 (docs/07-roadmap.md) ; le module expose déjà son préfixe et ses tags.

locals {
  name_prefix = "${var.project}-${var.env}"
  tags        = var.tags
}
