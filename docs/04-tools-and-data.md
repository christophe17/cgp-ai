# 04 — Outils et données : moteur de calcul, paramètres, RAG juridique, documents

> **Périmètre (2026-09-18)** : un seul vertical est construit — la transmission, spécialiste `estate`. L'agent `tax`, l'agent `extractor`, la Lambda `documents` et tout ce qui est marqué V2+ sont spécifiés ici mais **différés** (`07-roadmap.md`, « Périmètre »). L'infrastructure, elle, est construite en entier.

## 1. Moteur de calcul (`packages/calc_engine`)

### Principes

- Python pur, **aucune dépendance AWS ni LLM**, entièrement déterministe.
- `Decimal` partout, règles d'arrondi explicites et documentées par fonction (arrondi à l'euro le plus proche par défaut, sauf disposition légale contraire indiquée dans la docstring).
- Chaque fonction prend des objets du domaine, un objet `Params` (millésime résolu) et une date de référence, et renvoie un `CalcResult` **avec le raisonnement pas à pas** pour que l'utilisateur et la vérification puissent le suivre.
- Chaque fonction a une docstring : référence légale, date qui fait foi (année des revenus, date du décès, date de la donation), hypothèses simplificatrices, règles d'arrondi.
- Chaque valeur d'entrée issue du profil est annotée de son chemin JSON Pointer (`inputs_origin`), pour la vérification déterministe.
- Exposé par la Lambda `calc` (§5). Chaque appel est journalisé dans `calc_calls` avec entrées, sorties, millésime, hash des paramètres et version du moteur.

### Interface

```python
class CalcStep(BaseModel):
    label: str
    formula: str            # ex. "min(base, plafond) × taux"
    value: Decimal

class CalcResult(BaseModel):
    call_id: str
    function: str
    engine_version: str     # version du package calc_engine
    params_millesime: int
    params_hash: str        # hash du jeu de paramètres utilisé
    reference_date: date
    inputs: dict
    inputs_origin: dict[str, str]   # nom d'entrée → chemin dans le profil, quand applicable
    steps: list[CalcStep]
    result: dict
    warnings: list[str]     # ex. "paramètre income_tax.brackets en statut draft"
```

### `replay`

`calc.replay(call_id)` recharge l'appel journalisé, réexécute la fonction avec les mêmes entrées, le même millésime et la version courante du moteur, et renvoie `{identical: bool, differences: [...], original_engine_version, current_engine_version}`. Le journal reste la référence : un écart dû à une version différente du moteur est signalé, pas corrigé.

### Fonctions

| Priorité | Fonction | Description |
|---|---|---|
| Différé | `tax_shares` | Nombre de parts fiscales du foyer |
| Différé | `income_tax` | IR au barème progressif, quotient familial et plafonnement, décote, prélèvements sociaux sur revenus du capital simples |
| Différé | `per_deduction_ceiling` | Plafond de déduction PER |
| V1 | `estate_devolution` | Dévolution légale : conjoint, descendants avec représentation, ascendants ; réserve et quotité disponible ; effets du régime matrimonial et de la donation entre époux |
| V1 | `inheritance_tax` | Droits de succession par héritier : abattements, barème selon le lien, rappel fiscal des donations antérieures |
| V1 | `gift_tax` | Droits de donation, rappel fiscal, don familial exonéré |
| V1 | `dismemberment_value` | Valeur usufruit / nue-propriété selon l'âge de l'usufruitier (barème fiscal) |
| V1 | `life_insurance_death_tax` | Fiscalité au décès selon versements avant/après 70 ans, par bénéficiaire |
| V1 | `replay` | Rejoue un appel journalisé |
| V2 | `capital_income_tax`, `ifi`, `rental_yield`, `rental_tax_regime_compare`, `real_estate_capital_gain`, `loan_schedule` | |
| V3 | `portfolio_metrics`, `fee_impact`, `projection`, `retirement_gap`, `cashflow`, `debt_ratio`, `early_repayment_compare` | |

### Tests

- Cas unitaires chiffrés dans `packages/calc_engine/tests/cases/<fonction>/*.yaml` : entrées, sortie attendue, `expected_source` (simulateur officiel utilisé et date, ou calcul manuel détaillé à partir du texte légal), `status: draft | validated`, `validated_by: null`. Quand un simulateur officiel existe (impôt sur le revenu sur impots.gouv.fr, droits de succession sur service-public.fr), la valeur attendue est celle du simulateur, relevée avec sa date.
- Tests de propriété (hypothesis) : monotonie de l'impôt avec le revenu, quotes-parts successorales sommant à 1, usufruit + nue-propriété = pleine propriété, droits nuls sous l'abattement, invariance par permutation des héritiers de même rang.
- Test d'absence de littéral réglementaire : un test AST échoue si un nombre autre que 0, 1, 2, 12, 100 apparaît hors des tests et des fixtures.
- Couverture minimale : 95 %.

