# Test de bout en bout de l'observabilité

Vérifie la chaîne **donation-api → OTLP → otel-lgtm (Collector OTel, Tempo, Loki, Prometheus, Grafana)** et les factors *Logs as Event Streams* et *Telemetry*.
Validée sur le Sandbox le 26/09/2026 (image `1.1.0-SNAPSHOT-9420ad3-b27`). À rejouer après chaque reconstruction (`REBUILD.md`).

> **Depuis O1-5 (10/10/2026), l'API n'a plus de Route** : les requêtes passent par la Route publique `donation` (APISIX externe + WAF → APISIX interne → API) et `/api/v1` exige un token. Ici : token `donation-service` (lecture seule, `donation:read`), secret lu dans `keycloak-realm-secret` sans être affiché. Collection Postman (S1 / S2) : `inner-donation-api/postman/observabilite.postman_collection.json`, environnement `e2e-sandbox`.

Prérequis : minikube démarré (Argo CD actif), mot de passe Grafana (Secret `observability-grafana-secret`).
Commandes PowerShell. Utiliser `oc --kubeconfig ...` et non la fonction `ocs` : elle avale le `--` des `exec`.
Les API internes du pod `otel-lgtm` (Tempo `:3200`, Loki `:3100`, Prometheus `:9090`) ne sont pas exposées : on les interroge par `oc exec`.

## 0. Variables et état de la plateforme

```powershell
$kc  = "$HOME\.kube\sandbox.config"; $ns = "gregorie769-dev"
$api  = "https://" + (oc --kubeconfig $kc get route donation -n $ns -o jsonpath='{.spec.host}')
$graf = "https://" + (oc --kubeconfig $kc get route grafana -n $ns -o jsonpath='{.spec.host}')
function Get-SvcToken {   # token donation-service (300 s) ; le secret reste dans une variable locale
  $b64 = oc --kubeconfig $kc get secret keycloak-realm-secret -n $ns -o jsonpath='{.data.DONATION_SERVICE_CLIENT_SECRET}'
  $s = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64))
  (Invoke-RestMethod -Method Post "$api/realms/myc-internal/protocol/openid-connect/token" -Body @{ grant_type = 'client_credentials'; client_id = 'donation-service'; client_secret = $s; scope = 'donation:read' }).access_token }
function Invoke-Lgtm([string]$url) { $p = oc --kubeconfig $kc get pods -n $ns -l app.kubernetes.io/name=otel-lgtm -o jsonpath='{.items[0].metadata.name}'; oc --kubeconfig $kc exec $p -n $ns -- curl -s $url }

k --context minikube get applications -n argocd
oc --kubeconfig $kc get pods -n $ns
oc --kubeconfig $kc get configmap donation-api-config -n $ns -o jsonpath='{.data.OTLP_ENDPOINT} {.data.OTLP_EXPORT_ENABLED}'
```
Attendu : `donation-api-dev`, `observability-dev`, `keycloak-dev`, `apisix-internal-dev`, `apisix-external-dev` Synced / Healthy ; `donation-api`, `donation-api-mysql`, `otel-lgtm`, `keycloak`, `apisix-internal`, `apisix-external` 1/1 ; `http://otel-lgtm:4318 true`.

## 1. Requête tracée et log stdout (Logs as Event Streams)

```powershell
$tok = Get-SvcToken
curl.exe -s -o NUL -w "HTTP %{http_code}`n" -H "Authorization: Bearer $tok" "$api/api/v1/donors/00000000-0000-0000-0000-000000000000"
Start-Sleep 5
$j = (oc --kubeconfig $kc logs deploy/donation-api -n $ns --tail=100 | Select-String 'Donor not found' | Select-Object -Last 1).Line | ConvertFrom-Json
$tid = $j.traceId
[pscustomobject]@{ message = $j.message; traceId = $j.traceId; spanId = $j.spanId; pod = $j.service.node.name; version = $j.service.version; env = $j.service.environment }
```
Attendu : `HTTP 404` ; une ligne JSON ECS avec `traceId`, `spanId`, nom du pod, version et environnement `dev`.

## 1 bis. Scénarios S1 / S2 (Newman)

Collection `inner-donation-api/postman/observabilite.postman_collection.json` : S1 parcours nominal (30 donateurs et dons), S2 erreurs 4xx (15 cas). Token `donation-tests` (dev uniquement) obtenu par la collection. Newman plutôt que le Runner : Postman gratuit n'accepte pas les data files. Newman 6.2.1 minimum (`pm.execution.skipRequest` utilisé par S2).
```powershell
cd D:\workspace\public\inner-donation-api\postman
$b64 = oc --kubeconfig $kc get secret keycloak-realm-secret -n $ns -o jsonpath='{.data.DONATION_TESTS_CLIENT_SECRET}'
$sec = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)); "longueur du secret : $($sec.Length)"
npx --yes newman@6.2.1 run observabilite.postman_collection.json -e e2e-sandbox.postman_environment.json --env-var "donationTestsClientSecret=$sec" `
  --folder "S1 - Parcours nominal (data : observabilite-s1-nominal.data.json)" -d observabilite-s1-nominal.data.json
npx --yes newman@6.2.1 run observabilite.postman_collection.json -e e2e-sandbox.postman_environment.json --env-var "donationTestsClientSecret=$sec" `
  --folder "S2 - Erreurs 4xx (data : observabilite-s2-erreurs.data.json)" -d observabilite-s2-erreurs.data.json
