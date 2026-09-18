output "name_prefix" {
  description = "Préfixe de nommage des ressources du module (projet-environnement)."
  value       = local.name_prefix
}

output "tags" {
  description = "Tags appliqués aux ressources du module."
  value       = local.tags
}
