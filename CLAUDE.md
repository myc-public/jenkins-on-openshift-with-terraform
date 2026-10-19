# jenkins-on-openshift-with-terraform

Jenkins as code sur le Sandbox OpenShift (Terraform, JCasC, Job DSL) et documentation du Nexus local. Lire
d'abord [README.md](README.md). Règles communes du socle : `platform-handbook`.

## Commandes

- `cd terraform` ; `terraform plan -out=tfplan` ; `terraform apply tfplan` (jamais d'`apply` sans plan relu).
- Image Jenkins : `ocs start-build jenkins --from-dir=jenkins-image --follow`.

## Règles propres à ce dépôt

- Ne jamais modifier une ligne (Terraform, JCasC, Job DSL, Dockerfile) sans présenter l'avant / après et
  attendre la confirmation explicite sur le fichier concerné.
- Tout passe par Terraform : aucune ressource créée ou modifiée à la main avec `oc` (sauf `start-build`).
- Aucune valeur secrète dans un `.tf`, un `.yaml` ou un exemple : `secrets.auto.tfvars` (ignoré) et `${VAR}` dans
  JCasC. Ne jamais afficher ni écraser `secrets.auto.tfvars`, `terraform.tfvars` ou un `*.tfstate`.
- Nouveau job : un bloc dans `terraform/config/jobs.yaml`, pipeline `cicd/Jenkinsfile-ci` dans le dépôt cible.
- `README_local.md` contient des secrets (dette 23) : ne pas le lire, ne rien en recopier.
