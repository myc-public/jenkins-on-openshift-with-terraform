---
title: Architecture de sécurité v1 - exposition des API (Keycloak, APISIX, Next.js BFF)
created: 2026-09-28
tags:
  - sécurité
  - architecture
  - keycloak
  - api-gateway
  - bff
---

# Architecture de sécurité v1 - exposition des API

Décisions validées le 28/09 (cf. [ROADMAP](ROADMAP.md), section Sécurité, lots K0-K9). Pilote : `inner-donation-api`.

## Point de départ

`myc.security.enabled: false` sur tous les environnements : `/api/v1/**` est ouvert. La chaîne sécurisée existe (resource server JWT, scope `inner:donation`, handlers 401 / 403) mais pointe vers ADFS, sans vérification d'`issuer` ni d'`audience`, sans rôle et sans lien entre un donateur et une identité. CORS : `*` avec `allowCredentials`.

## Flux entrant

```
                                  Internet
                                     │  https://donation.<domaine>
             ┌───────────────────────┴───────────────────────┐
             │ APISIX externe + WAF (Coraza, OWASP CRS)      │  TLS, limitation par IP, anti-bot,
             │ seule Route OpenShift du socle                │  taille des requêtes, en-têtes de
             │ liste blanche de chemins                      │  sécurité, correlation-id, OTel
             └──────┬──────────────────────────┬─────────────┘
                    │ /, /_next/static/**,     │ /realms/myc/protocol/openid-connect/**
                    │ /api/auth/**, /api/bff/**│ + pages de login Keycloak
                    ▼                          ▼
   ┌──────────────────────────┐        ┌──────────────┐
   │ Next.js : front + BFF    │◄──────►│   Keycloak   │ console d'administration jamais exposée
   │ Auth.js, client          │ code + │  PostgreSQL  │
   │ confidentiel, session    │ PKCE   └──────▲───────┘
   │ serveur (Redis)          │ (backchannel) │ JWKS (interne)
   └────────────┬─────────────┘               │
                │ Bearer (audience donation-api)
                ▼                              │
   ┌──────────────────────────────────────────┴───┐    clients machine
   │ APISIX interne                               │◄── (inner-order-api,
   │ validation JWT (JWKS, iss, aud, exp),        │     client credentials)
   │ scopes, quotas par client                    │
   └────────────┬─────────────────────────────────┘
                ▼
   ┌──────────────────────────┐
   │ donation-api             │ revalidation JWT + RBAC + ABAC (owner_sub)
   └────────────┬─────────────┘
                ▼
              MySQL
```

## Responsabilités

| Composant | Fait | Ne fait pas |
|---|---|---|
| APISIX externe | Seul point d'entrée Internet : TLS, WAF, limitation par IP, liste blanche de chemins, en-têtes de sécurité, correlation-id | Validation des tokens, logique métier |
| Next.js (front + BFF) | Pages, login OIDC (Auth.js), tokens en session serveur, relais des appels vers APISIX interne, CSRF, logout | Logique métier, autorisation fine |
| APISIX interne | Validation JWT (JWKS), scopes, quotas par client, routage vers les API | Logique métier, décision d'accès métier |
| Keycloak | Identités, authentification, émission des tokens (rôles, scopes, audience) | Autorisation métier |
| donation-api | Revalidation du JWT, RBAC par opération, ABAC propriétaire | Session, login |

## Décisions

