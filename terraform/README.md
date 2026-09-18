# Terraform - socle Jenkins/OpenShift

Provisioning Jenkins sur OpenShift par Terraform. Arborescence complètement autonome, sans
dépendance vers `openshift-manifests/` (l'autre façon de provisionner, par Kustomize) : les
fichiers JCasC (`config/`) et l'image (`jenkins-image/`) sont des copies locales.

## Prérequis

- Session `oc login` déjà ouverte (le kubeconfig courant sert d'authentification).
- L'image Jenkins doit avoir été buildée au moins une fois :
  `oc start-build jenkins --from-dir=./jenkins-image --follow`
  (Terraform crée le `BuildConfig`/`ImageStream`, il ne déclenche pas le build).

## Utilisation

```bash
cd terraform
terraform init

export TF_VAR_jenkins_admin_password="..."
export TF_VAR_sonar_token="..."
export TF_VAR_smtp_username="..."
export TF_VAR_smtp_password="..."

terraform plan
terraform apply
```

## Notes

- Provider OpenShift-only (Route, BuildConfig, ImageStream) : `llomgui/openshift` (communautaire,
  non maintenu depuis 2020). En cas d'échec d'init/auth contre le cluster, basculer ces 3 ressources
  sur `kubernetes_manifest` (provider `hashicorp/kubernetes`, déjà utilisé pour le reste).
- Les fichiers JCasC (`config/jenkins.yaml`, `config/agents.yaml`, `config/jobs.yaml`) et
  `jenkins-image/` sont des copies indépendantes de celles utilisées par `openshift-manifests/`.
  Toute modification doit être répercutée manuellement des deux côtés tant que les deux arbres
  vivent dans le même repo.