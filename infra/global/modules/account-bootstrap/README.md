# Module `account-bootstrap`

Bootstrap d'un compte membre (`dev`, `staging`, `prod`), exécuté **une seule fois** depuis le compte
de gestion en assumant `OrganizationAccountAccessRole` (exception de bootstrap documentée dans
`docs/infra/00-bootstrap.md`). Crée :

- le bucket d'état et sa clé KMS (module `tfstate`) ;
- le fournisseur OIDC GitHub et deux rôles : `<projet>-<env>-github-plan` (lecture seule, sujets
  `pull_request` et `ref:refs/heads/main`) et `<projet>-<env>-github-apply` (administrateur, sujet
  `environment:<env>`, donc uniquement derrière l'environnement GitHub protégé) ;
- le budget mensuel du compte (module `budget`).

Le rôle d'apply est administrateur : c'est le compromis habituel pour un rôle qui gère toute
l'infrastructure d'un compte ; les SCP de l'organisation et la confiance OIDC limitée à
l'environnement protégé en bornent l'usage. Le rôle de plan refuse explicitement de lire le contenu
d'un objet S3 hors du bucket d'état.
