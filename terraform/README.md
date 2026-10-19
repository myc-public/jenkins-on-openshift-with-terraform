# Terraform - socle Jenkins/OpenShift

Provisioning de Jenkins sur OpenShift par Terraform. Les fichiers JCasC (`config/`) et l'image
(`jenkins-image/`) sont dans ce dossier : il ne dépend d'aucun autre.

## Prérequis

- `terraform.tfvars` (ignoré par Git) : `kubeconfig_path` et `kubeconfig_context` du Sandbox, obligatoires et sans
  valeur par défaut (pour empêcher un apply sur minikube) ; surcharges éventuelles des valeurs non sensibles
  décrites dans `terraform.tfvars.example`.
- Secrets : `secrets.auto.tfvars` (copie de `secrets.auto.tfvars.example`), ignoré par Git.
- L'image Jenkins doit avoir été construite au moins une fois : Terraform crée le `BuildConfig` et
  l'`ImageStream` mais ne lance pas le build (`ocs start-build jenkins --from-dir=jenkins-image --follow`).

## Utilisation

```powershell
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

Première installation (ordre imposé) : `platform-handbook`, `runbooks/reconstruction.md`, étape 3.

Après une modification de `config/*.yaml` : la ConfigMap `jenkins-jcasc` est mise à jour, mais JCasC n'est relu
qu'au démarrage de Jenkins ; un job retiré de `jobs.yaml` reste dans Jenkins et se supprime dans la console.

## Notes

- Provider OpenShift-only (Route, BuildConfig, ImageStream) : `llomgui/openshift` (communautaire,
  non maintenu depuis 2020). En cas d'échec d'init/auth contre le cluster, basculer ces ressources
  sur `kubernetes_manifest` (provider `hashicorp/kubernetes`, déjà utilisé pour le reste).
- Écarts permanents au plan sur 3 ressources : dette 18.
