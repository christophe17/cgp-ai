# ingestion — corpus juridique

Step Functions + Lambdas : téléchargement des sources open data (DILA, BOFiP), normalisation, embeddings, indexation pgvector, planification hebdomadaire, détection des changements par hash, rapport de différences.

## Règles

- Versions antérieures conservées avec `valid_to`.

## État

- **Phase 0** : squelette installable (`services/ingestion`), test de fumée.
- **Implémentation** : phase 4.

## Tests

Intégration en `dev` sur un sous-ensemble du corpus.
