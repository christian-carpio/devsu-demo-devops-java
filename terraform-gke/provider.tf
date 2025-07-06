terraform {
    required_providers {
        google = {
        source  = "hashicorp/google"
        version = "~> 5.0"
        }
    } 
}

provider "google" {
    project = "devsu-devops-demo"
    region  = "us-central1"
}