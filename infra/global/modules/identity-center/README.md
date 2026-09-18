# Module `identity-center`

Accès humain à l'organisation via IAM Identity Center avec MFA (`docs/08-production-readiness.md`
§1) : un utilisateur opérateur, trois groupes et trois permission sets.

| Permission set | Politiques | Session | Comptes | Groupe |
|---|---|---|---|---|
| `<projet>-admin` | AdministratorAccess | 4 h | gestion, dev | `<projet>-admins` |
| `<projet>-readonly` | ViewOnlyAccess, CloudWatchLogsReadOnlyAccess | 8 h | staging, prod | `<projet>-readers` |
| `<projet>-break-glass` | AdministratorAccess | 1 h | staging, prod | `<projet>-break-glass` |

`ViewOnlyAccess` (et non `ReadOnlyAccess`) : lecture des métadonnées et des journaux, mais pas du
contenu des objets S3 ni des données ; c'est le sens de « lecture seule par défaut » sur des comptes
qui hébergent des données patrimoniales.

L'adhésion au groupe break-glass est pilotée par `operator_break_glass` : une PR l'active, l'apply
est journalisé (CloudTrail d'organisation), une PR la retire. Procédure : `docs/runbooks/break-glass.md`.
L'instance Identity Center est activée dans la console (exception de bootstrap) ; ce module ne
s'applique qu'ensuite (`identity_center_enabled = true`).
