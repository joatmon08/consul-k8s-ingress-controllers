terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.55"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

