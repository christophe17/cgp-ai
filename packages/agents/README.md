# cgp-agents — agents Strands

Un agent Strands par étape LLM (`planner`, `collector`, `estate`, `consolidator`, `verifier`, `classifier`, `educator`), prompts versionnés dans `prompts/<agent>/vN.md` avec en-tête `reviewed_by`, schémas de sortie Pydantic, listes d'outils fermées, configuration des modèles dans `config/models.yaml` (`docs/03-agents.md`).

## Règles

- Les prompts ne contiennent aucune valeur réglementaire.
- Les schémas d'outils exposés au LLM ne contiennent ni `user_id` ni `session_id`.
- Les identifiants de modèles viennent de la configuration, jamais du code.

## État

- **Phase 0** : squelette installable (`packages/agents`), test de fumée.
- **Implémentation** : phase 5.

## Tests

Test d'exposition des outils par agent ; `evals/agents/<agent>/` (≥ 5 cas par agent).
