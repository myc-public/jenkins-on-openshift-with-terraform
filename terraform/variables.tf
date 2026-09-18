variable "kubeconfig_path" {
  description = "Chemin du kubeconfig utilisé pour se connecter au cluster OpenShift (session déjà ouverte via `oc login`)."
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "Contexte kubeconfig à utiliser. Laisser vide (null) pour utiliser le contexte courant."
  type        = string
  default     = null
}

variable "namespace" {
  description = "Namespace OpenShift pré-provisionné par le Developer Sandbox Red Hat."
  type        = string
  default     = "gregorie769-dev"
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