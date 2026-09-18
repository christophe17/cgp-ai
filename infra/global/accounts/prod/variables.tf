variable "project" {
  description = "Nom court du projet, préfixe des ressources."
  type        = string
  default     = "cgp"
}

variable "owner" {
  description = "Valeur du tag owner (responsable des ressources)."
  type        = string
  default     = "christophe"
}

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
  description = "Identifiant du compte membre (sortie member_account_ids de infra/global/organization)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id)) && var.account_id != "000000000000"
    error_message = "Identifiant de compte non renseigné : reporter la sortie member_account_ids du root organization."
  }
}

variable "github_repository" {
  description = "Dépôt GitHub autorisé à assumer les rôles OIDC (propriétaire/nom)."
  type        = string
  default     = "christophe17/cgp-ai"
}

variable "budget_limit_usd" {
  description = "Plafond mensuel du compte en USD (montant approuvé en euros, arrondi)."
  type        = number
}

variable "budget_notification_emails" {
  description = "Destinataires des alertes de budget."
  type        = list(string)
}
