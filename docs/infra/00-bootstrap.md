# 00 — Bootstrap : organisation, comptes, SCP, Identity Center, état Terraform, OIDC, budgets

Module(s) : `infra/global/organization`, `infra/global/accounts/<env>`, `infra/global/modules/{tfstate,budget,identity-center,account-bootstrap}`.

## 1. Ce que c'est, et pourquoi ici

Le socle d'identité, d'isolation et de gouvernance sur lequel tout le reste s'appuie : une organisation
AWS avec trois comptes membres cloisonnés par unité d'organisation et bornés par des SCP, un accès
humain par Identity Center avec MFA, un accès machine par OIDC GitHub sans aucune clé, et pour chaque
compte un bucket d'état chiffré et un budget qui alerte. Il sert `docs/08-production-readiness.md`
§1 (comptes, SCP, SSO, break-glass), §2 (backend S3 par compte, verrouillage natif) et §8 (budgets),
et la règle 7 de `CLAUDE.md` (région UE uniquement).

## 2. Ce que je sais déjà, ce qui est nouveau

| Ressource | Classement proposé | Ce que le guide tranche |
|---|---|---|
| `aws_organizations_organization` | à vérifier | Les SCP **ne s'appliquent jamais au compte de gestion**. Sa protection ne vient que d'Identity Center + MFA et de la suppression des clés IAM. |
| Unités d'organisation `workloads/{dev,protected}` | connu | Une SCP attachée à une OU s'applique à toute sa descendance ; `dev` reçoit les garde-fous mais pas la protection anti-suppression, pour rester destructible. |
| `aws_organizations_account` | nouveau | Chaque compte exige une adresse e-mail unique dans tout AWS ; la création est asynchrone ; la fermeture prend 90 jours et un compte fermé compte dans le quota. `close_on_deletion = false` et `prevent_destroy` verrouillent le tout. |
| SCP en `Deny` avec `NotAction` | à vérifier | Une SCP ne donne jamais de droits, elle en retire ; la restriction de région doit exclure les services globaux (leur point d'entrée est `us-east-1`), dont `wafv2` et `acm` pour le WAF de CloudFront. |
| IAM Identity Center | nouveau | L'instance s'active dans la console, dans **une** région, une fois. Deux API distinctes : `identitystore` (utilisateurs, groupes) et `sso-admin` (permission sets, affectations). Un utilisateur créé par API ne reçoit pas d'invitation : on lui envoie une réinitialisation de mot de passe. |
| Permission sets `admin`, `readonly`, `break-glass` | à vérifier | `ReadOnlyAccess` lit le contenu des objets S3 et des tables ; `ViewOnlyAccess` ne lit que les métadonnées. « Lecture seule par défaut » sur des comptes de données personnelles, c'est le second. |
| Bucket d'état (`tfstate`) | connu, sauf `use_lockfile` | Depuis Terraform 1.10, le verrou est un objet `.tflock` dans le bucket : plus de table DynamoDB, mais le rôle de plan doit pouvoir écrire ce fichier. |
| `aws_iam_openid_connect_provider` GitHub | à vérifier | AWS n'utilise plus l'empreinte de certificat pour GitHub ; c'est la revendication `sub` du jeton qui fait toute la sécurité (`repo:…:pull_request`, `repo:…:ref:refs/heads/main`, `repo:…:environment:<env>`). |
| Rôles `github-plan` et `github-apply` | à vérifier | Le plan a besoin de lire toute la configuration (donc `ReadOnlyAccess`), mais pas le contenu des données : un `Deny` explicite sur `s3:GetObject` hors du bucket d'état le dit. L'apply est administrateur, borné par les SCP et par l'environnement GitHub protégé. |
| CloudTrail d'organisation | nouveau | La politique de clé KMS exige le contexte de chiffrement `aws:cloudtrail:arn` ; la politique de bucket autorise deux préfixes, `AWSLogs/<compte de gestion>/` et `AWSLogs/<id d'organisation>/`. |
| AWS Budgets | à vérifier | Uniquement en USD. Un compte membre ne voit ses coûts que si `iam_user_access_to_billing = "ALLOW"` a été demandé à sa création. |
| Détection d'anomalies (Cost Explorer) | nouveau | Gratuite ; un moniteur par dimension `SERVICE`, un abonnement par e-mail avec un seuil d'impact absolu. |

Relis cette liste après lecture et corrige le classement à la main dans `carte-des-competences.md`.

## 3. Lecture guidée du HCL réel

### `organization/main.tf` — organisation, unités, comptes

`aws_organizations_organization` active `feature_set = "ALL"` (indispensable aux SCP) et déclare les
services autorisés à agir sur toute l'organisation : CloudTrail (journal d'organisation), Identity
Center, AWS Backup (politiques de sauvegarde, phase 3). `enabled_policy_types` limite volontairement
aux SCP : pas de politique de tags ni de sauvegarde tant qu'on ne s'en sert pas.

La structure `workloads > {dev, protected}` porte la seule asymétrie de gouvernance du projet :
`staging` et `prod` reçoivent une SCP de plus. `local.account_parent` fixe le rattachement sans
condition dans la boucle `for_each`.

`aws_organizations_account` : `iam_user_access_to_billing = "ALLOW"` est nécessaire aux budgets dans
le compte membre ; `role_name` est le rôle qu'Organizations crée dans le compte et que le bootstrap
assume ensuite ; `ignore_changes = [role_name]` parce que l'API ne le relit jamais.

### `organization/scp.tf` — trois politiques, deux cibles

- `eu_regions_only` : un `Deny` sur tout ce qui n'est pas listé dans `not_actions` quand
  `aws:RequestedRegion` n'est pas dans `var.eu_regions`. La liste `not_actions` est le point délicat :
  chaque service global oublié casse quelque chose de non évident (WAF de CloudFront, ACM pour
  CloudFront, Route 53, facturation). Six régions UE seulement : Londres et Zurich sont hors Union.
- `baseline_guardrails` : plus d'utilisateur IAM, de clé d'accès ni de profil de connexion dans les
  comptes membres ; aucun départ de l'organisation.
- `protect_security_services` : CloudTrail, clés KMS et sauvegardes indestructibles, y compris pour
  le rôle d'apply de la CI. Attachée à `protected` seulement.

### `organization/cloudtrail.tf` — journal d'organisation

L'ARN de la trail est construit à la main (`local.cloudtrail_arn`) pour casser la dépendance
circulaire entre la politique de bucket (qui cite la trail) et la trail (qui exige la politique).
Rétention 400 jours, versionnement, KMS avec clé de bucket, TLS obligatoire.

### `organization/budgets.tf` — budget consolidé et anomalies

Le budget consolidé (260 USD, soit 220 € approuvés) vit dans le compte de gestion ; les budgets par
compte vivent dans chaque compte (`account-bootstrap`). Le moniteur d'anomalies par service alerte
dès 10 USD d'impact.

### `modules/tfstate` — un bucket d'état, partout pareil

Versionnement, chiffrement KMS forcé (deux `Deny` : transport non TLS, envoi non chiffré), accès
public bloqué, propriété `BucketOwnerEnforced` (plus d'ACL), expiration des versions non courantes à
90 jours, `prevent_destroy`. Le même module sert le compte de gestion et les trois comptes membres.

### `modules/identity-center` — qui peut faire quoi, où

Trois groupes, trois permission sets, cinq affectations. L'adhésion au groupe `break-glass` est un
`for_each` sur une map vide ou à un élément selon `operator_break_glass` : activer l'accès, c'est une
PR et un apply, donc une trace.

### `modules/account-bootstrap` — ce que la CI reçoit

Le rôle de plan fait confiance à deux sujets (PR du dépôt, branche `main`), le rôle d'apply à un
seul (`environment:<env>`). Le premier a `ReadOnlyAccess` plus l'état, moins le contenu des objets ;
le second `AdministratorAccess` plus l'écriture de l'état. Le budget par compte est là aussi.

### `accounts/<env>` — trois racines identiques

Chacune assume `OrganizationAccountAccessRole` dans son compte et appelle `account-bootstrap` ; son
état est dans le bucket du compte de gestion (`global/accounts/<env>.tfstate`) : pas d'œuf ni de poule.

## 4. Procédure et vérifications après `apply`

Exceptions de bootstrap (exécutées une fois, à la main, dans cet ordre) :

1. **MFA sur l'utilisateur IAM `christophe`** (console IAM → utilisateur → Informations d'identification de
   sécurité → Attribuer un appareil MFA). Vérifier : `aws iam list-mfa-devices --user-name christophe`.
2. Depuis `infra/global/organization` : copier `terraform.tfvars.example` en `terraform.tfvars` (ignoré
   par git), puis créer `backend_override.tf` (ignoré par git lui aussi) qui remplace le backend S3 par
   un état local le temps du premier apply :
   ```bash
   printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
   terraform init
   terraform plan
   terraform apply
   ```
   Attendre que les trois comptes soient `ACTIVE` : `aws organizations list-accounts`.
3. Supprimer `backend_override.tf`, puis migrer l'état local vers le bucket que l'apply vient de créer :
   `rm backend_override.tf && terraform init -migrate-state -backend-config=backend.hcl`.
   Vérifier : `aws s3api list-object-versions --bucket cgp-tfstate-mgmt-749020018778 --prefix global/`,
   puis supprimer `terraform.tfstate*` locaux.
4. **Activer IAM Identity Center** dans la console, région `eu-central-1`, instance d'organisation.
   Passer `identity_center_enabled = true` dans `terraform.tfvars`, `terraform apply`. Dans la console
   Identity Center → Utilisateurs → `christophe` → Réinitialiser le mot de passe → envoyer un e-mail.
   À la première connexion : mot de passe, puis **enregistrer l'appareil MFA** (TOTP).
5. Configurer l'accès local par SSO (`~/.aws/config`) :
   ```ini
   [sso-session cgp]
   sso_start_url = <URL du portail d'accès>
   sso_region = eu-central-1
   sso_registration_scopes = sso:account:access

   [profile cgp-mgmt]
   sso_session = cgp
   sso_account_id = 749020018778
   sso_role_name = cgp-admin
   region = eu-central-1

   [profile cgp-dev]            # cgp-admin sur le compte dev
   [profile cgp-staging-ro]     # cgp-readonly sur staging
   [profile cgp-prod-ro]        # cgp-readonly sur prod
   [profile cgp-staging-break-glass]   # cgp-break-glass, utilisé seulement selon le runbook
   ```
   `aws sso login --profile cgp-mgmt`, puis `aws sts get-caller-identity --profile cgp-mgmt`.
6. Bootstrap des trois comptes, avec `AWS_PROFILE=cgp-mgmt`, depuis `infra/global/accounts/<env>` :
   `terraform.tfvars` (identifiant du compte issu de `member_account_ids`, e-mail), puis
   `terraform init -backend-config=backend.hcl && terraform apply`. Reporter les sorties : bucket dans
   `infra/envs/<env>/*/backend.hcl`, identifiant dans `infra/envs/<env>/*/terraform.tfvars`, et sur
   GitHub `gh variable set AWS_ACCOUNT_ID_<ENV>`.
7. **Supprimer les clés statiques** de l'utilisateur IAM :
   `aws iam list-access-keys --user-name christophe` puis `aws iam delete-access-key --user-name christophe --access-key-id <id>`,
   et retirer la section `[default]` de `~/.aws/credentials`.

Vérifications qui prouvent que ça fait ce qu'on croit :

```bash
# SCP : une région hors UE est refusée dans dev, pas dans le compte de gestion
aws --profile cgp-dev ec2 describe-vpcs --region us-east-1        # AccessDenied ... explicit deny in a service control policy
aws --profile cgp-dev ec2 describe-vpcs --region eu-central-1     # OK
aws --profile cgp-dev iam create-user --user-name test            # refusé par la SCP baseline_guardrails
aws organizations list-policies-for-target --target-id <ou-protected> --filter SERVICE_CONTROL_POLICY

# Lecture seule réelle sur staging
aws --profile cgp-staging-ro sts get-caller-identity              # rôle AWSReservedSSO_cgp-readonly_...
aws --profile cgp-staging-ro s3api list-buckets                   # OK (métadonnées)
aws --profile cgp-staging-ro s3 cp s3://cgp-tfstate-staging-<id>/envs/staging/foundation.tfstate -   # refusé

# État : chiffrement forcé, versionnement, verrou natif
aws --profile cgp-dev s3api get-bucket-versioning --bucket cgp-tfstate-dev-<id>
aws --profile cgp-dev s3api get-bucket-encryption --bucket cgp-tfstate-dev-<id>
# lancer deux `terraform plan` simultanés dans infra/envs/dev/foundation : le second attend le .tflock

# CloudTrail et OIDC
aws --profile cgp-mgmt cloudtrail get-trail-status --name cgp-organization
aws --profile cgp-dev iam get-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::<id>:oidc-provider/token.actions.githubusercontent.com
gh workflow run terraform.yml   # le job plan-dev doit obtenir des credentials sans aucun secret
```

## 5. Coût

| Poste | `dev` | `staging` allumé | Tout éteint |
|---|---|---|---|
| Organizations, Identity Center, Budgets (sans action), anomalies | 0 | 0 | 0 |
| Clés KMS (1 USD/clé/mois) : 3 états + CloudTrail + gestion | 1 | 1 | 5 au total |
| CloudTrail : premier journal d'événements de gestion gratuit ; S3 quelques centimes | ~0,1 | ~0,1 | ~0,3 |
| Bucket d'état : quelques Ko | ~0 | ~0 | ~0 |

Ordre de grandeur pour tout le bootstrap : **6 USD par mois**, identique allumé ou éteint.

## 6. Pièges

- **Le compte de gestion échappe aux SCP.** L'utilisateur IAM administrateur y restait sans MFA avec
  des clés statiques (constat du 2026-09-18) : c'est la première chose à corriger, avant même de créer
  l'organisation.
- **Un service global oublié dans `not_actions`** produit des refus incompréhensibles hors UE ; le
  premier candidat est le WAF de CloudFront (Amplify), qui vit en `us-east-1`.
- **Les utilisateurs Identity Center créés par API n'ont pas de mot de passe** ni d'invitation : sans
  la réinitialisation depuis la console, l'opérateur ne peut pas se connecter.
- **Le rôle de plan et le verrou** : avec `use_lockfile`, un rôle « lecture seule » qui ne peut pas
  écrire `*.tflock` échoue avec une erreur de verrouillage, pas de permission.
- **Les adresses e-mail des comptes ne sont pas des secrets, mais on ne les publie pas** (dépôt
  public) : `infra/global/**/terraform.tfvars` est ignoré par git, l'exemple porte des valeurs fictives.
- **Fermer un compte prend 90 jours** et compte dans le quota (10 comptes par défaut) : ne pas
  « recréer pour voir ».

## 7. Questions d'entretien

1. Pourquoi une SCP ne protège-t-elle pas le compte de gestion, et que fait-on à la place ?
2. `ReadOnlyAccess` ou `ViewOnlyAccess` pour un accès humain « lecture seule » sur un compte de données personnelles ? Quelle différence concrète ?
3. Comment un job GitHub Actions obtient-il des credentials AWS sans secret, et qu'est-ce qui empêche un fork du dépôt d'en faire autant ?
4. Que change `use_lockfile` par rapport au verrou DynamoDB, et quel droit supplémentaire faut-il au rôle de plan ?
5. Pourquoi la restriction de région par SCP doit-elle laisser passer `wafv2` et `acm` ?
