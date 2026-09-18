output "bucket_name" {
  description = "Nom du bucket d'état."
  value       = aws_s3_bucket.tfstate.bucket
}

output "bucket_arn" {
  description = "ARN du bucket d'état."
  value       = aws_s3_bucket.tfstate.arn
}

output "kms_key_arn" {
  description = "ARN de la clé KMS qui chiffre l'état."
  value       = aws_kms_key.tfstate.arn
}

output "kms_alias" {
  description = "Alias de la clé KMS, utilisé dans backend.hcl."
  value       = aws_kms_alias.tfstate.name
}
