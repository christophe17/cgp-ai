# cgp-params — référentiel de paramètres réglementaires

Barèmes, abattements, plafonds et taux, en YAML embarqués et versionnés par millésime (`docs/04-tools-and-data.md` §2). Chaque valeur porte sa source officielle, sa date de consultation et son statut `TODO_SOURCE | draft | validated`.

## Règles

- Aucune valeur de mémoire : recopiée depuis Légifrance, BOFiP, impots.gouv.fr ou service-public.fr.
- `ParamNotAvailable` si `TODO_SOURCE` ou millésime absent ; `ParamNotValidated` en `prod` si `draft`.
- Le hash du jeu de paramètres figure dans chaque `CalcResult`.

## État

- **Phase 0** : squelette installable (`packages/params`), test de fumée.
- **Implémentation** : phase 1 (chargeur, `params.get`, `params diff`, liste « transmission »).

## Tests

Unitaires sur le chargeur et la résolution de millésime ; mypy strict.
