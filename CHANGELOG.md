# Changelog

## 2026-09-18 — Migration Terraform + arborescences indépendantes

- Ajout d'un provisioning Terraform complet du socle Jenkins (`terraform/`), équivalent
  fonctionnel de l'ancien socle Kustomize : RBAC, PVC (`jenkins-home`, `maven-m2-cache`
  importées sans perte d'historique), BuildConfig/ImageStream (provider communautaire
  `llomgui/openshift`), ConfigMap JCasC, Secrets (valeurs injectées via `TF_VAR_*`,
  jamais commitées), Deployment, Service, Route.
- Cutover effectué sur le namespace `gregorie769-dev` : ancien socle supprimé (hors PVC),
  nouveau socle appliqué via `terraform apply`. Vérifié : pod Jenkins sain, jobs Job DSL
  présents, credentials (`github-jenkins`, `sonarqube-token`) préservées, agents Kubernetes
  éphémères fonctionnels.
- Restructuration en deux arborescences **totalement indépendantes**, en vue d'une scission
  future en deux projets séparés : `openshift/` renommé en `openshift-manifests/`, et
  `terraform/` doté de ses propres copies de `jenkins-image/` et des fichiers JCasC
  (`config/jenkins.yaml`, `agents.yaml`, `jobs.yaml`) — plus aucune référence croisée entre
  les deux arbres. Suppression du `kustomization.yaml` racine (point de couplage).
- Correctif applicatif : `scriptPath` des jobs `gen-ai-api` et `inner-order-api` mis à jour
  de `cicd/Jenkinsfile` vers `cicd/Jenkinsfile-ci` (renommage effectué côté repos
  applicatifs), répercuté dans les deux copies de `jobs.yaml`.
- Point de vigilance ouvert : secrets historiques (PAT GitHub, token `oc login`, token
  SonarCloud, mot de passe SMTP) toujours présents dans l'historique git malgré le
  renommage de `README.md` en `README_local.md` — à révoquer/régénérer et à purger de
  l'historique.