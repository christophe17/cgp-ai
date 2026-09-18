variable "aws_region" {
  description = "Région AWS unique du projet (UE)."
  type        = string
  default     = "eu-central-1"

  validation {
    condition     = contains(["eu-central-1", "eu-west-1", "eu-west-3", "eu-north-1", "eu-south-1", "eu-south-2"], var.aws_region)
    error_message = "La région doit être une région de l'Union européenne."
  }
}

variable "account_id" {
  description = "Identifiant du compte AWS de cet environnement ; le provider refuse tout autre compte."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id)) && var.account_id != "000000000000"
    error_message = "Identifiant de compte non renseigné : exécuter le bootstrap (docs/infra/00-bootstrap.md) puis reporter l'identifiant dans terraform.tfvars."
  }
}

variable "owner" {
  description = "Valeur du tag owner (responsable de la ressource)."
  type        = string
  default     = "christophe"
}
