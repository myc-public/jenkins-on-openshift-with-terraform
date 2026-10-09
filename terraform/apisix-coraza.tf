# Image apisix-coraza (O6) : APISIX epingle + WAF Coraza (OWASP CRS) en plugin wasm, pour APISIX externe.
# Le Dockerfile reste dans gitops-platform (images/apisix-coraza), le meme que la pile locale : build depuis Git.
# Construire (ou reconstruire apres un changement du Dockerfile sur main) :
#   ocs start-build apisix-coraza --follow
# Puis reporter le digest de l'image dans gitops-platform (apps/apisix-external/overlays/dev, images: digest).
resource "openshift_image_stream" "apisix_coraza" {
  metadata {
    name      = "apisix-coraza"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "apisix-coraza"
    }
  }

  spec {}
}

resource "openshift_build_config" "apisix_coraza" {
  metadata {
    name      = "apisix-coraza"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "apisix-coraza"
    }
  }

  spec {
    source {
      type        = "Git"
      context_dir = "images/apisix-coraza"
      git {
        uri = "https://github.com/myc-public/gitops-platform.git"
        ref = "main"
      }
    }

    strategy {
      type = "Docker"

      docker_strategy {
        dockerfile_path = "Dockerfile"
      }
    }

    # Tag = versions embarquees (APISIX, coraza-proxy-wasm) ; a changer avec les ARG du Dockerfile
    output {
      to {
        kind = "ImageStreamTag"
        name = "apisix-coraza:3.19.0-coraza0.6.0"
      }
    }
  }

  depends_on = [openshift_image_stream.apisix_coraza]
}
