# Module `frontend` : Amplify Hosting (Next.js SSR, branche par environnement, domaine, CloudFront), association WAF, variables d'environnement par branche.
# Les ressources arrivent en phase 7 (docs/07-roadmap.md) ; le module expose déjà son préfixe et ses tags.

locals {
  name_prefix = "${var.project}-${var.env}"
  tags        = var.tags
}
