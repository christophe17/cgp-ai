# 06 — Tests, évaluations, mesure, CI/CD, observabilité, rapport de validation

L'argument du portfolio est la **mesure** : chaque technique et chaque décision d'architecture est chiffrée, avec son incertitude, sur des cas de référence rejouables. Ce document définit ce qu'on mesure et comment. Le calendrier est dans `07-roadmap.md`, le matériel d'apprentissage dans `09-learning-method.md`.

## 1. Pyramide de tests

| Niveau | Quoi | Où | Quand |
|---|---|---|---|
| Unitaires | Moteur de calcul, paramètres, schémas, règles de complétude, périmètre, conformité, vérification | `packages/*/tests` | Chaque commit |
| Propriétés | Invariants du moteur de calcul et des validateurs du profil | `packages/calc_engine/tests`, `packages/domain/tests` | Chaque commit |
| Stockage et RAG | Dépôts PostgreSQL, migrations, recherche hybride | `packages/storage/tests`, `packages/legal_rag/tests` (testcontainers) | Chaque commit |
| Pipeline | Enchaînement des étapes avec agents simulés (réponses enregistrées) | `services/agent_runtime/tests` | Chaque commit |
| Notebooks | Exécution en mode `sample` (`nbmake`) | `notebooks/` | Chaque commit |
| Intégration | Lambdas, API, isolation utilisateurs, workflow de validation, suppression RGPD | `services/*/tests` | Chaque PR (env `dev`) |
| Récupération | Qualité du RAG juridique, ablation | `evals/retrieval` | Chaque PR touchant le RAG + hebdomadaire |
| Agents | Comportement de chaque agent contre Bedrock | `evals/agents/<agent>` | Chaque PR touchant prompts, modèles ou outils |
| Conformité | Classification et formulations | `evals/compliance` | Chaque PR touchant la conformité ou les prompts |
| Juge | Accord du juge LLM avec les annotations humaines | `evals/judge` | Chaque changement de rubrique ou de modèle juge |
| Bout en bout | Cas patrimoniaux complets | `evals/golden_cases` | Avant chaque déploiement `staging` et `prod` |
| Sécurité | Attaques fabriquées, accès croisé, PII dans les journaux | `evals/security` | Chaque PR touchant prompts, outils, guardrails |
| Frontend | Composants (Vitest), parcours (Playwright contre `staging`) | `frontend/` | Chaque PR ; parcours avant déploiement |
| Trafic | Rejeu synthétique contre `staging` : charge, coût, dérive, shadow | `evals/traffic` | À la main, phase 8, puis à chaque changement de modèle ou de prompt |
| En ligne | Trafic synthétique échantillonné | AgentCore Evaluations | Continu à partir de la phase 8 |

## 2. Cas de référence (`evals/golden_cases`)

Un fichier YAML par cas :

```yaml
id: succession-couple-2-enfants-av
status: draft                 # reste draft : aucune validation professionnelle n'est prévue
reference_date: 2026-09-20
profile: fixtures/profiles/couple_2_enfants_av.json
question: "Si je décède, combien mes enfants paieront-ils de droits ?"
expected:
  scope: in_scope
  must_ask: []                # informations que la collecte doit demander si absentes
  must_call_tools: [calc.estate_devolution, calc.inheritance_tax, calc.life_insurance_death_tax]
  must_not_call_tools: [profile.propose_update]
  numeric:                    # valeurs attendues, issues des cas unitaires du moteur
    - {calc: inheritance_tax, path: "per_heir[0].tax", case: cases/inheritance_tax/couple_2_enfants.yaml}
  must_cite_references: ["CGI art. 779"]
  classification: recommandation_personnalisee
  mandatory_mentions: [notaire, millesime, informatif]
  forbidden: [promesse_de_rendement, montant_non_source]
```

- Les valeurs numériques attendues renvoient aux cas unitaires du moteur (pas de duplication) ; le golden case vérifie que la réponse de l'agent contient exactement ces valeurs.
- Objectif : **30 cas** sur le vertical transmission — célibataire, couple marié sous chaque régime, pacsés, familles recomposées, enfant prédécédé avec descendants, donations antérieures dans et hors délai de rappel, assurance-vie avant/après 70 ans, démembrement, cas hors périmètre, cas de collecte incomplète, tentative d'injection dans un message ou un passage.
- Taxonomie étiquetée sur chaque cas (`kind`: factuel, calcul, multi-domaines, hors périmètre, collecte, piège, temporel) pour lire les résultats par famille.
- Construction : génération assistée puis **revue humaine intégrale** via une CLI (`cgp eval review`), versionnement avec `CHANGELOG.md` dans `evals/`.

## 3. Métriques

