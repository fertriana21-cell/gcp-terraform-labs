# 1. VPC del Consumer
resource  "google_compute_network" "vpc_consumer" {
name = "cl-vpc-consumer-dev"
auto_create_subnetworks = false
}

# 2. Subred Principal para VMs Backend
resource "google_compute_subnetwork" "subnet_backend" {
name = "cl-sub-consumer-backend" 
ip_cidr_range = "10.20.1.0/24"
region = var.region
network = google_compute_network.vpc_consumer.id
  
}

# 3. VM de VPC consumer
resource "google_compute_instance" "vm_consumer" {
  name = "vm-consumer"
  machine_type = "e2-micro"
  zone = "us-central1-a"
  

  boot_disk {
 initialize_params {
     image = "debian-cloud/debian-12"
   } 
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet_backend.id
}

tags = ["allow-ssh"]

}

# 4. Regla de firewall para permitir trafico ssh hacia la VM
resource "google_compute_firewall" "allow_ssh" {
  name         = "allow-ssh"
  network      = google_compute_network.vpc_consumer.id
  source_ranges = ["0.0.0.0/0"]
  priority     = 1000 
  direction    = "INGRESS"
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = ["allow-ssh"]
}

# 5. Recurso para IP del endpoint del PSC

resource "google_compute_address" "psc_endpoint_ip" {
  name = "psc-endpoint-ip"
  subnetwork = google_compute_subnetwork.subnet_backend.id
  address_type = "INTERNAL"
  address = "10.20.1.50" # IP local del consumer
  region = var.region
  
}

# 6. PSC ENDPOINT (Forwarding Rule que conecta la IP local con el Service Attachment)

resource "google_compute_forwarding_rule" "psc_endpoint" {
  name = "psc-consumer-endpoint"
  region = var.region
  network = google_compute_network.vpc_consumer.id
  ip_address =  google_compute_address.psc_endpoint_ip.id 
  target = var.service_attachment_uri
  load_balancing_scheme = ""
}