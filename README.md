# jenkins-on-openshift-with-terraform

Jenkins as code sur le Sandbox OpenShift (namespace `gregorie769-dev`) : Terraform crée le contrôleur, sa
configuration (JCasC, Job DSL), son image et ses secrets ; les builds tournent sur des agents Kubernetes éphémères.
Le dépôt documente aussi le Nexus local qui sert d'unique accès aux dépendances Maven et npm.
Vue d'ensemble du socle : [platform-handbook](https://github.com/myc-public/platform-handbook).

Remplace depuis le 18/09/2026 le socle Kustomize `jenkins-on-openshift-manifests` (archivé).

## Contenu

| Chemin | Rôle |
|---|---|
| [`terraform/`](terraform/README.md) | RBAC, PVC, BuildConfig et ImageStream (Jenkins, `apisix-coraza`), ConfigMap JCasC, Secrets, Deployment, Service, Route |
| `terraform/config/` | JCasC : `jenkins.yaml` (sécurité, credentials, Sonar, fichier `nexus-maven-settings`), `agents.yaml` (pod templates), `jobs.yaml` (Job DSL) |
| `terraform/jenkins-image/` | Image Jenkins (Dockerfile, `plugins.txt`) |
| [`docs/nexus.md`](docs/nexus.md) | Nexus local, tunnel Cloudflare, contrôle de la liaison Jenkins -> Nexus |
| `nexus/` | Définitions de dépôts Nexus (`npm-proxy.json`) |
| `docs/ROADMAP.md` | Page de renvoi vers `platform-handbook` |

## Jobs

| Job | Dépôt | Pipeline |
|---|---|---|
| `inner-donation-api` | `inner-donation-api` | `cicd/Jenkinsfile-ci` |
| `web-bff` | `web-bff` | `cicd/Jenkinsfile-ci` |
| `donation-web` | `donation-web` | `cicd/Jenkinsfile-ci` |
| `gen-ai-api` | `gen-ai-api` | `cicd/Jenkinsfile-ci`, absent du dépôt (dette 24) |

Credentials déclarés par JCasC (valeurs passées par Terraform, jamais dans Git) : `sonarqube-token`,
`nexus-credentials`, `gitops-git-credentials` ; fichier Maven `nexus-maven-settings`. Un job retiré de `jobs.yaml` n'est pas supprimé de Jenkins : le supprimer dans la console.

## Utiliser

```powershell
cd D:\workspace\public\jenkins-on-openshift-with-terraform\terraform
# Une seule fois (ne jamais écraser un fichier existant), puis renseigner les valeurs
if (-not (Test-Path secrets.auto.tfvars)) { Copy-Item secrets.auto.tfvars.example secrets.auto.tfvars }
terraform init
terraform plan -out=jenkins.tfplan
terraform apply jenkins.tfplan
Remove-Item jenkins.tfplan     # le plan contient les valeurs des variables, secrets compris
```

- Première installation sur un cluster (ordre : BuildConfig, image, puis le reste) :
  [reconstruction.md](https://github.com/myc-public/platform-handbook/blob/develop/runbooks/reconstruction.md), étape 3.
- Jenkins mis à 0 par la mise en veille du Sandbox :
  [reprise-session.md](https://github.com/myc-public/platform-handbook/blob/develop/runbooks/reprise-session.md).

## Configuration

Fichiers ignorés par Git : `terraform/secrets.auto.tfvars` (mots de passe et jetons ; `nexus_url` change avec le
tunnel), `terraform/terraform.tfvars` (`kubeconfig_path`, `kubeconfig_context`, obligatoires), `*.tfstate`. Modèles : `*.example`. Variables et valeurs par
défaut : [`terraform/variables.tf`](terraform/variables.tf).

## Liens

- Roadmap CI/CD et dettes (3, 4, 5, 18, 19, 23, 24) :
  [roadmap/cicd.md](https://github.com/myc-public/platform-handbook/blob/develop/roadmap/cicd.md),
  [dettes.md](https://github.com/myc-public/platform-handbook/blob/develop/dettes.md).
