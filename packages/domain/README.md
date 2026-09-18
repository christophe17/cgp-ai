# cgp-domain — profil patrimonial

Modèles Pydantic v2 du profil patrimonial (`docs/02-domain-model.md` §2), validateurs, règles de complétude (§3) et migration de schéma du profil. Le profil structuré est **la source de vérité** : les agents le lisent via un outil typé et ne l'écrivent jamais.

## Règles

- Montants en `Decimal` avec devise, jamais de `float`.
- Un champ absent vaut `None` (« non renseigné »), distinct de zéro.
- Aucune valeur dérivée (âge, parts fiscales) stockée dans le profil : c'est le moteur qui calcule.
- Chaque objet factuel porte une provenance.

## État

- **Phase 0** : squelette installable (`packages/domain`), test de fumée.
- **Implémentation** : phase 1 (schéma complet, validateurs, complétude du vertical transmission, fixtures).

## Tests

Unitaires et propriétés (hypothesis) sur les validateurs ; mypy strict.
