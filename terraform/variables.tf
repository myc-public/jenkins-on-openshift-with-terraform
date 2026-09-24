variable "kubeconfig_path" {
  description = "Chemin du kubeconfig utilisé pour se connecter au cluster OpenShift (session déjà ouverte via `oc login`). Obligatoire : pas de valeur par défaut, pour empêcher un apply accidentel sur ~/.kube/config (contexte minikube)."
  type        = string
}

variable "kubeconfig_context" {
  description = "Contexte kubeconfig à utiliser. Obligatoire : pas de valeur par défaut, pour empêcher un apply accidentel sur le contexte kubectl courant."
  type        = string
}

variable "namespace" {
  description = "Namespace OpenShift pré-provisionné par le Developer Sandbox Red Hat."
  type        = string
  default     = "gregorie769-dev"
}

variable "apps_domain" {
  description = "Domaine des Routes du cluster (change avec le cluster) : l'URL Jenkins en est deduite."
  type        = string
  default     = "apps.rm3.7wse.p1.openshiftapps.com"
}

variable "jenkins_image" {
  description = "Image Jenkins produite par le BuildConfig (ImageStreamTag interne)."
  type        = string
  default     = "image-registry.openshift-image-registry.svc:5000/gregorie769-dev/jenkins:latest"
}

variable "sonar_server_url" {
  description = "URL du serveur SonarQube/SonarCloud."
  type        = string
  default     = "https://sonarcloud.io"
}

variable "smtp_host" {
  type    = string
  default = "smtp.gmail.com"
}

variable "smtp_port" {
  type    = string
  default = "465"
}

variable "jenkins_home_storage_class" {
  type    = string
  default = "gp3"
}

variable "jenkins_home_storage_size" {
  type    = string
  default = "10Gi"
}

variable "maven_cache_storage_class" {
  type    = string
  default = "efs-sc"
}

variable "maven_cache_storage_size" {
  type    = string
  default = "5Gi"
}

# --- Secrets : jamais de valeur réelle ici. Fournir au apply via TF_VAR_<nom> ---

variable "jenkins_admin_password" {
  description = "Mot de passe admin Jenkins. À fournir via TF_VAR_jenkins_admin_password."
  type        = string
  sensitive   = true
}

variable "sonar_token" {
  description = "Token d'authentification SonarQube/SonarCloud. À fournir via TF_VAR_sonar_token."
  type        = string
  sensitive   = true
}

variable "smtp_username" {
  description = "Utilisateur SMTP. À fournir via TF_VAR_smtp_username."
  type        = string
  sensitive   = true
}

variable "smtp_password" {
  description = "Mot de passe SMTP. À fournir via TF_VAR_smtp_password."
  type        = string
  sensitive   = true
}

variable "nexus_username" {
  description = "Utilisateur Nexus. À fournir via TF_VAR_nexus_username."
  type        = string
  sensitive   = true
}

variable "nexus_password" {
  description = "Mot de passe/token Nexus. À fournir via TF_VAR_nexus_password."
  type        = string
  sensitive   = true
}

variable "nexus_url" {
  description = "URL de base de Nexus (tunnel Cloudflare), sans slash final. Source unique : injectée en variable d'environnement NEXUS_URL dans Jenkins et ses builds."
  type        = string
}


variable "gitops_git_username" {
  description = "Utilisateur Git du depot GitOps (compte de service dedie). A fournir via TF_VAR_gitops_git_username."
  type        = string
  sensitive   = true
}

variable "gitops_git_token" {
  description = "Token Git (droits push sur le depot GitOps uniquement). A fournir via TF_VAR_gitops_git_token."
  type        = string
  sensitive   = true
}
