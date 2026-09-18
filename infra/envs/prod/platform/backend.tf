# Configuration partielle : bucket, clé et chiffrement viennent de backend.hcl
# (terraform init -backend-config=backend.hcl). Un état par environnement et par couche.
terraform {
  backend "s3" {}
}
