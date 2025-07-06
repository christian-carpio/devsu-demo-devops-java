output "kubernetes_cluster_name" {
  description = "The name of the Kubernetes cluster created in GKE"
  value       = google_container_cluster.primary.name
}

output "kubernetes_cluster_location" {
  description = "The location of the Kubernetes cluster created in GKE"
  value       = google_container_cluster.primary.location
}
