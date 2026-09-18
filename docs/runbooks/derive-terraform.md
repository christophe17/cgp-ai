# Runbook — dérive Terraform détectée

**Déclencheur** : le workflow `drift.yml` (chaque nuit, ou à la main) ouvre ou commente une issue
« Dérive Terraform : `<env>/<couche>` » quand `terraform plan -detailed-exitcode` renvoie 2 sur
`staging` ou `prod`.

## Procédure

1. Lire le plan dans le résumé du run lié dans l'issue. Identifier chaque ressource en écart.
2. Qualifier l'origine :
   - **modification manuelle** (console, CLI) : chercher l'auteur dans CloudTrail
     (`aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=<nom>`),
     vérifier qu'une entrée break-glass existe dans `JOURNAL.md` ; sinon, incident de sécurité ;
   - **changement côté AWS** (valeur par défaut, dépréciation) : le plan montre un attribut que le
     HCL ne fixe pas ;
   - **ressource créée hors Terraform** : à importer (`import` dans le HCL) ou à détruire.
3. Corriger **par PR** : jamais dans la console. Selon le cas, aligner le HCL sur l'état voulu, ajouter
   un bloc `import`, ou laisser l'apply de promotion remettre la ressource en conformité.
4. Promouvoir la correction (`promote.yml`), puis relancer `drift.yml` à la main et vérifier le vert.
5. Fermer l'issue avec la cause et le correctif ; consigner dans `JOURNAL.md`.

## Ce qu'on ne fait pas

- `terraform apply -refresh-only` pour « accepter » silencieusement une dérive sans comprendre sa cause.
- Un `apply` local vers `staging` ou `prod` : seuls la CI et la procédure break-glass y écrivent.
