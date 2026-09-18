# profile_api — API profil

API HTTP (API Gateway + Lambda) pour le frontend et le back-office : profil et versions, `confirm_update`, conversations, recommandations, export, suppression ; routes conseiller protégées par le groupe `advisors`.

## Règles

- `user_id` pris dans le JWT validé par l'autorisateur, jamais dans la requête.
- Chaque consultation de dossier par un conseiller est journalisée.

## État

- **Phase 0** : squelette installable (`services/profile_api`), test de fumée.
- **Implémentation** : phase 5 (minimale) puis phase 6.

## Tests

Intégration : refus d'un utilisateur sans le groupe `advisors`.
