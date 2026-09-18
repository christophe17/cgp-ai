# cgp-compliance — conformité déterministe

Classification `information_generale` / `recommandation_personnalisee`, formulations interdites, mentions obligatoires, règles de périmètre et gabarits réglementaires (`docs/05-safety-compliance.md`). Les règles sont des données YAML sous `rules/`, toutes en statut `draft`.

## Règles

- Une sortie est personnalisée dès que les règles **ou** le classifieur LLM le disent.
- Les mentions obligatoires sont ajoutées par le code, jamais par le LLM.
- Hors périmètre : redirection sans analyse.

## État

- **Phase 0** : squelette installable (`packages/compliance`), test de fumée.
- **Implémentation** : phase 1 (périmètre) puis phase 5 (classification, formulations, mentions, gabarits).

## Tests

Unitaires sur chaque règle ; `evals/compliance/` (≥ 40 sorties étiquetées) ; mypy strict.
