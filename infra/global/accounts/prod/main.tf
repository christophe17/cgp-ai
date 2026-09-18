# Bootstrap du compte prod, exécuté depuis le compte de gestion via OrganizationAccountAccessRole.
module "bootstrap" {
  source = "../../modules/account-bootstrap"

  project                    = var.project
  env                        = "prod"
  account_id                 = var.account_id
  github_repository          = var.github_repository
  budget_limit_usd           = var.budget_limit_usd
  budget_notification_emails = var.budget_notification_emails
}
