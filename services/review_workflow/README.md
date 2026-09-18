# review_workflow — validation conseiller

Step Functions avec task token, relances, expiration si le profil change, SLA ; notifications SES ; décision via le back-office (`docs/05-safety-compliance.md` §3).

## Règles

- Aucune recommandation personnalisée n'atteint l'utilisateur sans validation humaine.

## État

- **Phase 0** : squelette installable (`services/review_workflow`), test de fumée.
- **Implémentation** : phase 6.

## Tests

Intégration : recommandation → validation → publication ; expiration.
