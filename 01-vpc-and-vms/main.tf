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

  
tags=["allow-ssh"]
}

# 5. Regla de firewall para permitir trafico SSH a una VM
resource "google_compute_firewall" "allow_ssh" {
  name         = "allow-ssh"
  network      = google_compute_network.vpc_network.id
  source_ranges = ["0.0.0.0/0"]
  source_ranges = ["35.235.240.0/20"] # Permite túneles SSH de Identity-Aware Proxy (IAP)
  priority     = 1000 

# 7. Cloud Router (Requerido para el funcionamiento de Cloud NAT)
resource "google_compute_router" "router" {
  name    = "cl-router-lab-dev-01"
  region  = "us-central1"
  network = google_compute_network.vpc_network.id
}

# 8. Puerta de enlace Cloud NAT
resource "google_compute_router_nat" "nat" {
  name                               = "cl-nat-lab-dev-01"
  router                             = google_compute_router.router.name
  region                             = "us-central1"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
  direction    = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["allow-ssh"]
}

# 6. Regla de firewall para permitir trafico HTTPS a una VM desde internet
resource "google_compute_firewall" "allow_http" {
  name         = "allow-http"
  network      = google_compute_network.vpc_network.id
  source_ranges = ["0.0.0.0/0"]
  priority     = 1000 
  direction    = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  target_tags = ["allow-ssh"]
}
