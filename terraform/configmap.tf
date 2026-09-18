resource "kubernetes_config_map" "jenkins_jcasc" {
  metadata {
    name      = "jenkins-jcasc"
    namespace = var.namespace
    labels = {
      "app.kubernetes.io/name" = "jenkins"
    }
  }

  data = {
    "jenkins.yaml" = file("${path.module}/config/jenkins.yaml")
    "agents.yaml"  = file("${path.module}/config/agents.yaml")
    "jobs.yaml"    = file("${path.module}/config/jobs.yaml")
  }
}