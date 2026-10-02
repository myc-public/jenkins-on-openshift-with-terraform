---
title: Roadmap - Architecture industrielle (séparation des responsabilités)
created: 2026-09-19
updated: 2026-09-27
tags:
  - architecture
  - roadmap
  - plateforme
  - gitops
  - observabilité
  - portabilité
---

# Roadmap - Architecture industrielle

## Principe directeur

Chaque outil a UNE responsabilité. C'est cette séparation qui rend l'architecture plus industrielle, plus gouvernable et surtout portable entre AWS, cloud souverain et on-premise.

## Règles pour Claude Code

- Ce fichier est la source de vérité de l'avancement. Le lire en début de session.
- Ne jamais déplacer une responsabilité d'un outil vers un autre sans validation explicite (cf. tableau ci-dessous).
- À la fin de chaque unité de travail : mettre à jour la colonne **Statut** et ajouter une ligne au **Journal**.
- Statuts autorisés : `todo`, `en cours`, `fait`, `bloqué`.
- Ne jamais marquer `fait` sans preuve (commande exécutée, pipeline vert, URL, commit).
- Garder ce fichier sous 200 lignes : archiver les anciennes entrées du journal dans `roadmap-archive.md`.

## Socle de la plateforme

| Dépôt / composant | Rôle |
|---|---|
| OpenShift Developer Sandbox | Cluster managé, runtime (namespace `gregorie769-dev`) + registry interne (ImageStream) |
| Argo CD | Instance unique sur minikube (ns `argocd`) : pilote le Sandbox à distance via le SA `argocd-deployer` (rôle `edit` sur `gregorie769-dev`) ; pas d'Argo CD sur le Sandbox |
| `gitops-platform` | Source de vérité des déploiements : Kustomize `base/overlays`, ApplicationSet, AppProject |
| `inner-donation-api` | Microservice pilote de la pipeline CI/CD bout-en-bout |
| `jenkins-on-openshift-with-terraform` | Jenkins provisionné en Infrastructure as Code (JCasC, Job DSL, RBAC) |
| `craft-platform` | Socle Maven : gestion des dépendances, plugins et artefacts (`craft-parent`, BOM, `craft-build-config`) |

## Outils utilisés

Jenkins (CI, agents Kubernetes éphémères) · Nexus (proxy Maven Central + `maven-releases`/`maven-snapshots`) · SonarCloud (Quality Gate, plan free : pas de webhook, pas d'analyse hors branche principale) · OpenShift Sandbox (runtime, BuildConfig, ImageStream, Route) · 
Registry interne OpenShift (ImageStream) · Argo CD / OpenShift GitOps (CD) · Kustomize (manifests) · Terraform (IaC Jenkins) · 
GitHub (dépôts applicatifs + GitOps, PAT) · Cloudflare Tunnel (exposition de Nexus local) · Minikube (environnement local isolé) · MySQL (image Red Hat) · Docker Compose (dev local) · Maven + craft-platform (dépendances, plugins, BOM)

## Responsabilités et avancement

| Outil | Responsabilité | Statut | Prochaine action | Preuve / lien |
|---|---|---|---|---|
| Terraform | Infrastructure / Platform | fait (Jenkins) | Backend d'état distant (state local aujourd'hui) ; `ignore_changes` sur le drift perpétuel (SA, BuildConfig, ImageStream) | `terraform apply` : 0 add / 5 change / 0 destroy, 24/09 (`JENKINS_URL` déduite de `apps_domain`) |
| Jenkins | CI + Security + Build | fait (donation-api, dev) | Étendre à inner-order-api / gen-ai-api | Build #25 vert (Quality Gate synchrone), commit GitOps `2b15c7c` |
| Nexus | Dependency / Artifact Management | fait | — | Publish + vérification SHA-256, build #14 |
| Registry | Container Images | fait | — | `donation-api:1.1.0-SNAPSHOT-ec9b845-b25@sha256:87e10798...` (build OpenShift `donation-api-8`) |
| ArgoCD | CD / GitOps | fait (dev) | Accélérer la détection (webhook GitHub ou `timeout.reconciliation`) ; `configMapGenerator` | `donation-api-dev` Synced / Healthy, rév. `2b15c7c` → rollout b25 le 24/09 12:34 (2 min 45 après le commit) ; installation épinglée v3.5.3 (`bootstrap/minikube-argocd/install`, `kubectl diff` identique) |
| OpenShift | PaaS / Runtime | en cours (dev uniquement) | Provisionner uat/preprod/prod | `donation-api` 1/1 + `donation-api-mysql` 1/1 ; Route `/management/health` → 200 |
| Apache APISIX (externe) | API Gateway de bordure + WAF (Coraza, OWASP CRS) | todo | Lot K5 | |
| Apache APISIX (interne) | API Gateway interne : validation JWT (JWKS), scopes, quotas | todo | Lot K5 | |
| Keycloak | Identités et accès (OIDC) : authentification, émission des tokens | todo | Lot K1 | |
| Next.js | Front web + BFF (session serveur, tokens jamais dans le navigateur) | todo | Lot K6 | |
| OpenTelemetry + Prometheus / Grafana / Loki / Tempo | Observability | en cours (pilote donation-api : logs, traces, métriques opérationnels) | Phase 2 (spans SQL, métriques métier, `traceparent` outbox) puis phase 4 (dashboards / alertes as code) | Test E2E du 26/09 (`gitops-platform/OBSERVABILITY-TEST.md`) : b27, trace 5 spans (Tempo), log par `trace_id` (Loki), p95 ~10-12 ms (Prometheus) |

## Pipeline CI/CD bout-en-bout — capacités mises en place

