## Objet

<!-- Une fonctionnalité par PR, commit conventionnel (feat:, fix:, chore:, docs:, ci:, infra…). -->

## Definition of Done (`docs/07-roadmap.md`)

- [ ] Code typé (mypy strict), testé, ruff vert
- [ ] Infrastructure en Terraform, `plan` joint en commentaire, aucune ressource créée à la main
- [ ] Journaux structurés sans PII ; métriques et alarmes utiles
- [ ] Documentation à jour (`docs/`, README du module, runbook si exploité)
- [ ] Contenu métier avec statut de validation, visible dans `make validation-report`
- [ ] Matériel d'apprentissage livré (notebook en mode `sample`, guide relu avec le `plan`)
- [ ] `STATE.md` et `JOURNAL.md` à jour
