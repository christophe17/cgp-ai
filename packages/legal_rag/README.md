# cgp-legal-rag — corpus juridique

Découpage par article (codes) ou par paragraphe numéroté (BOFiP), métadonnées temporelles, embeddings Bedrock, recherche hybride (vectorielle + plein texte, fusion par rang réciproque) filtrée par date (`docs/04-tools-and-data.md` §3).

## Règles

- Aucune découpe à taille fixe ; la hiérarchie du texte est conservée.
- `legal.get_passage` rejette un hash de passage incorrect.
- Chaque technique de retrieval est derrière une configuration et mesurée (ablation, `docs/06` §9).

## État

- **Phase 0** : squelette installable (`packages/legal_rag`), test de fumée.
- **Implémentation** : phase 4.

## Tests

testcontainers ; `evals/retrieval/` (rappel@5, rappel@10, MRR) avec intervalles.
