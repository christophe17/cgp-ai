variable "name" {
  description = "Nom du budget (unique dans le compte)."
  type        = string
}

variable "limit_usd" {
  description = "Plafond mensuel en USD (AWS Budgets ne gère que le dollar ; le montant approuvé en euros est arrondi)."
  type        = number

  validation {
    condition     = var.limit_usd > 0
    error_message = "Le plafond doit être strictement positif."
  }
}

variable "notification_emails" {
  description = "Destinataires des alertes à 50 %, 80 %, 100 % du réel et 100 % de la prévision."
  type        = list(string)

  validation {
    condition     = length(var.notification_emails) > 0
    error_message = "Au moins un destinataire est requis."
  }
}

variable "time_period_start" {
  description = "Début de la période budgétaire, au format AAAA-MM-JJ_HH:MM."
  type        = string
  default     = "2026-09-01_00:00"
}