Déterministes (prioritaires) :
- Exactitude numérique : tout montant de la réponse ∈ résultats `calc.*` de la session ou profil.
- Couverture des sources : proportion d'affirmations réglementaires avec `SourceRef` vérifié.
- Usage des outils : outils attendus appelés, outils interdits jamais appelés.
- Complétude : questions bloquantes posées quand l'information manque, jamais posées quand elle est présente.
- Périmètre : redirection sur les cas hors périmètre, jamais sur les cas dans le périmètre.
- Conformité : classification, mentions, formulations interdites.
- Taux de rejet de la vérification déterministe et du vérificateur, nombre d'itérations.

LLM-as-judge (secondaires, admis dans un gate seulement une fois calibré, §7) : clarté pour un non-spécialiste, pertinence des options, fidélité au profil.

Opérationnelles : latence p50/p95/p99 par étape et par question, TTFT, tokens et coût par question et par agent, taux d'erreur des outils.

Retrieval (`evals/retrieval`) : rappel@5, rappel@10, MRR, par famille de question.

## 4. Stabilité et intervalles de confiance

Les sorties LLM ne sont pas reproductibles. Chaque cas est exécuté **N fois** (N = 3 dans la CI, N = 10 pour les chiffres publiés) et chaque métrique agrégée est publiée **avec un intervalle de confiance à 95 % par bootstrap** sur les cas et les exécutions. Règles :

- critères déterministes : réussite exigée sur toutes les exécutions ;
- critères du juge : majorité, et l'intervalle est affiché ;
- **aucune conclusion sur une seule exécution** : une comparaison entre deux versions (prompt, modèle, configuration de retrieval) n'est retenue que si les intervalles ne se recouvrent pas ; sinon le résultat est publié comme « non significatif », ce qui est un résultat ;
- le coût de la suite d'évals est mesuré et affiché dans le rapport ;
- un `seed` n'existe pas côté Bedrock : la reproductibilité passe par l'enregistrement des réponses (`evals/cassettes/`) pour les tests, et par la date et l'identifiant exact du modèle pour les chiffres publiés.

## 5. Seuils de déploiement (quality gates)

- Moteur de calcul : 100 % des cas unitaires passent ; couverture ≥ 95 %.
- Golden cases : 100 % d'exactitude numérique, 100 % de périmètre et de classification, ≥ 95 % sur les autres critères déterministes, aucune régression par rapport à la version déployée **au-delà de l'intervalle**.
- Récupération : seuils de `evals/retrieval/thresholds.yaml`, fixés à partir de la configuration retenue par l'ablation (§9).
- Conformité : 100 % sur `evals/compliance`.
- Sécurité : 100 % de blocage sur `evals/security` pour les attaques marquées `must_block`.
- Tout changement de modèle, de prompt, de règle ou de millésime déclenche la suite complète.

## 6. Exécuteur commun, historique et rapport

- Un **seul exécuteur** (`evals/runners/`) pour `evals/agents`, `evals/compliance`, `evals/golden_cases`, `evals/security` : chargement des cas, N exécutions, contrôles déterministes, juge, agrégation et bootstrap, comparaison à la version de référence. Les familles de cas sont des données, pas des runners différents.
- Chaque run enregistre en base (`eval_runs`, `eval_results`) : date, commit, versions des prompts, identifiants de modèles, `engine_version`, `params_hash`, hash du corpus, coût, durée. Chaque chiffre publié est reliable au run qui l'a produit.
- `make eval` produit un **rapport HTML comparatif** (run courant contre référence, par famille de cas, intervalles, coût) ; artefact de CI, consultable dans le back-office.
- La GitHub Action **bloque la PR** sur régression au-delà de l'intervalle ; le rapport est joint au commentaire de PR.
- Le mode `sample` (cassettes, sous-ensemble de cas) tourne à chaque commit ; les runs complets contre Bedrock sont lancés à la main ou par les jobs planifiés, et archivés.

## 7. Juge LLM calibré (`evals/judge`)

Un juge non calibré est un générateur de nombres rassurants. Avant d'entrer dans un gate :

1. **Rubriques explicites** par critère (clarté, pertinence, fidélité) : notation discrète (0/1/2) avec description de chaque niveau ; justificatif demandé **avant** la note ; modèle juge **différent** du modèle générateur.
2. **Annotation humaine** : 40 sorties (20 réponses complètes, 20 findings) annotées par moi via `cgp eval annotate`, stockées dans `evals/judge/human/`.
3. **Accord mesuré** : kappa de Cohen par critère entre le juge et l'annotation humaine ; seuil d'admission dans un gate : κ ≥ 0,6 ; en dessous, le critère est publié comme indicatif seulement.
4. **Biais neutralisés et documentés** : position (ordre des candidats permuté), verbosité (longueur contrôlée dans la rubrique), auto-préférence (modèle juge différent), format (sorties normalisées avant jugement).
5. Toute modification de rubrique ou de modèle juge rejoue la calibration.