## 2. Référentiel de paramètres (`packages/params`)

### Principes

- Toute valeur réglementaire vit ici, **jamais dans le code ni les prompts**.
- Fichiers YAML embarqués dans le package (`packages/params/data/<millesime>/<domaine>.yaml`), chargés en mémoire, validés par Pydantic au chargement. Aucune base de données : les paramètres sont versionnés avec le code et leur hash figure dans chaque `CalcResult`.
- Versionnés par **millésime** (année d'application) avec dates de validité. La fonction du moteur choisit le millésime à partir de sa date de référence.
- Chaque valeur a une source (référence légale, URL officielle, date de consultation) et un statut.

### Format

```yaml
# packages/params/data/2026/income_tax.yaml
param_id: income_tax.brackets
millesime: 2026
applies_to: "revenus 2025"
valid_from: 2026-01-01
valid_to: null
source:
  reference: "CGI art. 197, I-1"
  url: "https://www.legifrance.gouv.fr/codes/article_lc/..."
  law: "Loi de finances pour 2026"
  consulted_on: 2026-09-20
status: draft                        # TODO_SOURCE | draft | validated
validated_by: null
validated_on: null
value:
  - {lower: 0, upper: ..., rate: ...}
```

### Procédure de renseignement (Claude Code)

1. Ouvrir la source officielle : article sur Légifrance, paragraphe BOFiP, page impots.gouv.fr ou service-public.fr.
2. Recopier la valeur telle qu'elle y figure, avec `reference`, `url`, `consulted_on`, `applies_to`.
3. `status: draft`.
4. Si la page est inaccessible ou ambiguë : `status: TODO_SOURCE`, `value: null`, et toute fonction qui en dépend lève `ParamNotAvailable`. Ne jamais compléter de mémoire.

### Comportement

- `params.get(param_id, reference_date)` résout le millésime et renvoie la valeur avec ses métadonnées.
- `ParamNotAvailable` si `TODO_SOURCE` ou millésime absent.
- `ParamNotValidated` si `status ≠ validated` et que la configuration `params.allow_draft` est fausse (`prod`). En `dev` et `staging`, les valeurs `draft` sont utilisées et un avertissement est ajouté au `CalcResult`.
- `params diff 2025 2026` (commande du package) affiche les changements entre millésimes.
- Processus annuel : nouveau millésime à chaque loi de finances, suite d'évals complète (aucune relecture professionnelle prévue : les valeurs restent `draft`).

Paramètres à renseigner, liste « **transmission** » (construite) : abattements et barèmes des droits de succession et de donation par lien de parenté, durée du rappel fiscal, don familial exonéré, barème de démembrement, régime de l'assurance-vie au décès (abattements et taux selon versements avant/après 70 ans), prélèvements sociaux applicables à l'assurance-vie au décès, seuil de périmètre `scope.max_gross_wealth`.

Liste « **fiscalité** » (différée) : barème IR et décote, plafonnement du quotient familial, plafond PER, taux de prélèvements sociaux sur les revenus du capital.

## 3. RAG juridique (`packages/legal_rag`)

### Corpus V1

- Code général des impôts (articles relatifs à l'IR, aux droits de mutation à titre gratuit, à l'assurance-vie, au démembrement).
- Code civil, livre III : successions, libéralités, régimes matrimoniaux.
- BOFiP : séries IR et ENR-DMTG.
- Fiches service-public.fr et impots.gouv.fr correspondantes.

Sources : exports open data de la DILA pour les codes (base LEGI) et de la DGFiP pour le BOFiP ; API Légifrance (PISTE) pour les mises à jour incrémentales lorsque des identifiants sont fournis dans Secrets Manager. Les conditions de réutilisation (Licence Ouverte) sont respectées et mentionnées dans l'interface.

### Ingestion (`services/ingestion`)

1. Téléchargement vers S3 `legal-raw/<source>/<date>/`.
2. Normalisation : découpage **par article** (codes) ou **par paragraphe numéroté** (BOFiP), conservation de la hiérarchie (code > livre > titre > chapitre > article), aucune découpe à taille fixe ; un article très long est découpé par alinéa avec le même `reference`.
3. Métadonnées par passage : `source`, `reference`, `hierarchy`, `version_date`, `valid_from`, `valid_to`, `url`, `excerpt_hash`.
4. Embedding via Bedrock (modèle en configuration), stockage dans `legal_chunks` (`embedding vector`, `search_vector tsvector` en configuration `french`), index HNSW.
5. Planification hebdomadaire (EventBridge Scheduler → Step Functions), détection des changements par hash, rapport de différences envoyé par SES, versions antérieures conservées avec `valid_to`.

### Outils

- `legal.search(query, domain, reference_date, top_k)` : recherche hybride (similarité vectorielle + plein texte, fusion par rang réciproque), filtrée sur `valid_from ≤ reference_date < valid_to`, renvoie des passages et leurs `SourceRef`.
- `legal.get_passage(chunk_id, excerpt_hash)` : texte exact, ou erreur si le hash ne correspond pas.

### Qualité

- Jeu d'évaluation `evals/retrieval/` : au moins 50 questions (IR, succession, donation, assurance-vie) avec les références attendues. Métriques : rappel@5, rappel@10, MRR. Seuil de non-régression : rappel@5 ≥ 0,85 après la première mesure, ajusté dans `evals/retrieval/thresholds.yaml`.
- Test de filtrage temporel : une question sur une règle modifiée renvoie la bonne version selon `reference_date`.

## 4. Profil et documents

### Outils de profil

- `profile.get(context, version=None)` → `WealthProfile`.
- `profile.propose_update(context, proposals)` → crée des `pending_updates` (patch JSON, provenance, question d'origine). N'écrit jamais le profil.
- `profile.confirm_update(user, pending_id, corrections)` : **endpoint de l'API profil**, appelé par le frontend sous le JWT de l'utilisateur après affichage du diff ; applique le patch, crée une nouvelle version, journalise. Pas un outil d'agent.

### Documents (**différé**)

- Upload par URL présignée S3 (`documents/<user_id>/<id>`), types acceptés : PDF, JPEG, PNG, taille maximale en configuration, antivirus non requis en V1 (fichiers jamais réexposés).
- `documents.extract(context, document_id, kind)` : envoie le document à Claude (Converse, bloc document ou image) avec un schéma de sortie strict par type ; V1 : `kind = avis_imposition` → `TaxNoticeExtraction` (année des revenus, nombre de parts, revenu fiscal de référence, revenus par catégorie et par déclarant, impôt net, prélèvements sociaux). Le résultat devient des propositions de mise à jour affichées champ par champ avec l'extrait d'origine ; rien n'est écrit sans confirmation.
- Les extractions sont stockées dans `documents.extraction` avec le modèle et la version du prompt utilisés.

## 5. Invocation des outils

### Contrat

```python
class ToolContext(BaseModel):     # construit par le code appelant, jamais par le LLM
    user_id: str
    session_id: str
    profile_version: int | None
    env: Literal["dev", "staging", "prod"]
    trace_id: str

class ToolRequest(BaseModel):
    tool: str                     # ex. "calc.income_tax"
    context: ToolContext
    args: dict                    # validé par le schéma d'entrée de l'outil

class ToolResponse(BaseModel):
    ok: bool
    result: dict | None
    error: {code: str, message: str} | None
```

- Les schémas exposés au LLM sont générés depuis les modèles Pydantic des `args` uniquement.
- Trois backends derrière la même interface `ToolInvoker` : `LocalToolInvoker` (appel en processus des mêmes handlers) pour la CLI et les tests ; `LambdaToolInvoker` (boto3 `invoke`, IAM, timeout et retries configurés), backend de référence en déploiement ; `GatewayToolInvoker` (client MCP vers AgentCore Gateway, JWT de l'utilisateur, authentification sortante par AgentCore Identity), second backend, sélectionné par feature flag SSM par environnement. Les trois passent les mêmes tests d'intégration, dont le test d'accès croisé ; Lambda et Gateway sont comparés sur latence, coût, taux d'erreur et propagation d'identité (`06-evals-mlops.md` §13).
- Une Lambda par famille : `profile`, `calc`, `legal`, `documents`, `usage`. Handlers minces dans `services/tools_lambda`, logique dans les packages.
- Chaque Lambda : validation du `ToolRequest`, vérification que l'appelant est un rôle autorisé (runtime, API ou passerelle) — avec le backend Gateway, `context` est reconstruit par le handler à partir des claims validés transmis par la passerelle, jamais des `args` —, exécution filtrée par `context.user_id`, journal structuré (`trace_id`, `tool`, durée, code d'erreur ; jamais les arguments en clair), DLQ, idempotence sur les écritures (`pending_updates` dédupliqués par hash de patch).
