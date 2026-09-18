# `infra/global/organization`

Racine Terraform du compte de gestion, appliquée en local (exception de bootstrap, une seule fois
puis à chaque changement d'organisation via PR) : organisation, unités `workloads/{dev,protected}`,
trois comptes membres, SCP, bucket d'état du compte de gestion, CloudTrail d'organisation, budget
consolidé et détection d'anomalies, puis Identity Center (module `identity-center`) une fois
l'instance activée dans la console.

Procédure complète : `docs/infra/00-bootstrap.md`. Les variables sensibles (adresses e-mail) vont
dans `terraform.tfvars`, ignoré par git ; `terraform.tfvars.example` en donne la forme.