## 8. Rapport de validation

`make validation-report` génère `reports/validation.md` (artefact de CI, aussi consultable dans le back-office) qui liste, par catégorie, tout ce qui attendrait une validation professionnelle :

- paramètres (`status ≠ validated`) avec source et date de consultation ;
- cas unitaires du moteur et golden cases en `draft` ;
- règles de conformité, formulations interdites, mentions, gabarits en `draft` ;
- prompts avec `reviewed_by: null` ;
- points **[À VALIDER]** de `docs/`.

**Aucune validation professionnelle n'est prévue** : tout reste `draft`, et le rapport le montre. Il est conservé parce qu'il démontre comment une relecture se brancherait et parce que le mode démonstration s'en sert pour afficher le statut de chaque contenu.

Boucle de correction (jouée par le conseiller de démonstration) :
1. Le conseiller corrige ou rejette une recommandation dans le back-office.
2. La correction crée un brouillon de golden case (profil fictif, question, sortie attendue) dans `evals/golden_cases/inbox/`.
3. Analyse : collecte, périmètre, récupération, raisonnement, calcul ou paramètre.
4. Correctif + cas ajouté → la régression est couverte.

## 9. Ablation du retrieval (`evals/retrieval/ablation`)

Chaque technique de retrieval est derrière une configuration et mesurée sur les 50 questions, N exécutions, intervalles bootstrap :

| Bras | Configuration |
|---|---|
| A | plein texte seul (`tsvector` français) |
| B | dense seul (embeddings Bedrock, HNSW) |
| C | hybride, fusion par rang réciproque |
| D | C + reranker (modèle de reranking disponible sur Bedrock, sinon cross-encoder local dans la Lambda ; choix documenté) |
| E | D + filtrage temporel (la configuration de production) |

Tableau publié : rappel@5, rappel@10, MRR par bras, latence p95 de `legal.search`, coût par requête. **Un bras dont le gain n'est pas significatif est retiré de la configuration de production et le retrait est documenté.** Le notebook `03` montre les passages renvoyés par chaque bras sur une même question, dont un cas où le plein texte bat le dense (référence d'article exacte, sigle) et un cas inverse.

## 10. Trafic synthétique, coût et dérive (`evals/traffic`)

Il n'y a pas d'utilisateurs. Tout ce qui suppose de la production se mesure sur un **générateur de trafic** qui rejoue les golden cases et les cas d'agents contre `staging` selon des profils configurables : débit, rafales, mélange de familles de questions, part de questions hors périmètre, part de collecte incomplète, et **dérive de la distribution dans le temps** (montée progressive d'une famille, apparition de questions hors vertical).

Mesures :
- p50/p95/p99 et TTFT par étape sous chaque profil ; limites de concurrence atteintes (Lambda, AgentCore, Bedrock, Aurora) ;
- coût par question par profil, **extrapolé au mois** pour deux volumes cibles (proposés par Claude Code, arbitrés par moi) ; part de chaque agent dans le coût ;
- **dérive** : détecteur sur la distribution des familles de questions et des classifications, et sur les évals en ligne ; une dérive contrôlée est injectée depuis le générateur et le **nombre de requêtes avant déclenchement** est publié ;
- budgets, alertes et kill switch déclenchés en conditions réelles pendant le test.

Ce que la simulation **ne capture pas**, écrit dans le README : le comportement adversarial ou hors distribution de vrais utilisateurs, la saisonnalité, le feedback humain authentique.

## 11. Évaluation shadow d'un changement

Avant tout changement de prompt, de modèle ou de configuration de retrieval en `staging` :

1. la nouvelle version tourne **en shadow** : même trafic (golden set complet + un profil de trafic), réponses enregistrées, jamais servies ;
2. tableau des écarts par famille de cas : métriques déterministes, juge calibré, coût, latence, avec intervalles ;
3. décision go/no-go documentée dans `JOURNAL.md` ; go seulement si aucune régression significative ;
4. rollback de prompt à chaud (registre de versions en configuration, paramètre SSM), sans redéploiement ; testé.

Le cas obligatoire de la phase 8 : un changement de modèle du niveau `capable`. C'est la répétition du runbook « le fournisseur a changé le modèle en silence ».

## 12. Sécurité mesurée (`evals/security`)

