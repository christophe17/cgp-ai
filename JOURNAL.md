# JOURNAL — historique daté

Une entrée par session de travail : contexte, fait, **incidents et surprises**, suite. Les incidents
sont notés au fil de l'eau ; ils nourrissent « ce qui a cassé » du README et les histoires d'entretien.

## 2026-09-18 — Phase 0 : socle du dépôt

**Contexte.** Démarrage à blanc : `CLAUDE.md` et `docs/` seuls, pas de dépôt git, un compte AWS
personnel (749020018778, alias `aws-kiwix-christophe`) sans organisation. Plan d'une page validé sur
quatre points : compte de gestion = compte existant, e-mails des comptes membres en adressage `+`,
budgets 60/120/40 € par mois, dépôt public `christophe17/cgp-ai`.

**Fait.** Vérification régionale (AgentCore complet en `eu-central-1`, Claude Opus 5 et Sonnet 5 en
profils UE, Nova et Mistral comme non-Claude, embeddings Cohere, reranker) ; couverture Terraform
d'AgentCore par `hashicorp/aws` v6.65 ; Policy in AgentCore retenu. Monorepo `uv`, CLI `cgp`,
squelettes, qualité, Makefile, compose, pre-commit, Terraform global et squelette complet, workflows
GitHub, notebook 00, guides 00 et 10, carte des compétences, runbooks, `STATE.md`.

**Incidents et surprises.**

- *Compte de gestion sans garde-fou.* L'utilisateur IAM `christophe` est administrateur, sans MFA,
  avec des clés statiques dans `~/.aws/credentials`, région par défaut `eu-west-3`. Les SCP ne
  s'appliqueront jamais à ce compte : la seule protection est le passage à Identity Center + MFA et la
  suppression des clés, placés en tête du guide 00. Un runtime AgentCore d'essai
  (`travel_companion_basic`) existe en `eu-west-3` ; il n'est pas touché.
- *`ruff format` a réécrit la spécification.* Le formateur traite les blocs Python des fichiers
  Markdown : `docs/02` et `docs/04` ont été reformatés (commentaires déplacés, lignes coupées). Les
  quatre blocs ont été restaurés à l'identique depuis le texte d'origine, et `docs/` puis `*.md` sont
  exclus de ruff. Leçon : exclure la documentation des formateurs avant le premier `format`.
- *`uv sync` n'installe pas les membres du workspace non déclarés.* Les 14 tests d'import échouaient ;
  la racine `cgp` dépend maintenant explicitement de chaque package, ce qui est aussi vrai
  fonctionnellement (la CLI orchestre tout).
- *zsh ne découpe pas `$liste` dans `for`.* Le premier générateur de `pyproject.toml` a produit une
  dépendance unique « cgp-domain calc-engine params … ». Corrigé par une boucle explicite.
- *Homebrew ne résout pas `tflint`* sur ce poste (renvoie vers un cask sans rapport, même après
  `brew update`). Installé depuis la release GitHub v0.64.0 avec vérification du checksum SHA-256.
- *Un backend S3 partiel exige `init` même pour un plan.* Le bootstrap de `infra/global/organization`
  passe par un `backend_override.tf` local (ignoré par git), puis `init -migrate-state`.
- *Dépôt public et artefacts de plan.* Un artefact GitHub est téléchargeable par quiconque sur un dépôt
  public, et un plan binaire contient l'état. Décision : chiffrement AES-256 de l'artefact avec un
  secret de dépôt (`TF_PLAN_ARTIFACT_KEY`), déchiffré dans le job d'apply.
- *Adresses e-mail racine des comptes.* Elles ne doivent pas figurer dans un dépôt public :
  `infra/global/**/terraform.tfvars` est ignoré par git, un `.example` porte des valeurs fictives.
- *Chaîne d'applies `dev` perméable.* Au premier run sur `main`, `apply-dev-agents` a démarré alors
  que `apply-dev-platform` avait été sauté : la condition `result != 'failure'` laisse passer `skipped`.
  Corrigé par `result == 'success'` (un run réutilisable dont l'apply est sauté faute de changement
  conclut quand même `success`). Leçon : en chaîne de déploiement, exiger le succès, pas l'absence d'échec.
- *SES en sandbox* en `eu-central-1` : 200 envois/jour vers des destinataires vérifiés. Sortie de
  sandbox à demander en phase 6, avant la validation conseiller.

**Suite.** Bootstrap AWS par l'auteur (guide 00 §4, cinq étapes), puis apply des racines `global`,
report des identifiants, premier run GitHub, acceptation de la phase 0.
