# 05 — Conformité, sécurité, modèle de menaces, RGPD, garde-fous, mode démonstration

> Ce document décrit des exigences techniques. Le cadre réglementaire (statut de conseiller en investissements financiers, obligations MIF2, distribution d'assurance, démarchage, RGPD) est une **hypothèse de conception** : aucune ouverture à de vrais clients n'est prévue (portfolio, décision du 2026-09-18). Les points **[À VALIDER]** sont implémentés tels quels et signalés dans le rapport de validation ; ils le restent.

## 1. Positionnement réglementaire

- Le service est conçu **comme s'il était** opéré sous le statut d'un cabinet de conseil (CIF, et intermédiaire en assurance si pertinent). **[À VALIDER]**
- Deux types de sorties :
  - **Information générale** : explication de règles, pédagogie, simulations présentées comme génériques.
  - **Recommandation personnalisée** : toute sortie qui recommande une action à cet utilisateur compte tenu de sa situation. Soumise à validation humaine avant diffusion.
- Documents réglementaires (document d'entrée en relation, lettre de mission, rapport d'adéquation) : gabarits dans `packages/compliance/templates/`, remplis depuis le profil par du code, jamais rédigés librement par le LLM. Gabarits génériques marqués `draft`, qu'un cabinet remplacerait par les siens. **[À VALIDER]**
- Parcours précontractuel dans l'onboarding : présentation du service, acceptation des conditions et de la politique de confidentialité, consentement explicite au traitement des données patrimoniales, remise du document d'entrée en relation, questionnaire investisseur. Aucune recommandation personnalisée n'est produite tant que la lettre de mission n'est pas acceptée (case à cocher horodatée). **[À VALIDER]**

## 2. Classification des sorties (`packages/compliance`)

- Règles déterministes dans `packages/compliance/rules/classification.yaml` : une sortie est personnalisée si elle contient une formulation prescriptive (liste de verbes et tournures) associée à un montant ou à un élément du profil, ou une option marquée « recommandée », ou une comparaison chiffrée « avant / après » sur la situation de l'utilisateur. Statut `draft`. **[À VALIDER]**
- Classification LLM indépendante (`classifier`).
- Décision finale : personnalisée dès que l'une des deux le dit.
- Réponse d'attente pendant la validation : accusé de réception, délai indicatif, et explication générique des règles applicables produite par `educator` à partir des seuls passages juridiques, sans montant ni élément du profil. Un test vérifie qu'aucun montant du profil ou des calculs de la session n'apparaît dans la réponse d'attente.
- Tests dans `evals/compliance/` : au moins 40 sorties étiquetées (20 générales, 20 personnalisées, dont 10 cas limites).

## 3. Validation par un conseiller (`services/review_workflow`)

1. Le pipeline enregistre la recommandation `pending_review` et démarre une exécution Step Functions.
2. Tâche en attente (task token) ; notification SES au(x) conseiller(s) du groupe `advisors`.
3. Back-office (routes `/advisor` du frontend) : file de validation, détail avec profil versionné, findings, calculs pas à pas rejouables, sources cliquables, rapports de vérification et de conformité.
4. Le conseiller approuve, modifie ou rejette, avec commentaire obligatoire en cas de modification ou de rejet. Une modification est un nouveau texte publié, conservé avec l'original.
5. Publication à l'utilisateur (notification dans l'application et par courriel), archivage dans le journal d'audit.
6. Expiration automatique si le profil change avant la décision ; relance après 48 h ; SLA cible 5 jours ouvrés (configuration).

Accès back-office : groupe Cognito `advisors`, attribué par un administrateur (jamais par inscription), MFA obligatoire, journalisation de chaque consultation de dossier dans `audit_events`. En mode démonstration, un compte conseiller de démonstration est provisionné.

## 4. Sécurité

