variable "project" {
  description = "Nom court du projet, préfixe des ressources."
  type        = string
  default     = "cgp"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.project))
    error_message = "Le nom du projet est en minuscules, chiffres et tirets, 2 à 16 caractères."
  }
}

variable "env" {
  description = "Environnement du compte membre : dev, staging ou prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env doit valoir dev, staging ou prod."
  }
}

variable "account_id" {
  description = "Identifiant du compte membre (12 chiffres), utilisé dans le nom du bucket d'état."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "L'identifiant de compte comporte 12 chiffres."
  }
}

variable "github_repository" {
  description = "Dépôt GitHub autorisé à assumer les rôles OIDC, sous la forme propriétaire/nom."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "Le dépôt s'écrit propriétaire/nom."
  }
}

variable "budget_limit_usd" {
  description = "Plafond mensuel du compte en USD."
  type        = number
}

variable "budget_notification_emails" {
  description = "Destinataires des alertes de budget."
  type        = list(string)
}
