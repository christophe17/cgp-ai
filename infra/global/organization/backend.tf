# Bootstrap : un fichier backend_override.tf (ignoré par git) contenant `terraform { backend "local" {} }`
# remplace ce backend le temps du premier apply ; on le supprime ensuite et on migre l'état vers le
# bucket créé par ce root : terraform init -migrate-state -backend-config=backend.hcl (guide 00, §4).
terraform {
  backend "s3" {}
}
