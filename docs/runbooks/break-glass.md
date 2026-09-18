# Runbook — accès break-glass à `staging` ou `prod`

**Quand** : une action d'écriture manuelle sur `staging` ou `prod` est indispensable et ne peut pas
attendre un passage par la CI (incident, restauration, rotation d'urgence). Toute autre situation passe
par une PR et la promotion (`docs/infra/10-ci-cd.md`).

**Principe** : l'accès humain à ces comptes est en lecture seule (`cgp-readonly`). Le permission set
`cgp-break-glass` (administrateur, session d'une heure) n'est atteignable que par le groupe
`cgp-break-glass`, dont l'adhésion est pilotée par Terraform et donc journalisée.

## Procédure

1. Ouvrir une entrée dans `JOURNAL.md` : date, heure, compte, raison, action prévue.
2. PR sur `infra/global/organization/terraform.tfvars.example` documentant le passage, puis en local :
   `operator_break_glass = true` dans `terraform.tfvars` et
   `make tf-global-apply ROOT=organization` (profil `cgp-mgmt`).
3. `aws sso login --profile cgp-<env>-break-glass` (profil défini dans `docs/infra/00-bootstrap.md` §4),
   vérifier `aws sts get-caller-identity`.
4. Exécuter **uniquement** l'action prévue. Noter chaque commande dans l'entrée du journal.
5. Remettre `operator_break_glass = false`, réappliquer, vérifier
   `aws identitystore list-group-memberships` (groupe vide).
6. Si une ressource a été modifiée hors Terraform : PR d'alignement (`import` ou correction du HCL)
   dans les 24 h ; le plan nocturne (`drift.yml`) doit repasser au vert.
7. Clôturer l'entrée du journal avec les identifiants d'événements CloudTrail
   (`aws cloudtrail lookup-events --lookup-attributes AttributeKey=Username,AttributeValue=<utilisateur>`).

## Vérifications après coup

- CloudTrail d'organisation : les appels `AssumeRoleWithSAML` puis les actions, sur le compte concerné.
- Aucun membre restant dans le groupe `cgp-break-glass`.
- Post-mortem sans blâme si l'origine est un incident de gravité haute (`docs/08` §6).
