variable "project" {
  description = "Nom court du projet, préfixe des groupes et permission sets."
  type        = string
}

variable "management_account_id" {
  description = "Identifiant du compte de gestion (accès administrateur de l'opérateur)."
  type        = string
}

variable "member_account_ids" {
  description = "Identifiants des comptes membres par environnement (dev, staging, prod)."
  type        = map(string)

  validation {
    condition     = alltrue([for env in ["dev", "staging", "prod"] : contains(keys(var.member_account_ids), env)])
    error_message = "Les trois environnements dev, staging et prod doivent être présents."
  }
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
  description = "Vrai pendant une procédure break-glass : l'opérateur rejoint le groupe administrateur d'une heure sur staging et prod."
  type        = bool
  default     = false
}

variable "admin_session_duration" {
  description = "Durée de session du permission set administrateur (ISO 8601)."
  type        = string
  default     = "PT4H"
}

variable "readonly_session_duration" {
  description = "Durée de session du permission set lecture seule (ISO 8601)."
  type        = string
  default     = "PT8H"
}

variable "break_glass_session_duration" {
  description = "Durée de session du permission set break-glass (ISO 8601), volontairement courte."
  type        = string
  default     = "PT1H"
}
