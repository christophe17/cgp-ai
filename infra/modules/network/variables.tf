variable "project" {
  description = "Nom court du projet, préfixe des ressources."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.project))
    error_message = "Le nom du projet est en minuscules, chiffres et tirets, 2 à 16 caractères."
  }
}

variable "env" {
  description = "Environnement cible : dev, staging ou prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.env)
    error_message = "env doit valoir dev, staging ou prod."
  }
}

variable "tags" {
  description = "Tags communs à toutes les ressources ; les clés project, env, layer, owner et data_classification sont obligatoires."
  type        = map(string)

  validation {
    condition = alltrue([
      for key in ["project", "env", "layer", "owner", "data_classification"] : contains(keys(var.tags), key)
    ])
    error_message = "Les tags project, env, layer, owner et data_classification sont obligatoires."
  }
}
