# cgp-calc-engine — moteur de calcul déterministe

Python pur, **aucune dépendance AWS ni LLM**, `Decimal` partout. Chaque fonction prend des objets du domaine, un jeu de paramètres résolu par millésime et une date de référence, et renvoie un `CalcResult` avec le raisonnement pas à pas (`docs/04-tools-and-data.md` §1).

## Règles

- Aucun calcul financier ou fiscal par le LLM : tout montant sort d'ici.
- Aucun littéral réglementaire dans le code (test AST) : les valeurs viennent de `cgp-params`.
- Docstring par fonction : référence légale, date qui fait foi, hypothèses, arrondis.
- Chaque entrée issue du profil est annotée de son chemin JSON Pointer (`inputs_origin`).

## État

- **Phase 0** : squelette installable (`packages/calc_engine`), test de fumée.
- **Implémentation** : phase 2 (`estate_devolution`, `inheritance_tax`, `gift_tax`, `dismemberment_value`, `life_insurance_death_tax`, `replay`).

## Tests

Cas unitaires YAML chiffrés avec `expected_source`, tests de propriété, couverture ≥ 95 %.
