resource "kubernetes_persistent_volume_claim" "jenkins_home" {
  wait_until_bound = false

  metadata {
    name      = "jenkins-home"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "jenkins"
    }
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.jenkins_home_storage_class

    resources {
      requests = {
        storage = var.jenkins_home_storage_size
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "maven_m2_cache" {
  metadata {
    name      = "maven-m2-cache"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name"      = "jenkins"
      "app.kubernetes.io/component" = "maven-cache"
    }
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = var.maven_cache_storage_class

    resources {
      requests = {
        storage = var.maven_cache_storage_size
      }
    }
  }
}