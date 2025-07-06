resource "google_container_cluster" "primary" {
  name     = "devsu-demo-devops-cluster"
  location = "us-central1-a"

  deletion_protection = false

  initial_node_count     = 1
  remove_default_node_pool = true
}

resource "google_container_node_pool" "custom_pool" {
  name       = "custom-pool"
  cluster    = google_container_cluster.primary.name
  location   = google_container_cluster.primary.location

  initial_node_count = 2

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 20
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