- **Région** : UE uniquement ; profils d'inférence UE ; vérification que chaque service utilisé reste dans l'UE.
- **Comptes** : un compte AWS par environnement ; SCP limitant aux régions UE ; aucun accès en écriture à `prod` hors procédure break-glass journalisée.
- **Chiffrement** : KMS avec clés gérées client pour la base, S3, journaux, secrets ; TLS partout.
- **Réseau** : Lambdas en VPC avec endpoints privés ; base accessible uniquement depuis le VPC via RDS Proxy ; pas d'IP publique.
- **IAM** : moindre privilège, un rôle par Lambda, par Step Functions et pour le runtime ; pas de wildcard sur les ressources de données ; le runtime n'a aucun accès direct à la base.
- **Isolation des utilisateurs** : `01-architecture.md` §5 ; tests d'accès croisé obligatoires.
- **Injection de prompt** : documents, passages du RAG et messages traités comme des données ; aucune écriture de profil sans confirmation dans l'interface ; vérification déterministe des sorties ; Bedrock Guardrails en entrée et en sortie ; schémas de sortie stricts.
- **Exposition publique** : WAF (règles gérées AWS, limitation de débit par IP) devant le frontend et l'API ; quota de questions par utilisateur et par jour (`usage.consume`) ; plafond de tokens par question ; alarme sur consommation anormale.
- **Authentification** : MFA obligatoire (TOTP), fonctions de sécurité avancées Cognito, politique de mots de passe, révocation de sessions, inscription sur invitation en mode démonstration.
- **Secrets** : Secrets Manager avec rotation ; aucun secret dans le code, les variables Terraform, l'état ou les journaux.
- **Journaux** : structurés, sans PII (noms, adresses, numéros fiscaux, IBAN, contenus de documents et de messages exclus) ; les montants agrégés sont autorisés. Les traces complètes sont en base, accès restreint et journalisé.
- **Chaîne d'approvisionnement** : `uv.lock` commité, audit des vulnérabilités en CI (bloquant sur critique), scan des images ECR, SBOM par release, images de base épinglées par digest.
- **Audit** : CloudTrail ; `audit_events` en ajout seul, export horaire vers S3 Object Lock (mode conformité) pour : recommandations, validations, consultations de dossiers, confirmations de profil, suppressions RGPD, accès break-glass.

## 5. Modèle de menaces

| Menace | Vecteur | Contrôles |
|---|---|---|
| Accès aux données d'un autre utilisateur | `user_id` manipulé via le LLM ou l'API | `user_id` injecté par le code depuis le JWT ; schémas d'outils sans identifiant ; filtrage systématique en base ; tests d'accès croisé |
| Injection de prompt | document malveillant, passage du RAG, message | données ≠ instructions ; pas d'écriture sans confirmation UI ; vérification déterministe ; guardrails ; outils en liste fermée |
| Fausse information réglementaire | hallucination, paramètre erroné | sources obligatoires et vérifiées ; paramètres sourcés avec statut ; vérification déterministe ; validation humaine ; mode démonstration visible |
| Fuite par les journaux ou les traces | PII dans logs, spans, erreurs | masquage, attributs de span limités, revue des journaux en CI (test qui injecte des PII fictives et vérifie leur absence) |
| Compromission d'un compte conseiller | hameçonnage | MFA, groupe attribué par administrateur, journalisation des consultations, revue trimestrielle des accès |
| Abus de coût | rafale de questions, prompts longs | WAF, quotas par utilisateur, plafonds de tokens et de tours, budgets AWS avec alarmes, kill switch |
| Altération du journal d'audit | administrateur malveillant | table en ajout seul, export Object Lock, SCP contre la désactivation |
| Fuite de l'état Terraform | bucket d'état exposé | chiffrement KMS, accès limité au rôle CI, versionnement, pas de secret dans l'état |
| Déni de service par dépendance | throttling Bedrock, panne régionale | backoff, files d'attente, réponse d'attente, kill switch, SLO et astreinte |