| Capacité | Catégorie | Bonne pratique |
|---|---|---|
| Build → tests → Sonar (Quality Gate synchrone `sonar.qualitygate.wait`) → package | 15-Factor III/V | Étapes séparées, gate bloquante sans webhook (plan free) |
| Publish Nexus + vérification SHA-256 | Supply chain integrity | Checksum avant/après, échec bloquant si divergence |
| Build image via BuildConfig (jar vérifié + Dockerfile) | 15-Factor V/X | Même image de base du dev à la prod |
| Tag immuable `<version>-<sha>-b<build>` | Cloud Native — Immutabilité | Jamais `latest` en usage réel |
| `gitops-platform` = source de vérité unique | GitOps | Aucun `oc apply` manuel |
| Kustomize `base/overlays` | 15-Factor I/X | Un seul manifeste, décliné par environnement |
| ApplicationSet (découverte par `config.json`) | Cloud Native — Déclaratif | Ajout d'environnement = ajout de dossier |
| Promotion dev = commit direct, uat/preprod/prod = PR | Contrôle de changement | Vélocité vs gouvernance |
| Secrets hors Git (K8s Secret / Terraform) | 15-Factor XV | Jamais commités |
| RBAC Jenkins scoping fin (pas de cluster-admin) | 15-Factor XV | Moindre privilège |
| Agents Jenkins éphémères (pods à la demande) | 15-Factor VI/IX | Pas d'agent statique |
| Métadonnées archivées (build-info, image-version) | Traçabilité / provenance | Commit ↔ build ↔ image ↔ commit GitOps |
| Readiness/Liveness probes (`/management/health/*`) | 15-Factor IX | Démarrage/arrêt orchestrable, rollout sans intervention |
| MySQL déclaré en GitOps (digest, PVC, sync-wave -1) | 15-Factor IV/VI | Backing service attaché par config, données hors processus |
| Secrets DB / management hors Git (modèles `*.example.yaml`) | 15-Factor XV | Aucune valeur par défaut, fail-fast au démarrage |
| Profil et préfixe injectés par l'overlay (`SPRING_PROFILES_ACTIVE`, `MYC_CONTEXT`) | 15-Factor III | Base neutre, config par environnement |
| `/management` protégé (ADMIN / VIEWER), sondes publiques sans détails | Security — moindre privilège | Aucun endpoint d'exploitation public |
| Dev local Docker Compose (même image MySQL, même Dockerfile) | 15-Factor X | Parité dev/prod |
| build-info → `/management/info` ; nom applicatif dans les logs | Traçabilité | Version déployée lisible à chaud |
| Jenkins en Config-as-Code (JCasC + Job DSL) | Infrastructure as Code | Reproductible, pas de clic UI |
| Cloisonnement kubeconfig minikube/Sandbox | Isolation d'environnements | `kubeconfig_path`/`kubeconfig_context` épinglés dans Terraform |
| Reconstruction documentée (`gitops-platform/REBUILD.md`, recette observabilité incluse) + tag `sandbox-v2` sur les 7 dépôts (précédent : `sandbox-v1`) | Reprise après sinistre | Socle reconstructible depuis Git + sauvegarde chiffrée |
| Cluster désigné par son nom (URL d'API uniquement dans le Secret de cluster, hors Git) | Portabilité | Changer de cluster = 1 secret + `apps_domain` |

**Hors périmètre actuel** : API First (OpenAPI réparé : springdoc 3.0.3 compatible Boot 4, non retravaillé ici), Telemetry (15-Factor XIV — en cours, cf. section Observabilité), overlays uat/preprod/prod, tagging de release Git (désactivé, 5 prérequis listés dans le Jenkinsfile), secrets Terraform en clair dans `secrets.auto.tfvars` local (TODO Vault).

## Observabilité — pilote donation-api (factors Telemetry et Logs as Event Streams)

Diagnostic du 24/09 (build #25) : l'app **produit** logs, métriques et IDs de trace, mais rien ne les **collecte** ni ne les **exploite**.
mar
| Signal | Existe | Manque |
|---|---|---|
| Logs | stdout uniquement, `traceId`/`spanId` par ligne, `logback_events_total` | Texte non structuré ; IDs en double ; données personnelles à INFO (email, montant) ; aucune collecte (Loki) |
| Métriques | Actuator + Micrometer Prometheus, `/management/prometheus` (VIEWER), ~450 séries | Aucun scrape ; pas d'histogramme p95/p99 ; pas de métriques métier (dons, outbox) |
| Traces | Micrometer Tracing (bridge Brave), traceId renvoyé dans les erreurs | Aucun exporter (spans perdus) ; sampling 10 % ; pas d'OTel ; pas de `traceparent` dans l'outbox |
| Santé | Sondes liveness/readiness, build-info | Dashboards, alertes, SLO |

### Capacités d'observabilité (à tenir à jour à chaque étape)

| # | Capacité | Fait (preuve) | Reste à faire | Phase |
|---|---|---|---|---|
| 1 | Logs structurés sur stdout | JSON ECS, `service.name/version/environment/node` (b26) | — | 1 |
| 2 | Corrélation logs ↔ traces | `trace_id` Loki ; liens Loki ↔ Tempo fournis par l'image ; test local 27/09 : trace 500 → log ERROR même `trace_id` | Preuve Sandbox ; span HTTP en `status=error` pour les 5xx (dette) | 4 |
| 3 | Collecte, stockage, recherche des logs | OTLP → Loki (compromis Sandbox) | Rétention ; collecte par nœud (stdout) sur la cible | 4 / 5 |
| 4 | Données personnelles protégées | email / montant retirés, lectures en DEBUG | Paramètres SQL jamais tracés (code prêt) ; ADR politique données personnelles | 2 / 4 |
| 5 | Traçage des requêtes | Spans HTTP + sécurité + SQL dans Tempo (Sandbox 27/09 : `POST /donations` = 5 spans `query`, sans valeurs de paramètres) | — | 2 |
| 6 | Propagation asynchrone du contexte | `traceparent` dans les headers de l'outbox, trace retrouvée dans Tempo (Sandbox 27/09) | Continuité via Kafka avec le relais | 2 / relais |
| 7 | Métriques techniques (JVM, HTTP, pool DB, logs) | Reçues en OTLP dans Prometheus (b27) | — | 2 |
| 8 | Latences en percentiles | Histogramme HTTP + borne SLO 300 ms (`le="300"`, test local 27/09) | — | 4 |
| 9 | Métriques métier (dérivées des événements du domaine) | Listener outbox après commit : `domain_events_total`, `donations_created_total{category,country}`, `donations_amount{category}` ; Sandbox 27/09 (Postman S1) : 32 `DonationCreated`, 5 catégories | Compteurs créés au 1er don : `increase()` ignore le 1er incrément de chaque série (sous-comptage par catégorie sur de faibles volumes) ; **TODO CDC** : Debezium + consommateur mêmes métriques | 2 / CDC |
| 9b | Backlog de l'outbox | — | Avec le relais Kafka / CDC (événements non publiés, retard de publication) | relais |
| 10 | Lien métriques → traces (exemplars) | — | Via span-metrics Tempo (registre OTLP Micrometer sans exemplars) | 4 |
| 11 | Tableaux de bord as code | Dashboard `donation-api — Service` (35 panneaux) versionné, rechargé à chaud (test local 27/09, `docs/dashboard-grafana-as-code-v1.md`) | Preuve Sandbox | 4 |
| 12 | Alertes | 7 règles Grafana versionnées (A1-A6) ; panne MySQL locale : A2, A3, A4, A5, A6 déclenchées puis résolues | Preuve Sandbox ; contact point externe ; backlog outbox (9b) | 4 |
| 13 | SLO et budget d'erreur | 99 % dispo, 95 % < 300 ms sur 7 j ; budget et burn rate multi-fenêtres (test local 27/09) | Preuve Sandbox | 4 |
| 14 | Santé et sondes | liveness / readiness, `/management/health` | — | fait |
| 15 | Backend d'observabilité | otel-lgtm en GitOps, PVC, digest épinglé | Composants séparés, rétention, stockage objet | 5 |
| 16 | Sécurité de la plateforme | Grafana avec login (anonyme → 401), OTLP interne | SSO / RBAC Grafana | 5 |
| 17 | Reproductibilité et recette | GitOps + `OBSERVABILITY-TEST.md` | Recette automatique post-déploiement | 5 |
| 18 | Généralisation : socle commun | — | Deps + config OTel / ECS dans `craft-parent` | 5 |
| 19 | Généralisation : autres APIs | — | `inner-order-api`, `gen-ai-api` | 5 |
| 20 | Généralisation : chaîne CI/CD | — | Métriques Jenkins et Argo CD | 5 |
| 21 | Profilage continu (optionnel) | — | Pyroscope (inclus dans otel-lgtm) | 5 |
| Phase | Contenu | Statut | Preuve attendue |
|---|---|---|---|
| 0. Décisions | Stack sur le Sandbox OpenShift, 100 % déclarative (GitOps), `grafana/otel-lgtm` au pilote puis composants séparés ; redéployée depuis Git sur le prochain Sandbox | fait | ADR du 26/09 |
| 1. Logs as Event Streams | JSON ECS sur stdout (structured logging natif Boot), `service.name/version/environment/node`, IDs dédoublonnés, données personnelles retirées, lectures en DEBUG | fait | b26 (`23375bd`) : `oc logs` = 100 % JSON ECS avec `traceId`, sans email ni montant |
| 2. Instrumentation OTel | **Fait** : Brave → `spring-boot-starter-opentelemetry`, export OTLP traces / métriques / logs (appender Logback), sampling 1.0 par env, attributs de ressource, histogramme HTTP. **Reste** : spans JDBC (`datasource-micrometer`), métriques métier (dons, backlog outbox), exemplars, `traceparent` dans l'outbox | en cours | b27 (`9420ad3`) : trace `http get /api/v1/donors/{donorId}` (5 spans) dans Tempo |
| 3. Plateforme | `apps/observability` (GitOps) : otel-lgtm 0.34.0 épinglée par digest, PVC 10 Gi, `/var/tempo` en emptyDir (UID aléatoire), Grafana sans accès anonyme (secret hors Git), OTLP interne au namespace | fait | `observability-dev` Synced / Healthy ; Grafana anonyme → 401 ; OTLP via Route → 302 ; logs, traces et métriques reçus |
| 4. Exploitation as code | Dashboards versionnés, alertes (dispo, p95, 5xx ; backlog outbox reporté au relais), corrélation logs ↔ traces ↔ métriques, SLO (`docs/dashboard-grafana-as-code-v1.md`) | fait | Test local 27/09 OK (panne MySQL → A2/A4 → trace 500 → log ERROR) ; Sandbox b33 : dashboard + 7 alertes `health=ok` après correctif `GF_PLUGINS_PREINSTALL_AUTO_UPDATE=false` ; S1 (30 itérations Postman, 180 tests) et S2 (15 cas 4xx) OK : 0 5xx, 0 ERROR, aucune alerte ; S3 panne MySQL (27/09 15:27-15:37 UTC, historique Grafana) : A5 et A4 déclenchées puis résolues, 504 côté client ; A2 / A6 non déclenchées sur le Sandbox (7 × 5xx, trafic < 0,1 req/s), prouvées en local |
| 5. Généralisation | `craft-parent` (deps + config communes), inner-order-api / gen-ai-api, métriques Jenkins / Argo, composants séparés + collecte des logs par nœud | todo | Nouvelle API observable sans code spécifique |

Contraintes : le Sandbox autorise `ServiceMonitor` / `PrometheusRule` mais pas d'opérateur OTel, ni DaemonSet ni `hostPath` → au pilote, logs **aussi** exportés en OTLP par l'app (compromis assumé), collecte par nœud sur la cible définitive. minikube (2 CPU / 3 Go) ne peut pas héberger la stack.

## Contrat de frontière (à ne pas violer)

- Terraform provisionne l'infra et la plateforme, il ne déploie pas les applications.
- Jenkins build, teste et sécurise, il ne déploie pas en environnement (c'est ArgoCD).
- Nexus gère les dépendances et artefacts applicatifs, la Registry gère les images conteneur.
- ArgoCD est le seul mécanisme de déploiement (GitOps).
- OpenShift exécute, il ne porte pas la logique de pipeline.
- APISIX externe est le seul point d'entrée depuis Internet (WAF, TLS, limitation) ; APISIX interne valide les tokens et route vers les API ; aucun des deux ne porte de logique métier.
- Keycloak authentifie et émet les tokens ; il ne décide pas de l'autorisation métier.
- Next.js (BFF) gère la session web et garde les tokens côté serveur ; il ne porte pas de logique métier.
- Chaque API revalide le JWT et applique RBAC / ABAC, même derrière les gateways.
- L'observabilité est transverse et instrumentée via OpenTelemetry.

## API First — inner-donation-api 

Référentiel des bonnes pratiques API First, état des lieux du service et plan d'action.

- Date de l'audit : 2026-09-26 (branche `develop`, commit `23375bd`)
- Périmètre : endpoints REST (`/api/v1/donors`, `/api/v1/donations`, `/v1/geo/villes`), gestion des erreurs, documentation OpenAPI, sécurité, événements outbox, tests, CI.


### 1. Bonnes pratiques API First

| # | Pratique | Description |
|---|---|---|
| P1 | Le contrat d'abord | Un fichier `openapi.yaml` versionné dans le dépôt est la source de vérité. Il est relu et validé avant d'écrire le code. |
| P2 | Le code est dérivé du contrat | Interfaces et DTO générés (openapi-generator), ou à défaut vérification en CI que le code correspond au contrat. |
| P3 | Contrat vérifié automatiquement (lint) | Spectral ou Redocly avec un guide de style : nommage, codes HTTP, descriptions, exemples. |
| P4 | Contrôle des changements cassants | openapi-diff en CI contre la version publiée : un changement cassant bloque le build ou impose une nouvelle version majeure. |
| P5 | Design orienté ressources | Noms au pluriel, sous-ressources (`/donors/{id}/donations`), pas de verbes, une seule convention de nommage (camelCase), une seule langue. |
| P6 | Sémantique HTTP correcte | 201 avec en-tête `Location`, 204, 404, 409, 422, 415, 400 pour une entrée mal formée (jamais 500). |
| P7 | Erreurs standardisées (RFC 9457) | `application/problem+json`, `type` stable, code d'erreur métier, `traceId`, aucun détail interne ni donnée personnelle exposés. |
| P8 | Pagination, filtre et tri uniformes | Sur toutes les collections, avec un format de page stable (pas l'objet `PageImpl` de Spring). |
| P9 | Idempotence | En-tête `Idempotency-Key` sur les POST sensibles (un don est un flux financier). |
| P10 | Gestion de la concurrence | `ETag` / `If-Match` avec un champ `@Version` pour éviter l'écrasement silencieux lors des mises à jour. |
| P11 | Versioning et dépréciation | Version dans l'URI, version du contrat alignée sur celle de l'artefact, en-têtes `Deprecation` / `Sunset`. |
| P12 | Sécurité déclarée dans le contrat | Scopes OAuth2 par opération ; la sécurité réellement appliquée correspond au contrat. |
| P13 | Contrat documenté | Descriptions, exemples, contraintes (min, max, format, enum), toutes les réponses d'erreur possibles. |
| P14 | Contrat publié | `openapi.yaml` publié comme artefact (Nexus) ou dans un catalogue, pour que les consommateurs génèrent leur SDK ou un mock. |
| P15 | Tests de conformité au contrat | Les réponses réelles sont validées contre le schéma OpenAPI (swagger-request-validator dans MockMvc). |
| P16 | Mock à partir du contrat | Prism permet aux consommateurs de travailler avant que l'implémentation existe. |
| P17 | Événements sous contrat | Contrat AsyncAPI pour les événements publiés via l'outbox (`DonationCreated`). |


### 2. État des lieux

#### 2.1 Ce qui existe

- Version dans l'URI (`/api/v1/...`), identifiants UUID, `PATCH` pour les mises à jour partielles, 201 / 204 sur donors et donations.
- Documentation générée depuis le code par springdoc 3.0.3 (désactivée en preprod et prod), schéma de sécurité OAuth2 déclaré.
- Modèle d'erreur proche de la RFC 7807 (`ApiError` : type, title, status, detail, instance, traceId, errors[]).
- Validation Bean Validation sur les DTO d'entrée.
- Pagination sur `GET /api/v1/donors`.
- Enveloppe d'événement versionnée (`eventType`, `eventVersion`) écrite dans `outbox_event`.

#### 2.2 Ce qui est partiel ou incorrect

| # | Constat | Où | Pratique |
|---|---|---|---|
| E1 | Approche code-first : aucun contrat versionné, le Swagger est déduit du code | tout le projet | P1, P2 |
| E2 | **Faille de sécurité** : le scope `inner:donation` n'est exigé que sur `/v1/**` alors que les endpoints sont en `/api/v1/**`. Donors et donations demandent seulement un token valide, sans vérification du scope | `config/security/SecurityConfig.java` | P12 |
| E3 | Préfixe en double derrière nginx (`/api/donation/` + `/api/v1/...`) | controllers + `myc.context` | P5 |
| E4 | `VilleAPI` : chemin `/v1/geo/villes` sans `/api`, français, paramètre snake_case (`pays_code`), POST qui renvoie 200, méthode POST nommée `getAllVilles` | `api/VilleAPI.java` | P5, P6 |
| E5 | `/donations/by-donor/{donorId}` n'est pas orienté ressource | `api/DonationController.java` | P5 |
| E6 | `GET /donations` non paginé (`findAll`) ; `GET /donors` renvoie le `PageImpl` de Spring (format instable) | controllers | P8 |
| E7 | Aucun en-tête `Location` sur les réponses 201 | POST donors et donations | P6 |
| E8 | **Un UUID invalide dans l'URL renvoie 500** (`MethodArgumentTypeMismatchException` interceptée comme `RuntimeException`) | `config/ErrorHandlingAdvice.java` | P6, P7 |
| E9 | **Un email déjà utilisé lors d'un PATCH renvoie 500** (`IllegalArgumentException`) ; une violation de contrainte en base aussi | `service/DonorServiceImpl.java` | P6 |
| E10 | Erreurs servies en `application/json` et non `application/problem+json` ; le `detail` expose des messages internes (Jackson, `MethodArgumentNotValidException`) ; le 409 révèle l'email (donnée personnelle) | `ErrorHandlingAdvice`, `DonorServiceImpl` | P7 |
| E11 | `BusinessException` renvoie 400 au lieu de 422 | `ErrorHandlingAdvice` | P6 |
| E12 | Champ `type: boolean` sans signification claire (enum `ONE_SHOT` / `RECURRING` attendue), champ `timestamp` ambigu | DTO donation | P5, P13 |
| E13 | La création d'une donation ne vérifie pas l'existence du donateur (`findDonor` jamais appelé) ; le client envoie lui-même un snapshot du donateur | `service/DonationServiceImpl.java` | P6 |
| E14 | Pas de descriptions ni d'exemples, aucune `@ApiResponse` sur donors et donations | controllers, DTO | P13 |
| E15 | Version du contrat `1.0.0` codée en dur alors que le pom est en `1.1.0` | `application.yml` (`myc.docs.version`) | P11 |
| E16 | Flux OAuth `clientCredentials` déclaré avec une `authorizationUrl` inutile ; aucun scope par opération | `config/OpenApiConfig.java` | P12 |
| E17 | Aucun test de controller pour donors et donations (seul `VilleApiTest` existe) | `src/test` | P15 |

#### 2.3 Ce qui est absent

| Pratique | Manque |
|---|---|
| P3 | Lint du contrat |
| P4 | Détection des changements cassants (openapi-diff) |
| P9 | `Idempotency-Key` sur `POST /donations` |
| P10 | `@Version` + `ETag` / `If-Match` |
| P11 | Politique de dépréciation (`Deprecation` / `Sunset`) |
| P14 | Publication du contrat |
| P15 | Tests de conformité au contrat |
| P16 | Mock à partir du contrat |
| P17 | Contrat AsyncAPI des événements |


### 3. Plan d'action

Chaque lot est livré avec ses tests de validation et doit laisser `mvn verify` vert.

| Lot | Actions | Tests de validation | Corrige |
|---|---|---|---|
| L0 – Corrections urgentes | Suppression de `VilleAPI` et de tout son périmètre (D3) ; scope exigé sur `/api/v1/**` ; handlers pour type mismatch (400), 415, 406, `DataIntegrityViolationException` et email en double (409) ; email retiré des messages d'erreur | MockMvc : UUID invalide → 400 ; token sans scope → 403 ; PATCH avec email en double → 409 | E2, E4, E8, E9, E10 (partiel) |
| L1 – Contrat | Écrire `src/main/resources/openapi/donation-api.yaml` (OpenAPI 3.1) à partir de l'existant corrigé : ressources, erreurs problem+json, pagination, exemples, scopes | Le contrat passe `redocly lint` / `spectral lint` sans erreur | E1, E14, E16 |
| L2 – Génération | `openapi-generator-maven-plugin` (interfaces Spring `interfaceOnly`, DTO générés) ; les controllers implémentent les interfaces générées | `mvn verify` compile ; une divergence code / contrat casse la compilation | E1 |
| L3 – Alignement du design | `/donors/{id}/donations`, pagination de `GET /donations` au format de page stable, `Location` sur les 201, enum pour le type de don, vérification de l'existence du donateur, préfixe sans doublon ; corrections directement en v1 (D2) | MockMvc par endpoint : 201 + Location, 404 donateur inconnu, pagination | E3, E5, E6, E7, E12, E13 |
| L4 – Erreurs RFC 9457 | Migration vers `ProblemDetail` de Spring, `application/problem+json`, `type` stable, code métier, 422 pour les erreurs métier | Test paramétré : chaque cas d'erreur renvoie le bon statut et le bon content-type | E10, E11 |
| L5 – Robustesse | `Idempotency-Key` sur `POST /donations` (table dédiée, migration Flyway) ; `@Version` + `ETag` / `If-Match` sur les PATCH (412 / 428) | Deux POST avec la même clé → une seule donation et un seul événement outbox ; `If-Match` périmé → 412 | P9, P10 |
| L6 – Tests de conformité | swagger-request-validator branché sur MockMvc : chaque réponse est validée contre le contrat | Build rouge si une réponse ne respecte pas le schéma | E17, P15 |
| L7 – CI/CD | Stages Jenkins : lint du contrat, openapi-diff contre la dernière version publiée, publication du yaml dans Nexus, version du contrat reprise du pom | Un changement cassant volontaire fait échouer le pipeline | E15, P3, P4, P14 |
| L8 – Événements | `asyncapi.yaml` pour `DonationCreated` ; test qui valide le payload outbox contre ce schéma | Test unitaire sur `OutboxFactory` | P17 |


### 4. Décisions à prendre

| # | Question | Options | Décision |
|---|---|---|---|
| D1 | Mode API First | (a) Contract-first avec génération de code (recommandé) ; (b) contrat écrit à la main et vérifié contre le code | **(a)** — openapi-generator en `interfaceOnly` : le yaml génère les interfaces (`DonorsApi`, `DonationsApi`) et les DTO, les controllers les implémentent. Validé le 2026-09-26 |
| D2 | Changements cassants | (a) Corriger directement en v1 (API pas encore en production) ; (b) préserver l'existant et ouvrir une v2 | **(a)** — corrections directement en v1, pas de consommateur externe à préserver. Validé le 2026-09-26 |
| D3 | `VilleAPI` | (a) L'aligner sur les autres ressources ; (b) la supprimer (reste du squelette initial) | **(b)** — suppression du controller, du service, du repository, des DTO, des entités (`City`, `Country`) et des tests associés (intégrée au lot L0). Validé le 2026-09-26 |


### 5. Suivi d'avancement

| Lot | Statut | Branche | Validation |
|---|---|---|---|
| L0 – Corrections urgentes | en cours — code livré le 2026-09-26, non commité ; validation Postman sur OpenShift en attente | `feature-apifirst` | `mvn clean verify` vert, 60 tests. `SecurityConfigTest` échoue avec l'ancien matcher `/v1/**` (token sans scope → 200) et passe avec `/api/v1/**` (→ 403) |
| L1 → L8 | todo | | |

La sécurité métier (OAuth2, RBAC, ABAC, Keycloak) relève d'une roadmap dédiée : voir la section « TODO — Sécurité » ci-dessous. Les tests de sécurité sur OpenShift (401 / 403) sont reportés à cette roadmap, la sécurité étant désactivée (`myc.security.enabled: false`).

Points relevés pendant L0, à traiter plus tard :
- Les refus 401 / 403 sont journalisés en `ERROR` par `SecurityAuthEntryPoint` / `SecurityAccessDeniedHandler` : un `WARN` suffirait (lot L4).
- Les 406 sont renvoyés sans corps quand le client n'accepte pas JSON : c'est le comportement normal de Spring, à décrire dans le contrat (lot L1).

## Sécurité — Keycloak, gateways, BFF, RBAC / ABAC (architecture : `docs/securite-architecture-v1.md`)

> Statut : **en cours (K0)**. Aujourd'hui `myc.security.enabled: false` : `/api/v1/**` est ouvert sur tous les environnements.

| Lot | Contenu | Statut | Preuve attendue |
|---|---|---|---|
| K0 | Décisions DS1-DS12, ADR, architecture | en cours | ADR du 28/09 |
| K1 | Keycloak as code (PostgreSQL, realm importé depuis Git), local + GitOps | en cours | Local OK le 28/09 (Keycloak 26.7.4, keycloak-config-cli 26.5.5, `gitops-platform/local/keycloak`) : token `donation-service` (iss, `aud=donation-api`, `donation:read`, rôle `agent`, 300 s), JWKS 200, refus (scope non autorisé, password grant, PKCE absent, redirect_uri étrangère), réimport idempotent ; reste : manifestes OpenShift + Argo ; validé par l'utilisateur le 01/10 (Postman `local-donation-keycloak`, 49 / 49) ; reste : manifestes OpenShift + Argo (déploiement d'un bloc) |
| K2 | Resource server : issuer Keycloak, audience, rôles / scopes → autorités, sécurité activée partout | fait | Local OK le 01/10 (branche `feature/k2-resource-server`, 75 tests verts dont `JwtValidationTest` : iss / aud / expiration / signature) ; Keycloak local : sans token 401, `donation:read` GET 200 / POST 403, read+write POST 201, audience sans scope 403, token `master` 401, token altéré 401, `/management/health` 200, CORS fermé ; starter Boot 4 `spring-boot-starter-security-oauth2-resource-server` (sans lui, aucun décodeur JWT) ; reste : commit / merge, variables `OIDC_*` dans l'overlay au déploiement ; mergé dans `develop` (PR #26) ; validé par l'utilisateur le 01/10 (Postman `local-donation-keycloak`, 49 / 49) ; variables `OIDC_*` à poser au déploiement |
| K3 | RBAC modèle C : permissions dans l'API (`@PreAuthorize`), matrice = rôles de realm composites (ADR 01/10) | fait | Local OK le 01/10 (branche `feature/k3-rbac`) : 98 tests verts (`PermissionsTest` 22 cas, garde-fou `EndpointsSecuredTest` vérifié par mutation) ; Keycloak local, vrais utilisateurs en code + PKCE : tokens `admin.test` 10 permissions, `agent.test` 7, `donor.a` 0, `donation-service` 4 ; 15 appels conformes à la matrice (agent : DELETE / PATCH don 403 ; admin : 204 / 200 ; donor : 403) ; matrice modifiée dans le realm puis réimportée → appliquée **sans redémarrer l'API** ; reste : commit / PR (`gitops-platform` + `inner-donation-api`) ; mergé dans `develop` (PR #27) ; validé par l'utilisateur le 01/10 (Postman `local-donation-keycloak`, 49 / 49) |
| K4a | Identités : realms `myc-internal` / `myc-customers` as code, groupes (groupes par défaut), rôles métier (dont `donation-supervisor`), Google / Facebook (externes), MFA (internes), attribut `party_id` non modifiable par l'utilisateur, contrôle CI Groupe → Rôle → Permission | en cours | Local OK le 02/10 (branches `feature/k4ab-identites`) : realms `myc-internal` / `myc-customers` appliqués, `party_id` non modifiable par l'utilisateur, groupes et rôles métier, Mailpit ; contrôle CI `tools/check-realm-rbac.py` vert (rouge sur copie fautive) ; MFA reportée à K6 ; reste : commit / PR |
| K4b | Contrat de claims : mappers `party_id`, `actor_type`, `permissions` ; API sur `permissions` / `party_id` (plus `resource_access`), deux émetteurs acceptés ; contrat documenté | en cours | Local OK le 02/10 : API à deux émetteurs (`OidcIssuersConfig`), convertisseur `ClaimsJwtAuthenticationConverter` (`permissions`, `party_id`, plus aucune structure Keycloak) ; 99 tests verts ; collection `local-donation-keycloak` (44 requêtes) 68 / 68 avec Newman ; reste : commit / PR |
| K4c | ABAC : donateur = lit ses données, liste tous ses dons, crée des dons (`donorId` = `party_id`) ; profil créé à l'inscription par l'onboarding (`POST /donors/me`, une fois) ; bénéficiaire sans accès à `donation-api` | todo | `donor.b` sur les données de `donor.a` → 403 |
| K4d | Audit : `@Audited`, topic `audit.events`, stockage non modifiable, consultation par le superviseur pour son équipe | todo | Action interne sensible → événement d'audit consultable |
| K5 | APISIX externe (WAF Coraza, liste blanche, limitation) + interne (JWT, scopes) ; NetworkPolicy ; suppression des Routes | todo | Attaque OWASP bloquée ; appel direct à l'API impossible |
| K6 | Next.js front + BFF (Auth.js, code + PKCE, session serveur Redis, CSRF, logout Keycloak) | todo | Login navigateur → appel API sans token dans le navigateur |
| K7 | Contrat OpenAPI : schéma Keycloak, scopes / rôles par opération | todo | Swagger avec Keycloak |
| K8 | Observabilité sécurité : 401 / 403 en WARN, audit par `sub`, alerte pics de refus, trace navigateur → SQL | todo | Trace unique de bout en bout dans Tempo |
| K9 | Tests : Postman (client credentials, matrice RBAC / ABAC) + parcours navigateur | todo | Runner vert |

Acquis du lot L0 : scope exigé sur `/api/v1/**`, chaîne sécurisée par défaut, `SecurityConfigTest` (401 / 403 / 200).


| Composant | Outil responsable |
|---|---|
| Infra physique, VM, réseau, stockage, DNS, load balancer, cloud, infra OpenShift | Terraform |
| OS, serveurs, hardening, certificats, agents (hors Kubernetes) | Ansible |
| Namespaces, RBAC, Deployments, Routes, Services, ConfigMaps, NetworkPolicies, Operators, Kafka, APISIX, Jenkins, Keycloak, Next.js | Argo CD — GitOps |

## Décisions (ADR courts)

| Date | Décision | Raison |
|---|---|---|
| 2026-09-22 | Kubeconfig séparés (`sandbox.config` via la fonction `ocs`, minikube en contexte par défaut) + `kubeconfig_path`/`kubeconfig_context` épinglés dans Terraform | Un `terraform apply` lancé sous le contexte minikube a fait perdre le state Jenkins (refresh → 404 → tentative de recréation) |
| 2026-09-23 | Argo CD reste sur minikube et pilote le Sandbox à distance (SA `argocd-deployer`, rôle `edit`) + `resource.inclusions` | Le blocage n'était pas le RBAC mais l'absence d'Argo sur le Sandbox ; le Sandbox refuse le list de nombreux types (cache Argo en `Unknown`) |
| 2026-09-24 | Secrets appliqués à la main depuis des modèles versionnés (`bootstrap/secrets/*.example.yaml`) | Aucun secret dans Git en attendant Sealed Secrets / External Secrets |
| 2026-09-24 | Quality Gate via `sonar.qualitygate.wait` (TODO webhook si plan Enterprise) | Webhook SonarCloud indisponible sur le plan free |
| 2026-09-24 | Dans les overlays, `patches:` au-dessus de `images:` ; merger `origin/main` dans `develop` avant une PR sur un overlay | Jenkins commite `newTag` sur `main` : conflit de lignes adjacentes (PR #6) |
| 2026-09-24 | Installation d'Argo CD codifiée (Kustomize, `install.yaml` v3.5.3 épinglé, Dex à 0) | Seule pièce du socle installée à la main (22/09) ; indispensable pour reconstruire après l'expiration du Sandbox |
| 2026-09-24 | Argo désigne le cluster par son nom (`destination.name`), `resource.inclusions` en motif `https://api.*:6443`, URL Jenkins déduite de `apps_domain` | L'URL d'API change avec le cluster : elle ne vit plus que dans le Secret de cluster (hors Git) |
| 2026-09-26 | Observabilité du pilote sur le Sandbox : stack tout-en-un `grafana/otel-lgtm` en GitOps, export OTLP par l'application (logs compris) | Livrer avant l'expiration du Sandbox ; pas de DaemonSet ni `hostPath` sur le Sandbox (collecte des logs par nœud impossible) ; redéploiement à l'identique depuis Git sur le prochain Sandbox |
| 2026-09-26 | Métriques métier = événements du domaine : dérivées de l'outbox (listener `AFTER_COMMIT` sur le contrat JSON publié), pas dans la couche service ; TODO : consommateur CDC (Debezium) avec les mêmes noms de métriques | Couplage faible (services sans télémétrie), seuls les faits commités comptent, même source que les consommateurs Kafka ; bascule CDC sans impact dashboards / alertes |
| 2026-09-28 | Flux entrant : Navigateur → APISIX externe + WAF → Next.js (front + BFF) → APISIX interne → API ; Keycloak : endpoints OIDC publics seuls exposés | Tokens hors navigateur (BFF), WAF sur le trafic non fiable avant le BFF, défense en profondeur (l'API revalide) |
| 2026-09-28 | Apache APISIX (autonome, YAML, 2 instances) à la place de Kong OSS | Kong OSS : pas de validation JWT par JWKS ni de WAF (Enterprise) ; APISIX : openid-connect, Coraza, OTel, sans base ni CRD (compatible Sandbox) |
| 2026-09-28 | Autorisation : rôles (qui) + scopes (quoi) + ABAC propriétaire (`owner_sub`) ; Keycloak + PostgreSQL dédié, realm as code | Remplace ADFS et le scope unique `inner:donation` ; l'email n'est pas une identité stable |
| 2026-10-01 | Autorisation « modèle C » : les API ne vérifient que des **permissions** stables (rôles de client Keycloak, ex. `donor:delete`), portées par le token limité à l'API ; les **rôles métier** (`donation-admin`, `donation-agent`, `donation-donor`) sont des rôles de realm **composites**, as code (la matrice) ; l'ABAC (propriétaire) reste dans l'API. Service d'autorisation dédié **reporté**, déclenché si : rôles différents par organisation, workflows d'approbation / recertification / séparation des tâches, règles sur les données partagées par plusieurs API ; il deviendrait alors la source des permissions (mapper de token), sans changer les API | Gouvernance centrale sans service à exploiter ni appel par requête ; analyse du microservice RBAC d'un programme précédent (identités dupliquées avec l'IdP, permissions lues à l'exécution, pas d'ABAC, admin non cloisonné par organisation) ; révise DK2 (rôles de client = permissions, rôles métier au niveau du realm) |
| 2026-10-02 | Identités : **deux realms** `myc-internal` (admin, agent, superviseur ; comptes créés dans Keycloak, AD plus tard ; MFA) et `myc-customers` (donateur, bénéficiaire ; inscription, Google / Facebook) ; autorisation **Groupe → Rôle métier → Permission** (jamais groupe → permission ni utilisateur → rôle, contrôlé par la CI) | Politiques de sécurité par realm (MFA, sessions, inscription) ; séparation workforce / clients ; gouvernance des accès par groupes |
| 2026-10-02 | **Contrat de claims** indépendant de l'IdP : `party_id` (identifiant métier de la personne), `actor_type` (`internal` / `external`), `permissions` (liste à plat pour l'API visée) ; **`donorId` = `party_id`** (pas de second identifiant, pas de renommage) ; changement d'IdP = mappers + `issuer-uri` / `jwk-set-uri` | Aucune API ne stocke d'identifiant Keycloak ni ne dépend de sa structure de token (corrige `resource_access` lu en K2 / K3) ; bounded contexts préservés |
| 2026-10-02 | Flux : pilote = API acceptant les deux émetteurs (liste explicite), cible = token interne émis par APISIX interne ; API → API par token exchange (RFC 8693) ; Kafka : contexte de sécurité en en-têtes (`party_id`, `actor_type`, `actor_id`, `traceparent`), jamais de token, identité par service ; audit des actions internes sensibles par `@Audited` → topic `audit.events` → stockage non modifiable, consultable par le superviseur pour son équipe | Pas de couplage fort entre les composants d'un workflow ; traçabilité des actions internes |

## Journal

| Date | Session | Ce qui a été fait | Reste à faire |
|---|---|---|---|
| 2026-09-19 | Création | Note initiale de séparation des responsabilités | Renseigner les statuts réels |
| 2026-09-22 | Pipeline CI/CD bout-en-bout (donation-api) | Tunnel Cloudflare Nexus renouvelé ; nouveau PAT GitHub gitops (classic, scope `repo`) ; state Terraform récupéré par import après désynchronisation ; cloisonnement minikube/Sandbox ; build #14 vert jusqu'au commit GitOps (`38f0485`) ; rendu Kustomize vérifié (`newTag: ...-b14`) | Confirmer le sync Argo CD live (accès `Application` refusé par RBAC) ; overlays uat/preprod/prod ; Kong ; Observability |
| 2026-09-23 | Argo CD + MySQL + dev local | Diagnostic Argo (pas RBAC : pas d'Argo sur le Sandbox) → Argo minikube + SA `argocd-deployer` + `resource.inclusions` ; MySQL GitOps ; dev local Compose ; Dockerfile partagé CI/local ; `OutboxFactoryTest` ; `sonar.branch.name` retiré (403 plan free) ; build #24 → commit `876cfb6` → Synced b24 (24/09 01:11) | Secret DB ; sondes ; webhook Sonar ; ROADMAP |
| 2026-09-24 | Mise en service donation-api (dev) | Secret DB (MySQL 1/1, Flyway OK) ; sondes `/management/health` + profil `dev` (PR #6) ; Quality Gate synchrone ; nom applicatif + build-info ; Swagger réparé (springdoc 3.0.3, `MYC_CONTEXT`) ; `/management` sécurisé + secret management (PR #7) ; build #25 → `2b15c7c` → Synced / Healthy b25 ; preuve Registry corrigée (b7 ≠ b14) | Révoquer le token exposé le 23/09 ; tunnel Cloudflare nommé ; `configMapGenerator` ; aligner `inner-order-api` / `craft-parent` ; overlays uat/preprod/prod ; Kong ; Observability |
| 2026-09-24 | Préparation de l'expiration du Sandbox (~30/09) | Tag `sandbox-v1` sur les 7 dépôts (gitops `2b15c7c` = b25) ; sauvegarde `D:\backup\socle-sandbox-v1-20260924` (7z chiffré + `nexus-data.tgz` 787 Mo) ; installation Argo codifiée ; cluster désigné par son nom (inclusions en glob testées, aucun redéploiement) ; `apps_domain` + `JENKINS_URL` (Terraform) ; runbook `REBUILD.md` (étapes 0-9) | Choix de la cible (nouveau Sandbox / OpenShift Local / OKD) ; `ignore_changes` Terraform (dette 15) ; rotation du token SonarCloud ; exercice de reconstruction via `REBUILD.md` |
| 2026-09-24 | Diagnostic observabilité (donation-api) | Inventaire logs / métriques / traces / plateforme ; roadmap en 6 phases (section Observabilité) | Phase 0 (hébergement) ; phase 1 (logs JSON ECS) |
| 2026-09-26 | Observabilité opérationnelle (pilote donation-api) | Logs JSON ECS (b26) ; OpenTelemetry + export OTLP (b27) ; stack otel-lgtm en GitOps (`observability-dev`) ; test E2E validé et versionné (`OBSERVABILITY-TEST.md`) ; incidents : idler du Sandbox (MySQL à 0, rétabli par Argo), tunnel Cloudflare mort (relancé) | Phase 2 (SQL, métier, outbox) ; phase 4 (dashboards, alertes, SLO) ; dette 15 (drift Terraform) |
| 2026-09-27 | API First (pilote donation-api) | Audit API First (17 pratiques, 17 constats, plan L0-L8) ; décisions D1 génération de code, D2 corrections en v1, D3 suppression VilleAPI ; lot L0 sur `feature-apifirst` (scope `/api/v1/**`, erreurs 400/409/415/406 sans données personnelles, VilleAPI supprimée) : `mvn clean verify` vert, 60 tests ; roadmap sécurité (OAuth2, RBAC, ABAC, Keycloak) ouverte en todo | Commit L0 ; validation Postman sur OpenShift ; lot L1 (contrat `donation-api.yaml`) |
| 2026-09-27 | Observabilité phase 4 (exploitation as code) | Contenu validé (`docs/dashboard-grafana-as-code-v1.md`) ; dashboard (35 panneaux), 7 alertes Grafana, SLO 99 % / 300 ms provisionnés via `configMapGenerator` dans `apps/observability` ; borne SLO 300 ms (`application.yml`) ; test local avec la même image : panne MySQL → alertes → trace → log, résolution | Commits (gitops + app) ; build + sync ; preuve Sandbox (suspendre l'auto-sync MySQL le temps du test) ; dette : 5xx en `status=error` sur le span HTTP |
| 2026-09-27 | Observabilité phase 4 sur le Sandbox (b33) | Correctif Grafana `GF_PLUGINS_PREINSTALL_AUTO_UPDATE=false` (plugins désenregistrés sous UID aléatoire) ; collection + data files Postman (`inner-donation-api/postman`) ; S1 / S2 OK (spans SQL, `traceparent` outbox, métriques métier prouvés) ; S3 panne MySQL : A4 / A5 déclenchées puis résolues | Remettre `autoSync: true` si coupé ; A2 / A6 sur le Sandbox avec charge parallèle ; sous-comptage par catégorie (`increase()` sur séries neuves) ; 5xx en `status=error` sur le span HTTP |
| 2026-09-28 | Sécurité : architecture cible et décisions | Flux Navigateur → APISIX externe + WAF → Next.js (front + BFF) → APISIX interne → API, Keycloak ; APISIX remplace Kong ; décisions DS1-DS12 validées ; lots K0-K9 ; `docs/securite-architecture-v1.md` | Backup `sandbox-v2` avant le 30/09 ; K1 (Keycloak as code) en local |
| 2026-09-28 | Backup `sandbox-v2` (avant expiration du Sandbox le 30/09) | Tag `sandbox-v2` sur `main` des 7 dépôts (gitops `5137d61`, donation-api `f8ba40c`) ; `D:\backup\socle-sandbox-v2-20260928` : `fichiers-locaux.7z` chiffré (31 fichiers : secrets `*.dev.yaml` dont Grafana, tfvars / tfstate, README locaux, dump MySQL 4 tables, mémoire Claude ; testé dans l'interface 7-Zip) + `nexus-data.tgz` 1 140 Mo ; `REBUILD.md` : référence v2, observabilité, dump optionnel, recette Grafana / Postman ; copies en clair de la v1 supprimées ; incident : idler du Sandbox (tout à 0) + minikube à moitié démarré, rétabli par `minikube start` et refresh Argo | Supprimer `motpass.txt` du dossier de backup ; commit de la note 7-Zip dans `REBUILD.md` ; `ocs logout` ; K1 Keycloak as code en local |
| 2026-10-01 | Sécurité : modèle d'autorisation | Avis sur le microservice RBAC d'un programme précédent (`README-RBAC.md`) ; capacités Keycloak vs service d'autorisation dédié ; ADR modèle C (permissions dans le token, rôles métier composites as code, service dédié reporté avec critères de déclenchement) | K3 en modèle C (realm + API) |
| 2026-10-01 | Sécurité : validation locale K1-K3 | Procédure de démarrage local (Keycloak, MySQL, `mvn spring-boot:run`) ; collection Postman `local-donation-keycloak` (35 requêtes : santé, tokens client credentials + connexion utilisateur code + PKCE automatisée, authentification, matrice RBAC, CORS) ; 49 / 49 tests verts chez l'utilisateur ; incident : `.env` Keycloak local écrasé par l'assistant pendant que l'utilisateur testait (remise à zéro de Keycloak) | K4 ABAC ; collection d'observabilité à adapter (K9) |
| 2026-10-02 | Sécurité : modèle d'identité et d'autorisation | Besoin utilisateurs (internes / externes, groupes, audit, workflows, indépendance vis-à-vis de l'IdP) ; décisions DI1-DI7 validées ; `donorId` = `party_id` ; profil donateur créé par l'onboarding ; K4 découpé en K4a-K4d | K4a (realms, groupes, rôles, MFA, Google) avec K4b (contrat de claims) |
| 2026-10-02 | Sécurité : K4a + K4b en local | Deux realms as code (internes / externes), groupes → rôles métier → permissions, contrat de claims (`permissions`, `party_id`, `actor_type`), API multi-émetteurs, contrôle CI des règles RBAC ; corrections : description YAML avec virgule, `userProfileEnabled` requis par keycloak-config-cli pour le profil utilisateur, `CryptoJS` redéclaré dans la collection (Newman) | Commit / PR des deux dépôts ; K4c ABAC |