Les attaques sont **fabriquées, jouées, puis contrées, puis rejouées**, et le taux de blocage est publié à chaque étape de contrôle (schéma de sortie, vérification déterministe, liste d'outils fermée, Guardrails en entrée, Guardrails en sortie) :

- injection par le message utilisateur (instructions, changement de rôle, demande de titre nominatif) ;
- injection par un **passage du RAG empoisonné** (corpus de test uniquement) ;
- injection par un document ou une réponse d'outil empoisonnés (fixtures) ;
- tentative de faire écrire le profil sans confirmation ;
- tentative d'exfiltration d'un montant du profil dans une réponse d'attente ou par les citations ;
- tentative d'accès croisé (`user_id` d'un autre utilisateur via le LLM et via l'API) ;
- PII fictives injectées et recherchées dans les journaux et les spans.

Chaque attaque a un `must_block: true|false` et le gate exige 100 % sur les `must_block`. Le notebook `09` montre une attaque qui passe avant le contrôle et échoue après.

## 13. Comparaison de modèles et de backends d'outils

Sur le golden set, N exécutions, intervalles : deux ou trois modèles disponibles dans la région pour chaque niveau (`capable`, `fast`), **dont un modèle non-Claude si Bedrock en propose un dans la région** (à vérifier en phase 0). Axes : métriques déterministes, juge calibré, coût par question, latence p95, taux de sorties structurées invalides. Décision par niveau documentée ; le cas attendu et à vérifier : le niveau `fast` suffit pour `collector`, `classifier`, `educator`, et l'écart de coût est de l'ordre de grandeur, pas du pourcentage.

**Backends d'outils** : les mêmes Lambdas appelées en direct (`LambdaToolInvoker`) et via AgentCore Gateway en MCP (`GatewayToolInvoker`), sur le golden set et sur un profil de trafic : latence p95 par appel d'outil et par question, coût par question (la passerelle a son propre tarif), taux d'erreur et de timeout, résultat du test d'accès croisé et de propagation d'identité sur les deux. Décision par environnement documentée ; si Gateway ne peut pas propager les claims validés (`01-architecture.md` §5), la ligne le dit et le backend est restreint aux outils sans donnée utilisateur.

## 14. CI/CD

- GitHub Actions, authentification OIDC vers AWS : un rôle par compte, aucune clé statique.
- Pipeline applicatif : lint + types → tests unitaires, propriétés, stockage (testcontainers), notebooks `sample` → build des images (Lambdas, runtime) avec scan de vulnérabilités et SBOM → déploiement `dev` → migrations → intégration + évals agents, conformité et sécurité (`sample`) → déploiement `staging` → migrations → golden cases + parcours Playwright → approbation manuelle (environnement GitHub protégé) → `prod`.
- Pipeline infrastructure : `terraform fmt -check` → `validate` → tflint → trivy (config) → `plan` publié en commentaire de PR → `apply` automatique en `dev` à la fusion → `apply` en `staging` puis `prod` après approbation, en appliquant l'artefact de plan relu. Détection de dérive nocturne sur `staging` et `prod` avec alarme.
- Prompts, configuration des modèles, paramètres et règles sont déployés comme du code ; la version de chaque artefact est enregistrée dans chaque trace et dans chaque run d'éval.
- Rollback : image et modules Terraform précédents, exécuté en `staging` à chaque release, documenté.
- Aucun contournement des gates sans ticket et approbation.

## 15. Observabilité

- OpenTelemetry (Strands + AgentCore Observability) → CloudWatch, X-Ray.
- Attributs de span : `session_id`, `trace_id`, `step`, `agent`, `prompt_version`, `model_id`, `engine_version`, `params_millesime`, `params_hash`, `profile_version`, `calc_call_ids`, tokens, coût ; **jamais de PII ni de contenu**.
- Dashboards versionnés en JSON : qualité (évals en ligne, rejets), coûts (par question, par agent, par jour), latence (par étape, TTFT), file de validation (volume, délai), erreurs d'outils, usage des quotas, dérive.
- Alarmes reliées à l'astreinte, chacune avec un runbook : taux de rejet en hausse, erreurs d'outils, `ParamNotAvailable` ou `ParamNotValidated`, dérive des évals en ligne, budget, DLQ non vide, throttling Bedrock, latence p95, file de validation au-delà du SLA.
- Trois runbooks obligatoires, joués pendant la phase 8 : **le fournisseur est indisponible** ; **la qualité s'est dégradée sans changement de code** ; **les coûts ont triplé dans la nuit**.
- Échantillonnage des évals en ligne : 10 % au départ.

## 16. Journal des incidents

`JOURNAL.md` reçoit, au fil de l'eau, chaque incident de construction et d'exploitation : ce qui s'est passé, le diagnostic, le correctif, la leçon. Sources attendues : une régression attrapée par le gate, une dérive de coût, un juge mal calibré, une cassette périmée, une restauration plus lente que le RTO, une ressource AgentCore non couverte par Terraform. Le README de la phase 9 en extrait « ce qui a cassé », et trois histoires au format situation-action-résultat chiffré en sortent pour les entretiens.