Remove-Variable sec, b64
```
Attendu : S1 180 / 180 assertions ; S2 15 / 15 (dans chaque itération, une seule requête exécutée, les autres sautées). Ne pas ajouter `--export-environment` : le secret serait écrit sur disque.
Le cas S2 `Content-Type text/plain` est refusé par le WAF (403, règle CRS 920420) avant l'API : absent des métriques et des traces de l'API, visible dans les logs d'APISIX externe.

## 2. Trace dans Tempo (Telemetry — traces)

Attendre ~10 s (export par lots toutes les 5 s).
```powershell
$t = Invoke-Lgtm "http://localhost:3200/api/traces/$tid" | ConvertFrom-Json
@($t.batches) | ForEach-Object { $_.scopeSpans.spans } | Sort-Object { [double]$_.startTimeUnixNano } |
  ForEach-Object { "{0,-40} {1,6} ms" -f $_.name, [math]::Round(([double]$_.endTimeUnixNano - [double]$_.startTimeUnixNano)/1e6,1) }
```
Attendu : 5 spans — `http get /api/v1/donors/{donorId}` (racine), `security filterchain before`, `authorize request`, `secured request`, `security filterchain after`.

## 3. Même événement dans Loki, par `trace_id` (Logs — acheminement, corrélation)

```powershell
$q = [uri]::EscapeDataString('{service_name="inner-donation-api"} | trace_id="' + $tid + '"')
(Invoke-Lgtm "http://localhost:3100/loki/api/v1/query_range?query=$q&limit=5&since=15m" | ConvertFrom-Json).data.result |
  ForEach-Object { "labels: service=$($_.stream.service_name) env=$($_.stream.deployment_environment_name) level=$($_.stream.severity_text)"; $_.values | ForEach-Object { "log: $($_[1])" } }
```
Attendu : `service=inner-donation-api env=dev level=INFO` ; `log: Resource not found: Donor not found: 00000000-...`.

## 4. Métriques dans Prometheus (Telemetry — métriques)

`rate()` exige du trafic **étalé** sur plusieurs envois (un toutes les 30 s) : 2 minutes de charge.
```powershell
$tok = Get-SvcToken; $auth = "Authorization: Bearer $tok"   # token neuf : valable 300 s, la charge dure 120 s
$end = (Get-Date).AddSeconds(120)
while ((Get-Date) -lt $end) { curl.exe -s -o NUL -H $auth "$api/api/v1/donors"; curl.exe -s -o NUL -H $auth "$api/api/v1/donors/00000000-0000-0000-0000-000000000000"; Start-Sleep -Milliseconds 800 }
Start-Sleep 35
foreach ($m in @(
  @('Debit (req/s)', 'sum by (uri, status) (rate(http_server_requests_milliseconds_count{service_name="inner-donation-api", uri!~"/management.*"}[2m]))'),
  @('Latence p95 (ms)', 'histogram_quantile(0.95, sum by (le, uri) (rate(http_server_requests_milliseconds_bucket{service_name="inner-donation-api", uri!~"/management.*"}[2m])))'),
  @('Heap JVM (Mo)', 'sum(jvm_memory_used_bytes{service_name="inner-donation-api", area="heap"}) / 1048576'),
  @('Connexions DB actives', 'hikaricp_connections_active{service_name="inner-donation-api"}'))) {
  "=== $($m[0])"; $q = [uri]::EscapeDataString($m[1])
  (Invoke-Lgtm "http://localhost:9090/api/v1/query?query=$q" | ConvertFrom-Json).data.result | ForEach-Object { "  $($_.metric.uri) $($_.metric.status) -> $([math]::Round([double]$_.value[1],3))" } }
```
Attendu : débit ~0,38 req/s par route (200 et 404) ; p95 ~10-15 ms ; heap et connexions DB renseignés. Les sondes `/management/**` sont exclues.

## 5. Sécurité de la stack

```powershell
curl.exe -s -o NUL -w "Grafana anonyme /api/datasources -> %{http_code}`n" "$graf/api/datasources"
curl.exe -s -o NUL -w "OTLP via la Route (/v1/traces)   -> %{http_code}`n" -X POST "$graf/v1/traces"
```
Attendu : **401** (anonyme refusé) ; **302** (redirection login : l'OTLP n'est pas exposé publiquement).

## 6. Parcours Grafana (manuel, démo)

1. Ouvrir `$graf`, se connecter avec le compte admin.
2. **Explore → Loki** : `{service_name="inner-donation-api"} | json` (filtres `severity_text`, `trace_id`).
3. Depuis un log, ouvrir la trace par son `trace_id` (sinon : coller le `trace_id` dans **Explore → Tempo → TraceQL**).
4. **Explore → Tempo → Search** : `service.name = inner-donation-api`.
5. **Dashboards** : JVM et RED fournis par l'image (non encore vérifiés avec nos labels — phase 4).

## 7. Résilience (optionnel)

Supprimer le pod `otel-lgtm` (console OpenShift) ou laisser l'idler du Sandbox le recycler : Argo / le ReplicaSet le recrée, les données antérieures restent (PVC), l'API n'est pas impactée (les exports échouent sans bloquer les requêtes).
