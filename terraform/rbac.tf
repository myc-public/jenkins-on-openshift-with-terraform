resource "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "controller"
    }
  }
}

resource "kubernetes_role" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "jenkins"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch", "create", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/exec"]
    verbs      = ["get", "create"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list", "watch"]
  }
}

resource "kubernetes_role_binding" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "jenkins"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.jenkins.metadata[0].name
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.jenkins.metadata[0].name
  }
}