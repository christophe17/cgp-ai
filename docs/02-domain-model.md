# 02 — Modèle de données patrimonial

Le profil patrimonial est **la source de vérité** partagée par tous les agents. Il est implémenté en Pydantic v2 dans `packages/domain` et persisté dans PostgreSQL (§7). Les agents le lisent via `profile.get` ; seules les confirmations de l'utilisateur dans l'interface l'écrivent.

## 1. Principes

- Chaque objet factuel porte une **provenance** : `declared_by_user`, `extracted_from_document` (avec l'ID du document), `computed`, `validated_by_advisor`.
- Un champ absent est `None` et signifie « non renseigné », distinct de zéro.
- Les montants sont en `Decimal` avec devise. Jamais de `float` pour l'argent. Une seule devise (`EUR`) dans cette version : un actif dans une autre devise met le profil hors périmètre.
- Les dates sont des `date` ISO. L'âge, le nombre de parts fiscales et toute valeur dérivée sont calculés par le moteur, jamais stockés dans le profil.
- Le profil est **versionné** : chaque confirmation crée une nouvelle version immuable ; les recommandations référencent la version utilisée.
- Les identifiants (`person_id`, `asset_id`…) sont des ULID générés par le stockage.
- Les textes libres (`notes`, `label`) ne sont jamais utilisés par le moteur de calcul ni journalisés.

## 2. Schéma

```python
Right = Literal["pleine_propriete", "nue_propriete", "usufruit"]

class Provenance(BaseModel):
    source: Literal["declared_by_user", "extracted_from_document", "computed", "validated_by_advisor"]
    document_id: str | None = None
    updated_at: datetime

class Money(BaseModel):
    amount: Decimal
    currency: Literal["EUR"] = "EUR"

class Person(BaseModel):
    person_id: str
    role: Literal["client", "spouse", "partner", "child", "grandchild", "parent", "sibling", "other"]
    first_name: str | None = None               # affichage uniquement
    birth_date: date | None = None
    death_date: date | None = None              # personne prédécédée (représentation successorale)
    parent_ids: list[str] = []                  # filiation au sein du foyer ; un enfant d'une union précédente n'a qu'un parent dans le foyer
    adoption: Literal["none", "simple", "pleniere"] = "none"
    tax_residence_country: str = "FR"           # ISO 3166-1 alpha-2 ; autre que FR → hors périmètre
    disability: bool | None = None
    notes: str | None = None

class Household(BaseModel):
    marital_status: Literal["single", "married", "pacs", "cohabiting", "divorced", "widowed"] | None = None
    union_date: date | None = None
    matrimonial_regime: Literal[
        "communaute_reduite_aux_acquets", "separation_de_biens",
        "communaute_universelle", "participation_aux_acquets", "other"
    ] | None = None
    marriage_contract_clauses: list[Literal["attribution_integrale", "preciput", "partage_inegal", "other"]] = []
    donation_entre_epoux: bool | None = None    # donation au dernier vivant
    members: list[Person]

class Ownership(BaseModel):
    person_id: str
    right: Right
    share: Decimal = Field(gt=0, le=1)

class AssetBase(BaseModel):
    asset_id: str
    label: str
    value: Money
    valuation_date: date
    ownership: list[Ownership]
    country: str = "FR"
    acquisition_date: date | None = None
    acquisition_value: Money | None = None
    provenance: Provenance

class MainResidence(AssetBase):
    category: Literal["residence_principale"]

class SecondaryResidence(AssetBase):
    category: Literal["residence_secondaire"]

class RentalProperty(AssetBase):
    category: Literal["immobilier_locatif"]
    regime: Literal["nu_micro", "nu_reel", "lmnp_micro", "lmnp_reel", "lmp", "sci_ir", "sci_is"] | None = None
    annual_rent: Money | None = None
    annual_charges: Money | None = None
    works_value: Money | None = None

class Scpi(AssetBase):
    category: Literal["scpi"]
    units: Decimal | None = None
    unit_price: Money | None = None
    held_via: Literal["direct", "assurance_vie"] = "direct"

class Beneficiary(BaseModel):
    person_id: str | None = None                # None si hors foyer
    label: str | None = None
    share: Decimal = Field(gt=0, le=1)
    right: Right = "pleine_propriete"

class LifeInsurance(AssetBase):
    category: Literal["assurance_vie"]
    insurer: str | None = None
    opened_on: date | None = None
    insured_person_id: str
    premiums_before_70: Money | None = None     # versements effectués avant les 70 ans de l'assuré
    premiums_after_70: Money | None = None
    beneficiary_clause_text: str | None = None
    beneficiaries: list[Beneficiary] = []
    euro_fund_share: Decimal | None = None      # 0..1

class Per(AssetBase):
    category: Literal["per"]
    kind: Literal["individuel", "collectif", "obligatoire"] | None = None
    deductible_contributions: dict[int, Money] = {}   # par année de versement

class AllocationLine(BaseModel):
    asset_class: Literal["actions", "obligations", "monetaire", "immobilier", "diversifie", "other"]
    share: Decimal = Field(gt=0, le=1)

class Pea(AssetBase):
    category: Literal["pea"]
    opened_on: date | None = None
    cumulative_payments: Money | None = None
    allocation: list[AllocationLine] = []

class Cto(AssetBase):
    category: Literal["cto"]
    allocation: list[AllocationLine] = []

class RegulatedSavings(AssetBase):
    category: Literal["livret"]
    kind: Literal["livret_a", "ldds", "lep", "livret_jeune", "cel", "pel", "other"] | None = None

class EmployeeSavings(AssetBase):
    category: Literal["epargne_salariale"]
    kind: Literal["pee", "pei", "perco", "pereco", "other"] | None = None
    available_on: date | None = None

class CompanyShares(AssetBase):
    category: Literal["parts_societe"]
    legal_form: str | None = None
    ownership_pct: Decimal | None = None
    operational: bool | None = None             # société opérationnelle ou holding patrimoniale
    agreements: list[str] = []                  # ex. pacte Dutreil signé

class PrivateEquity(AssetBase):
    category: Literal["private_equity"]

class Crypto(AssetBase):
    category: Literal["crypto"]

class OtherAsset(AssetBase):
    category: Literal["other"]
    description: str | None = None

Asset = Annotated[
    MainResidence | SecondaryResidence | RentalProperty | Scpi | LifeInsurance | Per | Pea | Cto
    | RegulatedSavings | EmployeeSavings | CompanyShares | PrivateEquity | Crypto | OtherAsset,
    Field(discriminator="category"),
]

class BorrowerInsurance(BaseModel):
    insured_person_id: str
    coverage_share: Decimal = Field(gt=0, le=1)  # quotité
    monthly_premium: Money | None = None

class Liability(BaseModel):
    liability_id: str
    kind: Literal["credit_immobilier", "credit_conso", "lombard", "pret_familial", "other"]
    outstanding: Money
    annual_rate: Decimal | None = None
    monthly_payment: Money | None = None
    start_date: date | None = None
    end_date: date | None = None
    linked_asset_id: str | None = None
    borrower_insurance: list[BorrowerInsurance] = []
    provenance: Provenance

class Income(BaseModel):
    person_id: str
    kind: Literal["salaire", "bnc", "bic", "foncier", "dividendes", "interets", "pension", "rente", "other"]
    annual_amount: Money                        # montant brut imposable de l'année income_year
    income_year: int
    provenance: Provenance

class PastGift(BaseModel):
    gift_id: str
    donor_id: str
    beneficiary_id: str
    date: date
    value: Money
    form: Literal["don_manuel", "donation_notariee", "donation_partage", "don_familial_exonere", "other"]
    right_transferred: Right = "pleine_propriete"
    allowance_used: Money | None = None         # abattement consommé, si connu
    tax_paid: Money | None = None
    provenance: Provenance

class Objective(BaseModel):
    kind: Literal["retraite", "transmission", "reduction_impot", "achat_immobilier",
                  "revenus_complementaires", "protection_conjoint", "epargne_precaution", "other"]
    horizon_years: int | None = None
    priority: int                               # 1 = plus important
    notes: str | None = None

class KnowledgeExperience(BaseModel):
    product: Literal["actions", "obligations", "opcvm", "assurance_vie", "scpi", "produits_derives", "crypto", "private_equity"]
    knowledge: Literal["none", "basic", "good"]
    experience_years: int | None = None

class InvestorProfile(BaseModel):
    risk_tolerance: Literal[1, 2, 3, 4, 5, 6, 7] | None = None
    knowledge_experience: list[KnowledgeExperience] = []
    capacity_for_loss: Literal["none", "limited", "significant"] | None = None
    horizon_years: int | None = None
    sustainability_preferences: Literal["none", "some", "strong"] | None = None   # [À VALIDER] granularité attendue par le questionnaire réglementaire
    completed_at: datetime | None = None

class Preferences(BaseModel):
    excluded_asset_classes: list[str] = []
    other_constraints: list[str] = []

class WealthProfile(BaseModel):
    schema_version: Literal[1] = 1
    user_id: str
    version: int
    created_at: datetime
    household: Household
    assets: list[Asset] = []
    liabilities: list[Liability] = []
    incomes: list[Income] = []
    past_gifts: list[PastGift] = []
    objectives: list[Objective] = []
    investor_profile: InvestorProfile = InvestorProfile()
    preferences: Preferences = Preferences()
```

### Validateurs (obligatoires, testés)

- Exactement un membre de rôle `client` ; identifiants uniques ; tout `person_id` référencé (ownership, bénéficiaires, filiation, revenus, donations, assurance emprunteur) existe dans `household.members` ; tout `linked_asset_id` existe.
- `parent_ids` : au plus deux, sans cycle, jamais soi-même ; une personne prédécédée a `death_date` avant la date du jour.
- Par actif : somme des parts en `pleine_propriete` + somme des parts en `nue_propriete` = 1 ; somme des parts en `usufruit` = somme des parts en `nue_propriete`.
- Par assurance-vie : somme des parts des bénéficiaires = 1 par droit ; `insured_person_id` existe.
- `valuation_date` et `date` de donation ≤ date du jour ; `income_year` ≤ année courante.
- Une donation antérieure a `donor_id ≠ beneficiary_id`.

## 3. Règles de complétude (`packages/domain/completeness.py`)

Déterministes, évaluées par le pipeline avant les spécialistes. Un champ **bloquant** manquant arrête le flux et déclenche l'agent de collecte. Les champs **utiles** manquants sont listés dans `missing_information` du finding et abaissent la confiance.

| Domaine du plan | Bloquants | Utiles |
|---|---|---|
| `income_tax` (différé) | revenus de l'année concernée pour chaque adulte du foyer, situation matrimoniale, enfants avec dates de naissance, handicap | versements PER déductibles, revenus fonciers et régime |
| `estate` (succession) | situation matrimoniale et régime, donation entre époux, membres avec `parent_ids` et dates de naissance, donations antérieures (liste possiblement vide mais confirmée), pour chaque assurance-vie : assuré, versements avant/après 70 ans, bénéficiaires | clauses du contrat de mariage, démembrements existants |
| `gift` (donation) | donateur et bénéficiaire avec dates de naissance, donations antérieures confirmées, valeur et nature du bien | droit transmis, abattements déjà utilisés |
| `life_insurance` | assuré, date d'ouverture, versements avant/après 70 ans, bénéficiaires | répartition fonds euros / UC |
| `real_estate` (V2) | valeur, date d'évaluation, régime locatif, loyers et charges, crédit lié | travaux, assurance emprunteur |
| `allocation` (V3) | profil investisseur complet, objectifs priorisés | allocation détaillée des enveloppes |

« Confirmée » signifie que l'utilisateur a répondu explicitement, y compris « aucune » ; l'information est stockée comme liste vide avec provenance `declared_by_user`.

L'agent de collecte pose systématiquement, une fois par profil, les questions à fort impact : biens ou résidence à l'étranger, enfants d'unions précédentes, donations passées, assurance-vie ouverte avant ou après 70 ans, parts de société. Les réponses négatives sont enregistrées.

## 4. Règles de périmètre (`packages/compliance/scope.py`)

Déterministes, évaluées sur le profil et le plan avant tout appel de spécialiste. Hors périmètre, le pipeline répond par un message de redirection vers un conseiller et n'appelle aucun spécialiste :

- une personne du foyer avec `tax_residence_country ≠ FR` ;
- un actif avec `country ≠ FR` ou une devise autre que `EUR` ;
- une société opérationnelle (`CompanyShares.operational = True`) dans une question de transmission ;
- patrimoine brut supérieur au seuil `scope.max_gross_wealth` du référentiel de paramètres (**[À VALIDER]**, valeur initiale 5 000 000 EUR) ;
- intention détectée par le planificateur : divorce en cours, contentieux, trust, expatriation ;
- toute question sur un titre ou un fonds nominatif.

## 5. Objets produits par les agents

```python
class SourceRef(BaseModel):
    chunk_id: str               # identifiant du passage dans l'index juridique
    reference: str              # ex. "CGI art. 779" ou "BOI-ENR-DMTG-10-50-20 §120"
    version_date: date          # date de version du texte
    url: str
    excerpt_hash: str           # hash du passage, vérifié par legal.get_passage

class CalcRef(BaseModel):
    call_id: str
    function: str
    engine_version: str
    params_millesime: int
    params_hash: str

class Option(BaseModel):
    label: str
    pros: list[str]
    cons: list[str]
    calc_refs: list[CalcRef]

class SpecialistFinding(BaseModel):
    agent: str
    prompt_version: str
    question_scope: str
    facts_used: list[str]       # chemins JSON dans le profil, ex. "assets[2].value.amount"
    assumptions: list[str]
    findings: list[str]
    options: list[Option]
    calc_refs: list[CalcRef]
    sources: list[SourceRef]
    missing_information: list[str]
    confidence: Literal["low", "medium", "high"]

class Plan(BaseModel):
    intent: str
    domains: list[Literal["income_tax", "estate", "gift", "life_insurance", "real_estate", "allocation", "retirement", "budget"]]
    questions: list[str]
    out_of_scope_signals: list[str]

class DraftRecommendation(BaseModel):
    profile_version: int
    summary: str
    findings: list[SpecialistFinding]
    conflicts: list[str]

class CheckResult(BaseModel):
    check: Literal["amounts_match_calc", "calc_refs_exist", "sources_exist", "facts_exist", "calc_inputs_match_profile", "no_forbidden_phrase"]
    passed: bool
    details: list[str]

class VerificationReport(BaseModel):
    deterministic: list[CheckResult]
    llm_status: Literal["approved", "rejected", "needs_revision"]
    llm_issues: list[dict]      # {severity, location, description}
    iterations: int

class ComplianceDecision(BaseModel):
    classification: Literal["information_generale", "recommandation_personnalisee"]
    rule_hits: list[str]        # règles déterministes déclenchées
    llm_classification: Literal["information_generale", "recommandation_personnalisee"]
    forbidden_phrases_found: list[str]
    mandatory_mentions: list[str]
```

## 6. Chemins de faits (`facts_used`)

Un chemin est une expression JSON Pointer relative à la racine du profil (`/assets/2/value/amount`). La vérification déterministe résout chaque chemin dans la version de profil référencée et échoue si le chemin n'existe pas. Les entrées de chaque `CalcResult` portent, pour chaque valeur issue du profil, le chemin d'origine, ce qui permet de contrôler qu'elles correspondent au profil.

## 7. Persistance PostgreSQL (`packages/storage`)

Une base par environnement, schémas gérés par Alembic, accès via des dépôts typés (`ProfileRepository`, `ConversationRepository`…). Toute requête sur des données utilisateur prend `user_id` en paramètre obligatoire.

| Table | Contenu | Notes |
|---|---|---|
| `users` | `user_id` (sub Cognito), `created_at`, `deleted_at`, `demo` | |
| `profile_versions` | `user_id`, `version`, `profile` (jsonb), `created_at`, `created_by` | Immuable ; la version courante est la plus haute |
| `pending_updates` | `id`, `user_id`, `base_version`, `patch` (jsonb, JSON Patch), `provenance`, `status`, `created_at`, `decided_at` | Statuts `pending`, `confirmed`, `rejected`, `expired` |
| `documents` | `id`, `user_id`, `s3_key`, `kind`, `status`, `extraction` (jsonb), `uploaded_at` | |
| `conversations`, `messages` | conversation par session ; messages avec rôle, contenu, `trace_id`, findings et rapports (jsonb) | |
| `calc_calls` | `call_id`, `user_id`, `session_id`, `function`, `engine_version`, `params_millesime`, `params_hash`, `inputs`, `steps`, `result`, `warnings`, `created_at` | Journal des appels au moteur |
| `recommendations` | `id`, `user_id`, `profile_version`, `draft`, `verification`, `compliance` (jsonb), `classification`, `status`, `created_at` | Statuts `pending_review`, `approved`, `modified`, `rejected`, `expired`, `published` |
| `reviews` | `id`, `recommendation_id`, `advisor_id`, `decision`, `comment`, `published_content`, `decided_at` | |
| `usage_daily` | `user_id`, `day`, `questions`, `input_tokens`, `output_tokens` | Quotas |
| `audit_events` | `id`, `at`, `actor_type`, `actor_id`, `action`, `subject_type`, `subject_id`, `details` (jsonb) | Ajout seul : `UPDATE` et `DELETE` révoqués pour le rôle applicatif ; export horaire vers S3 Object Lock |
| `legal_documents`, `legal_chunks` | corpus juridique et passages indexés (`04-tools-and-data.md` §3) | Sans donnée personnelle |

- Chiffrement KMS du cluster ; PITR ; `deletion_protection` en `staging` et `prod`.
- Suppression RGPD : une transaction supprime toutes les lignes de l'utilisateur dans toutes les tables (sauf `audit_events`, où `actor_id` et `subject_id` sont pseudonymisés), puis les objets S3 ; un test d'intégration vérifie qu'aucune ligne ne subsiste.
- Migration de schéma du profil : `schema_version` dans le JSON ; une fonction de migration par version, testée sur les fixtures ; la lecture d'une ancienne version migre à la volée sans réécrire l'historique.