| # | Décision | Pourquoi |
|---|---|---|
| DS1 | Keycloak sur le Sandbox en GitOps, realm importé depuis Git ; local avec Compose | Tout déclaratif ; reconstruit à l'identique sur un nouveau cluster |
| DS2 | PostgreSQL dédié à Keycloak (sclorg, digest, PVC) | Base recommandée par Keycloak ; pas de couplage avec le MySQL de l'API |
| DS3 | Rôles = qui (`donation-admin`, `donation-agent`, `donor`) ; scopes = ce que le client demande (`donation:read`, `donation:write`) ; ABAC = propriétaire | Remplace le scope unique `inner:donation` ; sépare identité, délégation et propriété |
| DS4 | Colonne `owner_sub` (sub Keycloak) sur le donateur | L'email change et c'est une donnée personnelle ; le `sub` est stable |
| DS5 | Clients : `donation-api` (audience), `donation-web` (Next.js, confidentiel, code + PKCE), client de service (client credentials) ; utilisateurs de test : admin, agent, deux donateurs | Un client par usage, aucun client public |
| DS6 | Apache APISIX, mode autonome (YAML), deux instances (externe, interne) | Kong OSS n'a ni validation JWT par JWKS ni WAF (Enterprise) ; APISIX : openid-connect, Coraza, OTel, sans base ni CRD (compatible Sandbox) ; un seul produit à exploiter |
| DS7 | L'API revalide toujours le JWT | Défense en profondeur ; aucune confiance implicite dans le réseau |
| DS8 | Next.js serveur = front + BFF (un seul serveur) | Le serveur Next.js est déjà un BFF (route handlers, Auth.js) : un saut et un composant de moins |
| DS9 | Front React / Next.js servi sous le même domaine que le BFF | Même origine : cookie `SameSite`, pas de CORS |
| DS10 | WAF en bordure, avec APISIX externe | Filtrer le trafic non fiable avant le BFF (cible principale : cookies, sessions, callback OIDC) ; un WAF après le BFF inspecte un trafic déjà reconstruit |
| DS11 | Pilote : mapper d'audience `donation-api` et relais du token ; cible : token exchange (RFC 8693) | Limiter la portée du token de l'utilisateur à l'API appelée |
| DS12 | Sessions du BFF dans Redis (Auth.js avec stockage serveur) | Tokens jamais dans un cookie, même chiffré ; BFF sans état et multi-instances (15-factor) |
| DS13 | Modèle C (01/10) : l'API vérifie des **permissions** (rôles de client `donation-api`, ex. `donor:delete`) ; la matrice = rôles de realm **composites** `donation-admin` / `donation-agent` / `donation-donor`, as code dans le realm ; ABAC dans l'API | Les API ne connaissent pas les rôles métier ; gouvernance centrale sans service à exploiter ni appel par requête ; source des permissions remplaçable plus tard sans toucher aux API |

Options écartées :
- **WAF après le BFF** (proposition initiale) : laisse l'External Gateway et le BFF exposés au trafic brut.
- **nginx du front en reverse-proxy du BFF** : ne cache rien (les chemins `/bff` restent atteignables depuis Internet), ajoute un saut, couple la disponibilité de l'API à celle du front et duplique le routage de la gateway.
- **Front sur un CDN d'un autre domaine** : cross-origin, CORS, cookies `SameSite=None`, exposition au CSRF.
- **Kong OSS** : voir DS6.

## Parcours

**Chargement** : `GET /` → APISIX externe (WAF) → Next.js (pages, `/_next/static/**`). Aucune authentification.

**Login** : le front navigue vers `/api/auth/signin` → Auth.js redirige vers Keycloak (`/realms/myc/...`, authorization code + PKCE) → login → callback `/api/auth/callback/keycloak` → Next.js échange le code en backchannel, stocke les tokens en session Redis, pose un cookie de session (`HttpOnly`, `Secure`, `SameSite=Lax`, préfixe `__Host-`).

**Appel métier** : le navigateur appelle `/api/bff/...` avec le cookie → Next.js retrouve la session, rafraîchit l'access token si besoin, appelle APISIX interne avec `Authorization: Bearer` → APISIX interne valide le JWT et les scopes → donation-api revalide, applique RBAC et ABAC. Le navigateur ne voit jamais de token.

**CSRF** : jeton anti-CSRF exigé sur les requêtes qui modifient (POST, PATCH, DELETE) vers `/api/bff/**`, en plus de `SameSite`.

**Logout** : `/api/auth/signout` → destruction de la session Redis → logout Keycloak initié par le client ; back-channel logout de Keycloak vers le BFF.

**Clients machine** (inner-order-api, partenaires) : client credentials auprès de Keycloak → APISIX interne (ou externe pour un partenaire) → API. Ils ne passent pas par le BFF.

## Keycloak

