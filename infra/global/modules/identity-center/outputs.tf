output "instance_arn" {
  description = "ARN de l'instance Identity Center."
  value       = local.instance_arn
}

output "identity_store_id" {
  description = "Identifiant du magasin d'identités."
  value       = local.identity_store_id
}

output "operator_user_id" {
  description = "Identifiant de l'utilisateur opérateur."
  value       = aws_identitystore_user.operator.user_id
}

output "group_ids" {
  description = "Identifiants des groupes admins, readers et break-glass."
  value = {
    admins      = aws_identitystore_group.admins.group_id
    readers     = aws_identitystore_group.readers.group_id
    break_glass = aws_identitystore_group.break_glass.group_id
  }
}

output "permission_set_arns" {
  description = "ARN des permission sets admin, readonly et break-glass."
  value = {
    admin       = aws_ssoadmin_permission_set.admin.arn
    readonly    = aws_ssoadmin_permission_set.readonly.arn
    break_glass = aws_ssoadmin_permission_set.break_glass.arn
  }
}
