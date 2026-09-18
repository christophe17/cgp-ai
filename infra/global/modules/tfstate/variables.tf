variable "bucket_name" {
  description = "Nom du bucket d'état (unique globalement, préfixé par le projet et l'environnement)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Le nom du bucket doit respecter les règles de nommage S3 (minuscules, chiffres, tirets)."
  }
}

variable "kms_alias" {
  description = "Alias de la clé KMS dédiée à l'état, sous la forme alias/<nom>."
  type        = string

  validation {
    condition     = startswith(var.kms_alias, "alias/")
    error_message = "L'alias KMS doit commencer par alias/."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Nombre de jours de conservation des versions non courantes de l'état (historique en cas de retour arrière)."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 30
    error_message = "Conserver au moins 30 jours d'historique d'état."
  }
}
