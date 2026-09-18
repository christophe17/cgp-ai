variable "project" {
  description = "Nom court du projet, préfixe des ressources."
  type        = string
  default     = "cgp"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.project))
    error_message = "Le nom du projet est en minuscules, chiffres et tirets, 2 à 16 caractères."
  }
}

variable "owner" {
  description = "Valeur du tag owner (responsable des ressources)."
  type        = string
  default     = "christophe"
}

variable "aws_region" {
  description = "Région AWS unique du projet ; doit appartenir à l'Union européenne."
  type        = string
  default     = "eu-central-1"

  validation {
    condition     = contains(var.eu_regions, var.aws_region)
    error_message = "La région doit figurer dans eu_regions."
  }
}

variable "eu_regions" {
  description = "Régions AWS situées dans l'Union européenne ; toute autre région est refusée par SCP."
  type        = list(string)
  default     = ["eu-central-1", "eu-west-1", "eu-west-3", "eu-north-1", "eu-south-1", "eu-south-2"]
}

variable "management_account_id" {
  description = "Identifiant du compte de gestion (compte existant qui crée l'organisation)."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.management_account_id))
    error_message = "L'identifiant de compte comporte 12 chiffres."
  }
}

variable "member_accounts" {
  description = "Comptes membres à créer : clé = environnement (dev, staging, prod), adresse e-mail racine distincte et plafond mensuel en USD."
  type = map(object({
    email            = string
    budget_limit_usd = number
  }))

  validation {
    condition     = alltrue([for env in keys(var.member_accounts) : contains(["dev", "staging", "prod"], env)])
    error_message = "Les clés de member_accounts sont dev, staging et prod."
  }

  validation {
    condition     = alltrue([for account in values(var.member_accounts) : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", account.email))])
    error_message = "Chaque compte membre a une adresse e-mail valide."
  }

  validation {
    condition     = length(distinct([for account in values(var.member_accounts) : account.email])) == length(var.member_accounts)
    error_message = "Chaque compte membre a une adresse e-mail distincte."
  }
}

variable "organization_budget_limit_usd" {
  description = "Plafond mensuel consolidé de l'organisation, en USD."
  type        = number
}

variable "budget_notification_emails" {
  description = "Destinataires des alertes de budget et de dépense anormale."
  type        = list(string)
}

variable "anomaly_threshold_usd" {
  description = "Impact absolu minimal (USD) d'une anomalie de coût pour déclencher une alerte."
  type        = number
  default     = 10
}

variable "identity_center_enabled" {
  description = "Vrai une fois IAM Identity Center activé dans la console (exception de bootstrap) ; crée alors l'utilisateur, les groupes, les permission sets et les affectations."
  type        = bool
  default     = false
}

variable "operator" {
  description = "Utilisateur Identity Center de l'opérateur unique du projet."
  type = object({
    user_name   = string
    given_name  = string
    family_name = string
    email       = string
  })
}

variable "operator_break_glass" {
  description = "Vrai pendant une procédure break-glass (docs/runbooks/break-glass.md) : l'opérateur rejoint le groupe break-glass, administrateur d'une heure sur staging et prod."
  type        = bool
  default     = false
}

variable "cloudtrail_retention_days" {
  description = "Durée de conservation des journaux CloudTrail de l'organisation, en jours."
  type        = number
  default     = 400

  validation {
    condition     = var.cloudtrail_retention_days >= 365
    error_message = "Conserver les journaux CloudTrail au moins un an."
  }
}
