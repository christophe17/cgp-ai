# Bootstrap du compte dev, exécuté depuis le compte de gestion via OrganizationAccountAccessRole.
module "bootstrap" {
  source = "../../modules/account-bootstrap"

  project                    = var.project
  env                        = "dev"
  account_id                 = var.account_id
  github_repository          = var.github_repository
  budget_limit_usd           = var.budget_limit_usd
  budget_notification_emails = var.budget_notification_emails
}
