resource "openshift_route" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "jenkins"
    }
  }

  spec {
    to {
      kind = "Service"
      name = kubernetes_service.jenkins.metadata[0].name
    }

    port {
      target_port = "http"
    }

    tls {
      termination                      = "edge"
      insecure_edge_termination_policy = "Redirect"
    }
  }
}