# cgp-ai — conseil patrimonial multi-agents (vertical transmission)

Portfolio en production : un système multi-agents déployé sur AWS (Amazon Bedrock + AgentCore),
avec calculs déterministes, sources juridiques datées et validation humaine, réduit à un seul
vertical (succession, donation, assurance-vie au décès, démembrement) et à une infrastructure
complète sur trois comptes. Aucune ouverture à de vrais clients : le mode démonstration est l'état
final, et tout contenu métier reste `draft`.

- La spécification vit dans [`docs/`](docs/) ; l'ordre de lecture est dans [`CLAUDE.md`](CLAUDE.md).
- L'état courant est dans [`STATE.md`](STATE.md), l'historique dans [`JOURNAL.md`](JOURNAL.md).
- Le matériel d'apprentissage est dans [`notebooks/`](notebooks/) et [`docs/infra/`](docs/infra/).

## Démarrer

```bash
make install        # uv sync --locked + hooks pre-commit
make lint test      # ruff, mypy, pytest
make notebooks-ci   # notebooks en mode sample, sans réseau
make tf-check       # fmt, validate, tflint, trivy sur infra/
```

Ce README sera remplacé en phase 9 par la version portfolio (tableau des chiffres mesurés).