## 6. RGPD

- Registre des traitements et analyse d'impact (AIPD) rédigés en première version par Claude Code dans `docs/compliance/` à la phase 8, comme exercice de conception ; non finalisés, aucune ouverture n'étant prévue. **[À VALIDER]**
- Minimisation : ne collecter que ce qu'exigent les analyses demandées ; les règles de complétude en sont la définition opérationnelle.
- Droits : export du profil et de l'historique (JSON et PDF) depuis l'interface ; rectification via l'interface ; suppression complète (base, documents S3, extractions, conversations, appels de calcul) par un workflow `gdpr_delete` testé de bout en bout ; les événements d'audit sont pseudonymisés, pas supprimés.
- Pas d'utilisation des données clients pour entraîner des modèles ; conditions Bedrock documentées dans l'AIPD.
- Durées de conservation par défaut, appliquées par des tâches planifiées, **[À VALIDER]** :

| Donnée | Conservation par défaut |
|---|---|
| Profil, documents, conversations, appels de calcul | durée de vie du compte, puis suppression sous 30 jours après demande ou clôture |
| Recommandations validées et journal d'audit associé | 5 ans après la clôture du compte |
| Journaux techniques (CloudWatch) | 90 jours |
| Mises à jour en attente non confirmées | 30 jours |

## 7. Bedrock Guardrails

Un guardrail par environnement, appliqué à l'entrée utilisateur et à la sortie finale :

- Filtres PII : masquage dans les sorties non destinées à l'utilisateur.
- Sujets interdits : titres et fonds nominatifs, promesses de rendement, optimisation frauduleuse, dissimulation d'avoirs, conseil hors périmètre (pays étrangers, trusts).
- Filtres de contenu standard.
- Toute intervention du guardrail est journalisée avec sa catégorie (sans le contenu).

## 8. Mentions et formulations (`packages/compliance`)

- `packages/compliance/rules/mentions.yaml` : mentions ajoutées par le code selon les domaines et le mode : caractère informatif des simulations, hypothèses utilisées, millésime des règles, nécessité d'un notaire pour les actes de transmission, statut de validation des paramètres, redirection vers un conseiller.
- `packages/compliance/rules/forbidden_phrases.yaml` : liste initiale rédigée par Claude Code (« garanti », « sans risque », « vous devez absolument », « rendement assuré », « aucun impôt »…) avec variantes, statut `draft`. **[À VALIDER]**
- `packages/compliance/rules/out_of_scope.yaml` : signaux textuels de cas hors périmètre utilisés par le planificateur et les règles de périmètre.

## 9. Cas hors périmètre

Détection déterministe (`02-domain-model.md` §4) avant tout spécialiste, complétée par les signaux du planificateur. Réponse : message de redirection vers un conseiller, sans analyse, avec la raison en termes simples. Liste : résidence fiscale ou bien hors de France, devise autre que l'euro, société opérationnelle dans une question de transmission, patrimoine au-delà du seuil, divorce en cours, contentieux, trust, expatriation, titre ou fonds nominatif.

## 10. Mode démonstration

Activé par `DEMO_MODE=true` dans **tous** les environnements, `prod` compris : c'est l'état final du projet. Effets, tous testés :

- Bandeau permanent : « Prototype de démonstration. Contenus et paramètres non validés par un professionnel. Aucun conseil. »
- Inscription sur invitation uniquement (pas d'auto-inscription) ; comptes de démonstration provisionnés par script ; aucune donnée de personne réelle : les profils de démonstration sont fictifs (`fixtures/demo/`).
- Chaque réponse porte la mention du statut de validation des paramètres utilisés.
- Les documents uploadés doivent être des documents de test fournis dans `fixtures/documents/` ; un avertissement demande de ne pas téléverser de document réel.
- Le compte conseiller de démonstration voit la file de validation et peut jouer le rôle du conseiller.
