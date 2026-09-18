resource "kubernetes_service" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "jenkins"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      "app.kubernetes.io/name" = "jenkins"
    }

    port {
      name        = "http"
      port        = 8080
      target_port = "http"
    }

    port {
      name        = "agent"
      port        = 50000
      target_port = "agent"
    }
  }
}