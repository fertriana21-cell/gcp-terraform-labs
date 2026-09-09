terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = "cl-demo-learn-507500"
  region  = "us-central1"
  zone    = "us-central1-a"
}

# 1. Red VPC Principal
resource "google_compute_network" "vpc_network" {
  name                    = "cl-vpc-lab-dev-01"
  auto_create_subnetworks = false
}

# 2. Subred Zona A
resource "google_compute_subnetwork" "subnet_uc1a" {
  name          = "cl-sub-lab-dev-uc1a-01"
  ip_cidr_range = "10.0.1.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
}

# 3. Subred Zona B
resource "google_compute_subnetwork" "subnet_uc1b" {
  name          = "cl-sub-lab-dev-uc1b-01"
  ip_cidr_range = "10.0.2.0/24"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
}

# 4. Instancia de VM en la Subred Zona A
resource "google_compute_instance" "vm_lab_dev_01" {
  name         = "cl-vm-lab-dev-uc1a-01"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_uc1a.id

    access_config {
    }
  }
}
