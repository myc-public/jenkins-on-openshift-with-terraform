resource "openshift_image_stream" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "jenkins"
    }
  }

  spec {}
}

resource "openshift_build_config" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "jenkins"
    }
  }

  spec {
    source {
      type = "Binary"
    }

    strategy {
      type = "Docker"

      docker_strategy {
        dockerfile_path = "Dockerfile"
      }
    }

    output {
      to {
        kind = "ImageStreamTag"
        name = "jenkins:latest"
      }
    }
  }
}