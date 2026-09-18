# 10 — CI/CD : OIDC GitHub → AWS, environnements protégés, plan en PR, apply de l'artefact relu

Fichiers : `.github/workflows/{ci,terraform,terraform-layer,promote,drift}.yml`, `.github/dependabot.yml`.
Première version (phase 0) : OIDC, environnements, plan et apply Terraform, dérive nocturne. La
promotion applicative (images, migrations, évals bloquantes), le rollback exécuté en `staging`, les
SBOM et scans d'images arrivent en phase 8 et complètent ce guide.

## 1. Ce que c'est, et pourquoi ici

Cinq workflows qui font respecter la règle « aucune ressource hors Terraform, aucun apply humain vers
`staging` ou `prod` » (`CLAUDE.md` règle 9, `docs/08` §2 et §7) : la CI obtient ses droits AWS par
OIDC sans aucune clé, un plan est publié sur chaque PR, l'apply de `dev` suit la fusion, `staging` et
`prod` n'avancent qu'après approbation dans un environnement GitHub protégé, en appliquant exactement
le plan relu, et la dérive est cherchée chaque nuit.

## 2. Ce que je sais déjà, ce qui est nouveau

| Élément | Classement proposé | Ce que le guide tranche |
|---|---|---|
| GitHub Actions, matrices, `needs`, concurrence | connu | rien à lire |
| Actions épinglées par SHA de commit | à vérifier | Un tag (`v4`) est mobile ; le SHA ne l'est pas. Dependabot met à jour le SHA et le commentaire de version. |
| OIDC `token.actions.githubusercontent.com` | nouveau | Le rôle AWS fait confiance à la revendication `sub` : `repo:<propriétaire>/<dépôt>:pull_request`, `…:ref:refs/heads/main`, `…:environment:<env>`. Un job qui déclare `environment:` obtient un `sub` différent : c'est ce qui sépare plan et apply. |
| Environnements GitHub protégés | à vérifier | Les relecteurs obligatoires exigent un dépôt public ou un plan payant ; `dev` n'a pas de relecteur, `staging` et `prod` en ont un. |
| Workflow réutilisable (`workflow_call`) | à vérifier | Un seul fichier `terraform-layer.yml` pour `dev`, `staging` et `prod` ; les secrets sont passés explicitement ; l'`environment` déclaré dans le workflow appelé est bien protégé. |
| Artefact de plan chiffré | nouveau | Sur un dépôt public, un artefact est téléchargeable par tout le monde ; le plan binaire contient l'état complet. Il est donc chiffré (AES-256, clé dans un secret GitHub) avant l'envoi, déchiffré dans le job d'apply. |
| `plan -detailed-exitcode` | à vérifier | 0 = rien, 1 = erreur, 2 = changements. C'est ce qui pilote l'apply conditionnel et la détection de dérive. |
| PR depuis un fork | à vérifier | Pas de secret ni d'OIDC : le plan est explicitement ignoré (`head.repo.full_name == github.repository`). |

## 3. Lecture guidée des workflows

### `ci.yml` — Python, notebooks, dépendances, secrets

Quatre jobs indépendants : `python` (ruff, mypy, pytest avec couverture), `notebooks` (`make notebooks-ci`,
mode `sample`, sans réseau), `audit` (`uv export` du verrou puis `pip-audit`, bloquant), `secrets`
(gitleaks sur tout l'historique). `uv sync --locked` refuse un `uv.lock` désynchronisé.

### `terraform.yml` — statique, plan en PR, apply de `dev`

`static` : `fmt -check`, `validate` de chaque racine avec `init -backend=false`, tflint récursif,
trivy sur la configuration (HIGH et CRITICAL bloquants). `plan-dev` : matrice sur les quatre couches,
via le workflow réutilisable, sans apply. `comment` : un seul commentaire par PR, mis à jour à chaque
run (marqueur HTML), qui renvoie au résumé du run où chaque plan est affiché. Sur `main` : quatre
applies chaînés `foundation → platform → agents → frontend`, chacun conditionné au succès du
précédent, avec l'environnement `dev` (sans relecteur).

### `terraform-layer.yml` — le cœur

Job `plan` : rôle `cgp-<env>-github-plan`, `init -backend-config=backend.hcl`, `plan -out=tfplan
-detailed-exitcode`, plan lisible dans le résumé, artefact chiffré si `apply` est demandé et qu'il y a
des changements. Job `apply` : n'existe que s'il y a des changements, déclare `environment: <env>`
(donc attend l'approbation pour `staging` et `prod`), rôle `cgp-<env>-github-apply`, déchiffre et
applique **le même fichier de plan**. Terraform refuse un plan dont l'état a bougé entre-temps.

### `promote.yml` — `staging`, puis `prod`

Déclenchement manuel, refusé hors de `main`. `staging` d'abord ; `prod` seulement si la cible le
demande et que `staging` a réussi. Chaque étape est un plan, une approbation, un apply.

### `drift.yml` — chaque nuit

Matrice `staging`/`prod` × quatre couches, `plan -lock=false -detailed-exitcode`. Un code 2 fait
échouer le job et ouvre (ou commente) une issue étiquetée `drift` qui renvoie au runbook.

## 4. Vérifier après le bootstrap

```bash
gh variable list                                   # AWS_ACCOUNT_ID_DEV, _STAGING, _PROD
gh secret list                                     # TF_PLAN_ARTIFACT_KEY
gh api repos/christophe17/cgp-ai/environments      # dev, staging, prod ; relecteur sur staging et prod
gh api repos/christophe17/cgp-ai/branches/main/protection | jq '.required_status_checks, .required_pull_request_reviews'
gh workflow run terraform.yml && gh run watch      # plan-dev obtient des credentials sans secret
gh run view <id> --log | grep -A2 'configure-aws-credentials'   # rôle assumé : cgp-dev-github-plan
```

## 5. Coût

GitHub Actions est gratuit pour un dépôt public. Côté AWS, un plan coûte quelques appels d'API (0).

## 6. Pièges

- **L'artefact de plan sur un dépôt public** est lisible par n'importe qui : chiffré ou rien.
- **`-lock=false` dans la dérive**, sinon le plan nocturne bloque un apply en cours ; l'inverse est vrai
  pour tout plan qui précède un apply.
- **`concurrency` sans `cancel-in-progress`** pour Terraform : annuler un apply en vol laisse un état
  incohérent ; on annule les runs de CI Python, pas ceux de Terraform.
- **Le `sub` d'un job avec `environment:` change** : un rôle qui fait confiance à `ref:refs/heads/main`
  seulement refusera l'apply, et l'erreur STS ne dit pas pourquoi.
- **`TF_PLAN_ARTIFACT_KEY`** doit exister avant le premier apply ; sans lui, `openssl` échoue après
  le plan, pas avant.

## 7. Questions d'entretien

1. Que contient un fichier de plan Terraform et pourquoi ne faut-il jamais le publier en clair ?
2. Comment garantir que ce qui est appliqué en `prod` est exactement ce que le relecteur a lu ?
3. Pourquoi épingler une action GitHub par SHA plutôt que par tag ?
4. Que se passe-t-il si un `terraform apply` de `dev` est annulé au milieu, et comment le workflow s'en protège-t-il ?
