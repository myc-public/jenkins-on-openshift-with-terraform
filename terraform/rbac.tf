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

  # Build d'image (BuildConfig binaire) et tag immuable dans le registry interne
  rule {
    api_groups = ["build.openshift.io"]
    resources  = ["buildconfigs"]
    verbs      = ["get", "list", "create", "update", "patch"]
  }

  rule {
    api_groups = ["build.openshift.io"]
    resources  = ["buildconfigs/instantiate", "buildconfigs/instantiatebinary"]
    verbs      = ["create"]
  }

  rule {
    api_groups = ["build.openshift.io"]
    resources  = ["builds"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["build.openshift.io"]
    resources  = ["builds/log"]
    verbs      = ["get"]
  }

  rule {
    api_groups = ["image.openshift.io"]
    resources  = ["imagestreams", "imagestreamtags"]
    verbs      = ["get", "list", "create", "update", "patch"]
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