- Realm `myc` importé depuis Git ; secrets des clients et mots de passe des utilisateurs de test hors Git.
- `hostname` = URL publique (l'`iss` des tokens) ; backchannel dynamique pour les appels internes (Next.js, APISIX interne, API). Sans cela, l'`iss` du token ne correspond pas à l'URL de validation interne.
- Access token court (5 min) ; refresh token avec rotation, conservé uniquement par le BFF.
- Détection du brute force ; MFA pour les administrateurs ; ni implicit flow ni password grant.
- Console d'administration : jamais routée par APISIX externe.

## Protections réseau et exposition

1. Aucune Route OpenShift sauf APISIX externe : Next.js, APISIX interne, donation-api, Keycloak admin n'ont qu'un Service `ClusterIP`.
2. NetworkPolicy en chaîne : APISIX externe → Next.js ; Next.js → APISIX interne ; APISIX interne → donation-api ; donation-api → MySQL. Next.js et APISIX interne → Keycloak (interne).
3. Liste blanche de chemins sur APISIX externe : `/`, pages, `/_next/static/**`, `/api/auth/**`, `/api/bff/**`, endpoints OIDC publics et pages de login Keycloak. Tout le reste est bloqué.
4. Santé et management non routés : la route de santé de Next.js (`/api/health`) est bloquée à la gateway et appelée par les sondes directement sur le pod ; l'actuator des API reste sur `/management` (non routé).

## Front (Next.js)

- Une seule image pour tous les environnements : chemins relatifs, configuration par variables d'environnement au démarrage (15-factor, build once run anywhere).
- En-têtes : CSP stricte, `X-Content-Type-Options`, `Referrer-Policy`, HSTS.
- Cache : pages sans cache ; `/_next/static/**` en cache long (noms de fichiers avec hash).
- Aucun token dans `localStorage` ni dans le JavaScript.

## Observabilité

`traceparent` propagé de bout en bout (plugin OpenTelemetry d'APISIX, instrumentation OTel de Next.js, API) : une seule trace dans Tempo du navigateur jusqu'au SQL. Jamais de token ni de cookie dans les logs. 401 / 403 en WARN, audit par `sub` sans donnée personnelle, alerte sur les pics de refus (lot K8).

## Contraintes du Sandbox

Pas d'opérateur (Keycloak, APISIX Ingress), pas de CRD, pas de service mesh (pas de mTLS entre pods) : tout en Deployments et ConfigMaps GitOps, contrôle des flux par NetworkPolicy. Quota `requests.cpu` 3 (950m utilisés le 27/09) : Keycloak, PostgreSQL, deux APISIX, Next.js et Redis tiennent, avec des requests réduites au pilote.

## Autorisation métier : Keycloak ou service dédié (ADR du 01/10)

**Keycloak gère** : authentification, fédération, utilisateurs / groupes / organisations (multi-organisation), rôles de realm et de client, rôles composites (rôle métier → permissions), contenu des tokens (audience, scopes, token limité à une API), token exchange, administration déléguée par organisation, audit.

**Un service d'autorisation dédié se justifie pour** : rôles personnalisables par organisation (administrés par le métier), gouvernance des accès (demande / approbation, séparation des tâches, attributions temporaires, délégations, recertification, rapports), autorisation sur les données à grande échelle (propriétaire, périmètre, relations : PDP OpenFGA / OPA / Cerbos), règles contextuelles (montant, état, canal), catalogue des permissions déclaré as code par les applications. **Jamais** : authentification, cycle de vie des identités, sessions, émission des tokens.

**Points à éviter** (constatés sur un microservice RBAC antérieur) : utilisateurs et groupes dupliqués avec l'IdP (référencer le `sub`), permissions lues par chaque API à chaque requête (les porter dans le token, calculées à l'émission), relation Rôle ↔ Application redondante avec Rôle → Permissions, administration non cloisonnée par organisation, utilisateur limité à une organisation.

**Décision** : modèle C au pilote. Service dédié déclenché si l'un des critères est atteint : rôles différents par organisation ; workflows d'approbation / recertification / séparation des tâches ; règles sur les données partagées par plusieurs API. Il deviendrait alors la source des permissions du token (mapper Keycloak, avec cache), les API restant inchangées.
