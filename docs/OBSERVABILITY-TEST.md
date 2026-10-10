# Test de bout en bout de l'observabilité

Vérifie la chaîne **donation-api → OTLP → otel-lgtm (Collector OTel, Tempo, Loki, Prometheus, Grafana)** et les factors *Logs as Event Streams* et *Telemetry*.
Validée sur le Sandbox le 26/09/2026 (image `1.1.0-SNAPSHOT-9420ad3-b27`). À rejouer après chaque reconstruction (`REBUILD.md`).

> **Depuis O1-5 (10/10/2026), l'API n'a plus de Route** : seule la Route `donation` (APISIX externe, WAF) est publique et `/api/v1` exige un token. Les étapes qui appellent `$api` sont à reprendre avec l'URL publique et un token `donation-service` (lot prévu après O1-6, avec la collection Postman observabilité).

Prérequis : minikube démarré (Argo CD actif), mot de passe Grafana (Secret `observability-grafana-secret`).
Commandes PowerShell. Utiliser `oc --kubeconfig ...` et non la fonction `ocs` : elle avale le `--` des `exec`.
Les API internes du pod `otel-lgtm` (Tempo `:3200`, Loki `:3100`, Prometheus `:9090`) ne sont pas exposées : on les interroge par `oc exec`.

## 0. Variables et état de la plateforme

```powershell
$kc  = "$HOME\.kube\sandbox.config"; $ns = "gregorie769-dev"
$api  = "https://" + (oc --kubeconfig $kc get route donation-api -n $ns -o jsonpath='{.spec.host}')
$graf = "https://" + (oc --kubeconfig $kc get route grafana -n $ns -o jsonpath='{.spec.host}')
function Invoke-Lgtm([string]$url) { $p = oc --kubeconfig $kc get pods -n $ns -l app.kubernetes.io/name=otel-lgtm -o jsonpath='{.items[0].metadata.name}'; oc --kubeconfig $kc exec $p -n $ns -- curl -s $url }

k --context minikube get applications -n argocd
oc --kubeconfig $kc get pods -n $ns
oc --kubeconfig $kc get configmap donation-api-config -n $ns -o jsonpath='{.data.OTLP_ENDPOINT} {.data.OTLP_EXPORT_ENABLED}'
```
Attendu : `donation-api-dev` et `observability-dev` Synced / Healthy ; `donation-api`, `donation-api-mysql`, `otel-lgtm` 1/1 ; `http://otel-lgtm:4318 true`.

## 1. Requête tracée et log stdout (Logs as Event Streams)

```powershell
curl.exe -s -o NUL -w "HTTP %{http_code}`n" "$api/api/v1/donors/00000000-0000-0000-0000-000000000000"
Start-Sleep 5
$j = (oc --kubeconfig $kc logs deploy/donation-api -n $ns --tail=100 | Select-String 'Donor not found' | Select-Object -Last 1).Line | ConvertFrom-Json
$tid = $j.traceId
[pscustomobject]@{ message = $j.message; traceId = $j.traceId; spanId = $j.spanId; pod = $j.service.node.name; version = $j.service.version; env = $j.service.environment }
```
Attendu : `HTTP 404` ; une ligne JSON ECS avec `traceId`, `spanId`, nom du pod, version et environnement `dev`.

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
$end = (Get-Date).AddSeconds(120)
while ((Get-Date) -lt $end) { curl.exe -s -o NUL "$api/api/v1/donors"; curl.exe -s -o NUL "$api/api/v1/donors/00000000-0000-0000-0000-000000000000"; Start-Sleep -Milliseconds 800 }
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
