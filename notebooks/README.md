# Notebooks d'apprentissage

Contrat dans `docs/09-learning-method.md` §2 : un notebook n'implémente rien, il importe et exécute le
code réel du dépôt. Deux modes, pilotés par `CGP_NB_MODE` :

- `sample` (CI, `make notebooks-ci`) : outils en processus, PostgreSQL local, réponses Bedrock
  enregistrées dans `cassettes/`, aucun appel réseau ;
- `full` (`make notebooks-full`, compte `dev`) : vrais appels ; chiffres archivés dans `results/<date>/`.

| # | Notebook | Phase |
|---|---|---|
| 00 | `00_visite_guidee.ipynb` | 0 |
| 01 | `01_calcul_deterministe.ipynb` | 2 |
| 02 | `02_anatomie_d_un_outil.ipynb` | 3 |
| 03 | `03_du_texte_de_loi_au_passage.ipynb` | 4 |
| 04 à 06, 12 | pipeline, harness, trace, Gateway ou Lambda | 5 |
| 07 | `07_validation_et_audit.ipynb` | 6 |
| 08 à 10 | trafic et dérive, sécurité mesurée, choix d'un modèle | 8 |
| 11 | `11_l_agent_est_la_mauvaise_reponse.ipynb` (optionnel) | 9 |
