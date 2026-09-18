# cgp-verification — contrôles déterministes des sorties

Les six contrôles de `docs/03-agents.md` §9 : montants issus d'un calcul, références de calcul journalisées, sources confirmées par hash, faits existants dans le profil, entrées de calcul cohérentes avec le profil, aucune formulation interdite.

## Règles

- Un échec renvoie le finding au spécialiste (au plus 2 itérations), puis l'écarte.
- Rejoué sur le résumé consolidé.

## État

- **Phase 0** : squelette installable (`packages/verification`), test de fumée.
- **Implémentation** : phase 5.

## Tests

Unitaires : chaque contrôle rejette un finding volontairement corrompu ; mypy strict.
