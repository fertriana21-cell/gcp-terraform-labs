# 1. VPC del Productor
resource  "google_compute_network" "vpc_producer" {
name = "cl-vpc-producer-dev"
auto_create_subnetworks = false
}

# 1. Subred Principal para VMs Backend
resource "google_compute_subnetwork" "subnet_backend" {
name = "cl-sub-producer-backend" 
ip_cidr_range = "10.10.1.0/24"
region = var.region
network = google_compute_network.vpc_producer.id
  
}

# 2. SUBRED CLAVE: PSC NAT Subnet (Especial para PSC)
resource "google_compute_subnetwork" "subnet_psc_nat" {
name = "cl-sub-producer-psc-nat"
ip_cidr_range = "10.10.100.0/24"
region = var.region
network = google_compute_network.vpc_producer.id
purpose = "PRIVATE_SERVICE_CONNECT"

}

# 3. Firewalls Internos
resource "google_compute_firewall" "allow_producer_internal" {
name = "allow-producer-internal"
network = google_compute_network.vpc_producer.id
allow {
  protocol = "TCP"
  ports = ["80", "22"]
}
source_ranges = ["10.10.1.0/24", "10.10.100.0/24", "35.191.0.0/16", "130.211.0.0/22"]
}

# 4. regla de firewall para habilitar el health check de los load balancers desde la API de google.allow 
resource "google_compute_firewall" "allow-health_checks" {
  name = "allow-health-check-ilb"
  network = google_compute_network.vpc_producer.id
allow {
  protocol = "TCP"
  ports = ["80"]
}
 source_ranges = ["130.211.0.0/22", "35.191.0.0/16"] 
}

# 5. Regla para permitir trafico IAP
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh"
  network = google_compute_network.vpc_producer.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
}

# 6. Template para la VM Backend 
resource "google_compute_instance_template" "producer_template" {
name_prefix = "producer-template"
machine_type = "e2-micro"
region = var.region

disk {
  source_image = "debian-cloud/debian-12"
  auto_delete = true
  boot = true
}
network_interface {
  subnetwork = google_compute_subnetwork.subnet_backend.id
}

metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update && apt-get install -y nginx
    echo "<h1>Hola desde el Servicio Productor de PSC 🚀</h1>" > /var/www/html/index.html
    systemctl restart nginx
  EOF
  lifecycle {
    create_before_destroy = true
  }
}

  # 7. Instance Group Manager (Unizona para ahorrar créditos)

resource "google_compute_instance_group_manager" "producer_mig" {
    name = "producer-mig"
  zone = "${var.region}-a"
  base_instance_name = "producer-srv"
  target_size = 1
  version {
    instance_template = google_compute_instance_template.producer_template.id
  }
  named_port {
    name = "http"
    port = 80
  }

}


# 8. Internal Load Balancer (ILB L4 TCP)

resource "google_compute_health_check" "ilb_hc" {
  name = "produces-ilb-hc"
  http_health_check {
    port = 80
  }
}


resource "google_compute_region_backend_service" "ilb_backend"{
  name = "producer-ilb-backend"
  region = var.region
  protocol = "TCP"
  load_balancing_scheme = "INTERNAL"
  health_checks = [google_compute_health_check.ilb_hc.id]
  backend {
    group = google_compute_instance_group_manager.producer_mig.instance_group
    balancing_mode = "CONNECTION"

  }
}



resource "google_compute_forwarding_rule" "ilb_forwarding_rule" {
  name = "producer-ilb-forwarding-rule"
  region = var.region
  network = google_compute_network.vpc_producer.id
  subnetwork = google_compute_subnetwork.subnet_backend.id
  load_balancing_scheme = "INTERNAL"
  backend_service = google_compute_region_backend_service.ilb_backend.id 
  ports = ["80"]
  ip_protocol = "TCP"
}

# 9. SERVICE ATTACHMENT DE PSC
resource "google_compute_service_attachment" "namepsc_provider" {
name = "cl-psc-service-attachment"
region = var.region
description = "Service Attachment para publicar nuestro servicio privado via PSC"
enable_proxy_protocol = false
connection_preference = "ACCEPT_AUTOMATIC" # Acepta cualquier conexión automáticamente
nat_subnets = [google_compute_subnetwork.subnet_psc_nat.id]
target_service = google_compute_forwarding_rule  .ilb_forwarding_rule.id
}

# 10. Cloud router y cloud nat habilitados para dar salida a internet a las VMs
resource "google_compute_router" "producer_router" {
  name    = "cl-router-producer"
  region  = var.region
  network = google_compute_network.vpc_producer.id
}

resource "google_compute_router_nat" "producer_nat" {
  name                               = "cl-nat-producer"
  router                             = google_compute_router.producer_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}