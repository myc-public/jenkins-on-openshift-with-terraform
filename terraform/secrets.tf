resource "kubernetes_secret" "jenkins_admin" {
  metadata {
    name      = "jenkins-admin"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "jenkins"
    }
  }

  type = "Opaque"

  data = {
    password = var.jenkins_admin_password
  }
}

resource "kubernetes_secret" "jenkins_smtp" {
  metadata {
    name      = "jenkins-smtp"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "jenkins"
    }
  }

  type = "Opaque"

  data = {
    username = var.smtp_username
    password = var.smtp_password
  }
}

resource "kubernetes_secret" "jenkins_sonar" {
  metadata {
    name      = "jenkins-sonar"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "jenkins"
    }
  }

  type = "Opaque"

  data = {
    token = var.sonar_token
  }
}