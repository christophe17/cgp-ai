# STATE — état courant du projet

Mis à jour le 2026-09-18. Relu avec `CLAUDE.md` et `JOURNAL.md` à chaque session.

## Phase en cours : 0 — Socle du dépôt et des comptes

### Fait (sans dépendance AWS)

- Monorepo `uv` (Python 3.12) : CLI `cgp` à la racine, 8 packages et 6 services en squelette avec README
  et test de fumée ; `cgp validation-report` opérationnel (collecteurs `docs` et `prompts`).
- Qualité : ruff, mypy strict, pytest (24 tests), nbmake, pre-commit (ruff, mypy, terraform fmt et
  validate, tflint, trivy, gitleaks, commits conventionnels), `docker-compose.yml` (pgvector pg16 par digest).
- `Makefile` : `install`, `dev-up`, `dev-down`, `lint`, `format`, `test`, `notebooks-ci`,
  `notebooks-full`, `validation-report`, `tf-check`, `tf-plan`, `tf-apply` (dev uniquement).
- Terraform : `infra/global` (organisation, OU, comptes, SCP, CloudTrail, budgets, Identity Center,
  bootstrap par compte avec état, OIDC, rôles CI, budget), 11 modules de domaine (contrat variables et
  sorties), 12 racines `envs/<env>/<couche>` ; `fmt`, `validate`, tflint et trivy verts ; `plan` de la
  racine `organization` exécuté en lecture seule contre le compte de gestion.
- GitHub Actions : `ci.yml`, `terraform.yml`, `terraform-layer.yml` (réutilisable, artefact de plan
  chiffré), `promote.yml`, `drift.yml` ; Dependabot ; gabarit de PR.
- Vérification régionale consignée dans `infra/README.md` : `eu-central-1` conservée ; Policy in
  AgentCore retenu dans le module `gateway`.
- Apprentissage : notebook `00_visite_guidee` (mode `sample`, exécuté en CI), guides
  `docs/infra/00-bootstrap.md` et `10-ci-cd.md` (première version), carte des compétences initialisée
  (`docs/infra/carte-des-competences.md`, colonne « Moi » vide), runbooks `break-glass` et `derive-terraform`.

### En attente : bootstrap AWS (actions manuelles de l'auteur, `docs/infra/00-bootstrap.md` §4)

1. MFA sur l'utilisateur IAM `christophe` du compte 749020018778.
2. `terraform apply` de `infra/global/organization` (organisation, trois comptes, SCP, CloudTrail, budgets).
3. Activation d'IAM Identity Center dans la console (`eu-central-1`), puis second apply
   (`identity_center_enabled = true`), mot de passe et MFA de l'opérateur, `aws sso login`.
4. Bootstrap des trois comptes (`infra/global/accounts/<env>`) ; report des identifiants dans
   `infra/envs/<env>/*/backend.hcl` et `terraform.tfvars` ; variables GitHub `AWS_ACCOUNT_ID_<ENV>`.
5. Suppression des clés statiques de l'utilisateur IAM.

Tant que 1 à 5 ne sont pas faits : le job `plan-dev` de la CI est rouge (pas de rôle OIDC), les
`backend.hcl` et `terraform.tfvars` de `infra/envs` portent des valeurs de remplissage.

### Critères d'acceptation de la phase 0

| Critère | État |
|---|---|
| `uv run pytest` et `make notebooks-ci` passent en CI | **oui** (run `ci` 35348485387 du 2026-09-18 : 4 jobs verts) |
| `terraform plan` passe sur toutes les couches de `dev` en CI | bloqué par le bootstrap |
| Un `apply` manuel vers `staging` ou `prod` est impossible (aucun credential local) | bloqué par le bootstrap (permission sets lecture seule) |

## Chiffres actuels

Aucune mesure en phase 0. Dépense AWS du mois d'août 2026 : 0,06 USD. Budgets approuvés le
2026-09-18 : dev 60 €, staging 120 €, prod 40 € par mois (saisis 70, 140, 50 USD ; consolidé 260 USD).

## Décisions en attente

- **Licence du dépôt public** `christophe17/cgp-ai` : sans fichier `LICENSE`, tous droits réservés.
- Nom de domaine pour Amplify Hosting (phase 7).

## Phase suivante

Phase 1 — Domaine et paramètres. Ne commence pas avant l'acceptation de la phase 0.
