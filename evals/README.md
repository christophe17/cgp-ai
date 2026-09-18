# Évaluations

Suite d'évaluations spécifiée dans `docs/06-evals-mlops.md`. Un seul exécuteur (`runners/`, phase 5)
pour `agents/`, `compliance/`, `golden_cases/` et `security/` ; les familles de cas sont des données.

| Dossier | Contenu | Phase |
|---|---|---|
| `golden_cases/` | cas patrimoniaux de bout en bout (YAML), `inbox/` pour les brouillons issus des corrections du conseiller | 8 |
| `agents/<agent>/` | au moins 5 cas par agent | 5 |
| `retrieval/` | 50 questions de transmission, seuils, `ablation/` | 4 |
| `compliance/` | au moins 40 sorties étiquetées | 5 |
| `judge/` | rubriques, annotations humaines (`human/`), calibration | 5 |
| `security/` | attaques fabriquées, `must_block` | 8 |
| `traffic/` | générateur de trafic, profils, dérive, shadow | 8 |
| `cassettes/` | réponses Bedrock enregistrées (mode `sample`) | 5 |
| `runners/` | exécuteur commun, bootstrap, rapport HTML | 5 |

Le `CHANGELOG.md` de ce dossier trace chaque ajout ou modification de cas.
