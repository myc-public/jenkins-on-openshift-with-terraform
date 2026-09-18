terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    openshift = {
      source  = "llomgui/openshift"
      version = "1.1.0"
    }
  }
}
