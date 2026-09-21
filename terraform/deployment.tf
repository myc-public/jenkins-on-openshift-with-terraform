resource "kubernetes_deployment" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "controller"
    }
  }

  spec {
    replicas = 1

    strategy {
      type = "Recreate"
    }

    selector {
      match_labels = {
        "app.kubernetes.io/name" = "jenkins"
      }
    }

    template {
      metadata {
        labels = {
          "app.kubernetes.io/name"      = "jenkins"
          "app.kubernetes.io/component" = "controller"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.jenkins.metadata[0].name

        security_context {
          run_as_non_root = true
        }

        container {
          name              = "jenkins"
          image             = var.jenkins_image
          image_pull_policy = "Always"

          port {
            name           = "http"
            container_port = 8080
          }

          port {
            name           = "agent"
            container_port = 50000
          }

          env {
            name  = "CASC_JENKINS_CONFIG"
            value = "/var/jenkins_home/casc_configs"
          }

          env {
            name = "JENKINS_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.jenkins_admin.metadata[0].name
                key  = "password"
              }
            }
          }

          env {
            name  = "JAVA_OPTS"
            value = "-Djenkins.install.runSetupWizard=false"
          }

          env {
            name  = "SONAR_SERVER_URL"
            value = var.sonar_server_url
          }

          env {
            name = "SONAR_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.jenkins_sonar.metadata[0].name
                key  = "token"
              }
            }
          }

          env {
            name  = "NEXUS_URL"
            value = var.nexus_url
          }

          env {
            name = "NEXUS_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.jenkins_nexus.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "NEXUS_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.jenkins_nexus.metadata[0].name
                key  = "password"
              }
            }
          }

          env {
            name = "GITOPS_GIT_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.jenkins_gitops.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "GITOPS_GIT_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.jenkins_gitops.metadata[0].name
                key  = "token"
              }
            }
          }

          env {
            name  = "SMTP_HOST"
            value = var.smtp_host
          }

          env {
            name  = "SMTP_PORT"
            value = var.smtp_port
          }

          env {
            name = "SMTP_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.jenkins_smtp.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "SMTP_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.jenkins_smtp.metadata[0].name
                key  = "password"
              }
            }
          }

          resources {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "2"
              memory = "2Gi"
            }
          }

          volume_mount {
            name       = "jenkins-home"
            mount_path = "/var/jenkins_home"
          }

          volume_mount {
            name       = "jcasc"
            mount_path = "/var/jenkins_home/casc_configs"
          }

          readiness_probe {
            http_get {
              path = "/login"
              port = "http"
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 12
          }

          liveness_probe {
            http_get {
              path = "/login"
              port = "http"
            }
            initial_delay_seconds = 120
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 6
          }
        }

        volume {
          name = "jenkins-home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.jenkins_home.metadata[0].name
          }
        }

        volume {
          name = "jcasc"
          config_map {
            name = kubernetes_config_map.jenkins_jcasc.metadata[0].name
          }
        }
      }
    }
  }
}