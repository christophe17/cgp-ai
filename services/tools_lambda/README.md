# tools_lambda — Lambdas d'outils

Handlers minces pour les familles `profile`, `calc`, `legal`, `usage` (`documents` différé) ; la logique vit dans les packages. Contrat `ToolRequest` / `ToolResponse` de `docs/04-tools-and-data.md` §5.

## Règles

- Appelants autorisés par IAM uniquement ; `user_id` lu dans le contexte, jamais dans les arguments.
- Timeouts, retries, DLQ, idempotence sur les écritures, journaux structurés sans PII.

## État

- **Phase 0** : squelette installable (`services/tools_lambda`), test de fumée.
- **Implémentation** : phase 3 (`profile`, `calc`, `usage`) puis phase 4 (`legal`).

## Tests

Intégration en `dev` : mêmes tests via `LocalToolInvoker` et `LambdaToolInvoker`, accès croisé refusé.
