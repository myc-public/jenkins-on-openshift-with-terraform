# Nexus local et tunnel

Toute dépendance passe par Nexus : Maven Central (ou npm) -> proxy Nexus -> dépôt Nexus -> `~/.m2` de Jenkins ->
build. Nexus tourne en conteneur Docker sur le poste ; Jenkins (Sandbox OpenShift) l'atteint par un tunnel
Cloudflare. Règles Maven : `artifacts-manager` (`settings.xml`).

## Éléments

| Élément | Valeur |
|---|---|
| Conteneur | `nexus`, port local 8081 |
| Données | volume Docker `nexus-data` (sauvegardé par [sauvegarde.md](https://github.com/myc-public/platform-handbook/blob/develop/runbooks/sauvegarde.md), étape 6) |
| Dépôts | `maven-public` (groupe), `maven-central` (proxy), `maven-releases`, `maven-snapshots` ; `npm-proxy` ([`nexus/npm-proxy.json`](../nexus/npm-proxy.json)) |
| Identifiants | compte Nexus dédié à Jenkins ; valeurs dans `terraform/secrets.auto.tfvars` (hors Git) |
| URL vue par Jenkins | celle du tunnel, dans `nexus_url` de `terraform/secrets.auto.tfvars` |

Création du conteneur (une seule fois, ou après sa suppression ; les données vivent dans le volume `nexus-data`) :
```powershell
if (-not (docker ps -a --filter name=^nexus$ --format '{{.Names}}')) {
  docker run -d --name nexus -p 8081:8081 -v nexus-data:/nexus-data sonatype/nexus3:3.96.2 }
```
Version épinglée : celle des données du volume (relevée le 29/10 par `docker inspect nexus`, conteneur créé le 20/09 en
`latest`). Monter de version est une migration de Nexus, irréversible : sauvegarder le volume avant.

## Démarrer

```powershell
docker start nexus
curl.exe -s -o NUL -w "local: %{http_code}`n" http://localhost:8081/service/rest/v1/status    # 200 attendu
cloudflared tunnel --url http://localhost:8081
```

Le tunnel rapide donne une nouvelle URL à chaque lancement (dette 3) : la reporter dans `nexus_url`, puis
`terraform apply` (la variable `NEXUS_URL` de Jenkins en dépend).

## Contrôler la liaison Jenkins -> Nexus

Du poste vers Jenkins ; `$u` = URL du tunnel. Les identifiants restent dans le pod, jamais affichés.

```powershell
$u = 'https://<tunnel>.trycloudflare.com'
# 1. Nexus répond sur le poste
curl.exe -s -o NUL -w "local: %{http_code}`n" http://localhost:8081/service/rest/v1/status
# 2. Le tunnel répond
curl.exe -s -o NUL -w "tunnel: %{http_code}`n" "$u/service/rest/v1/status"
# 3. Jenkins atteint Nexus
ocs exec deploy/jenkins -- curl -s -o /dev/null -w '%{http_code}' "$u/service/rest/v1/status"
# 4. Les identifiants de Jenkins sont acceptés
ocs exec deploy/jenkins -- sh -c "curl -s -o /dev/null -w %{http_code} -u `$NEXUS_USERNAME:`$NEXUS_PASSWORD $u/service/rest/v1/repositories"
```

| Résultat | Cause probable |
|---|---|
| 1 échoue | conteneur `nexus` arrêté |
| 1 passe, 2 échoue | `cloudflared` arrêté, ou URL changée (530 / 502) |
| 1 et 2 passent, 3 échoue | sortie réseau bloquée côté OpenShift |
| 4 renvoie 401 | identifiants du secret Jenkins différents de ceux de Nexus |
