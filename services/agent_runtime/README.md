# agent_runtime — conteneur AgentCore Runtime

Point d'entrée du runtime, pipeline en code (`pipeline.py`, 16 étapes de `docs/03-agents.md` §2), budgets, itérations, réponses prudentes, streaming. Image ARM64 construite par la CI.

## Règles

- Le contrôle du flux est du code ; les agents sont des étapes appelées.
- `ToolContext` construit à partir du JWT validé, jamais fourni par le LLM.

## État

- **Phase 0** : squelette installable (`services/agent_runtime`), test de fumée.
- **Implémentation** : phase 5.

## Tests

Tests du pipeline avec agents simulés (réponses enregistrées).
