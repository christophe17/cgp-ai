output "organization_id" {
  description = "Identifiant de l'organisation."
  value       = aws_organizations_organization.this.id
}

output "organizational_unit_ids" {
  description = "Identifiants des unités d'organisation."
  value = {
    workloads = aws_organizations_organizational_unit.workloads.id
    dev       = aws_organizations_organizational_unit.dev.id
    protected = aws_organizations_organizational_unit.protected.id
  }
}

output "member_account_ids" {
  description = "Identifiants des comptes membres par environnement, à reporter dans infra/global/accounts/<env> et infra/envs/<env>/*/terraform.tfvars."
  value       = { for env, account in aws_organizations_account.member : env => account.id }
}

output "management_tfstate_bucket" {
  description = "Bucket d'état du compte de gestion (états de infra/global/*)."
  value       = module.tfstate.bucket_name
}

output "cloudtrail_bucket" {
  description = "Bucket des journaux CloudTrail de l'organisation."
  value       = aws_s3_bucket.cloudtrail.bucket
}

output "identity_center" {
  description = "Instance Identity Center, groupes et permission sets (nul tant qu'Identity Center n'est pas activé)."
  value       = one(module.identity_center[*])
}
