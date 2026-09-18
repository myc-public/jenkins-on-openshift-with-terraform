output "jenkins_route_host" {
  description = "Hostname exposé par la Route Jenkins."
  value       = try(openshift_route.jenkins.spec[0].host, null)
}

output "jenkins_service_name" {
  value = kubernetes_service.jenkins.metadata[0].name
}