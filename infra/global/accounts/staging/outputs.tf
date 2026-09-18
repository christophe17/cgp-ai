output "tfstate_bucket" {
  description = "Bucket d'état du compte, à reporter dans infra/envs/<env>/*/backend.hcl."
  value       = module.bootstrap.tfstate_bucket
}

output "tfstate_kms_alias" {
  description = "Alias KMS de l'état."
  value       = module.bootstrap.tfstate_kms_alias
}

output "github_plan_role_arn" {
  description = "Rôle de plan assumé par GitHub Actions."
  value       = module.bootstrap.github_plan_role_arn
}

output "github_apply_role_arn" {
  description = "Rôle d'apply assumé par GitHub Actions via l'environnement protégé."
  value       = module.bootstrap.github_apply_role_arn
}
