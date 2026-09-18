output "tfstate_bucket" {
  description = "Bucket d'état du compte, à reporter dans les backend.hcl des couches de l'environnement."
  value       = module.tfstate.bucket_name
}

output "tfstate_kms_alias" {
  description = "Alias KMS de l'état, à reporter dans les backend.hcl."
  value       = module.tfstate.kms_alias
}

output "github_plan_role_arn" {
  description = "Rôle assumé par la CI pour les plans (PR, main, dérive)."
  value       = aws_iam_role.github_plan.arn
}

output "github_apply_role_arn" {
  description = "Rôle assumé par la CI pour les applies, via l'environnement GitHub protégé."
  value       = aws_iam_role.github_apply.arn
}
