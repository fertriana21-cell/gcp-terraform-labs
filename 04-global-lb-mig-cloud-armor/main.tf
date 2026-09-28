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



# 4. Subred proxy only

resource "google_compute_subnetwork" "subnet_proxy" {

  name          = "cl-sub-lab-dev-proxy-01"

  ip_cidr_range = "10.129.0.0/23"

  region        = "us-central1"

   network       = google_compute_network.vpc_network.id

  purpose       = "REGIONAL_MANAGED_PROXY"

  role          = "ACTIVE"

  }



# 5. Regla de firewall para permitir trafico SSH a una VM

resource "google_compute_firewall" "allow_ssh" {

  name         = "allow-ssh"

  network      = google_compute_network.vpc_network.id

  source_ranges = ["0.0.0.0/0"]

  priority     = 1000

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



# 6. Regla de firewall para permitir entrada de tráfico HTTP/TCP

#desde los rangos IP de los comprobadores de estado de Google



resource "google_compute_firewall" "allow_health_checks" {

  name         = "allow-alb-health-checks"

  network      = google_compute_network.vpc_network.id

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]

  priority     = 1000

  direction    = "INGRESS"

  allow {

    protocol = "tcp"

    ports    = ["80"]

  }

 target_tags = ["allow-health-check"]

}



# 7. Regla de firewall para permitir  tráfico HTTP de la subred proxy

# hacia instancias de backend.

 

resource "google_compute_firewall" "allow_proxy_http_to_backend" {

    name         = "allow-proxy-to-backend"

  network      = google_compute_network.vpc_network.id

  source_ranges = ["10.129.0.0/23"]

  priority     = 1000

  direction    = "INGRESS"

  allow {

    protocol = "tcp"

    ports    = ["80"]

  }

 target_tags = ["allow-http"]

}



# 8. MIG Template

resource "google_compute_instance_template" "web_server_template" {

    name_prefix = "web-template"

    machine_type = "e2-micro"

    region = "us-central1"

    tags = ["allow-http", "allow-ssh", "allow-health-check", "allow-proxy-to-backend"]



disk {

  source_image = "debian-cloud/debian-12"

  auto_delete = true

  boot = true

  disk_type = "pd-standard"

  disk_size_gb = 10



}

    network_interface {

      subnetwork = google_compute_subnetwork.subnet_uc1a.id

      access_config {

        network_tier = "STANDARD"

      }

    }

    scheduling {

    automatic_restart   = true

    on_host_maintenance = "MIGRATE"

    preemptible         = false

    provisioning_model  = "STANDARD"

  }

  metadata_startup_script = <<-EOF

    #!/bin/bash

    set -e



    # Actualizar paquetes e instalar Nginx y cURL

    apt-get update -y

    apt-get install -y nginx curl



    # Obtener metadatos directamente del Google Cloud Metadata Server

    VM_NAME=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)

    VM_ZONE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | awk -F/ '{print $NF}')

    VM_INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

    VM_MACHINE_TYPE=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/machine-type | awk -F/ '{print $NF}')



    # Crear la página index.html con un diseño visual moderno

    cat <<HTML > /var/www/html/index.html

    <!DOCTYPE html>

    <html lang="es">

    <head>

      <meta charset="UTF-8">

      <meta name="viewport" content="width=device-width, initial-scale=1.0">

      <title>GCP Network Professional Lab</title>

      <style>

        * { box-sizing: border-box; margin: 0; padding: 0; }

        body {

          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;

          background: linear-gradient(135deg, #0d1117 0%, #161b22 100%);

          color: #e6edf3;

          min-height: 100vh;

          display: flex;

          justify-content: center;

          align-items: center;

          padding: 20px;

        }

        .card {

          background: rgba(255, 255, 255, 0.04);

          border: 1px solid rgba(240, 246, 252, 0.1);

          backdrop-filter: blur(16px);

          border-radius: 16px;

          padding: 32px;

          max-width: 600px;

          width: 100%;

          box-shadow: 0 20px 40px rgba(0, 0, 0, 0.5);

        }

        .badge {

          display: inline-block;

          background: #238636;

          color: #ffffff;

          font-size: 11px;

          font-weight: 700;

          padding: 4px 12px;

          border-radius: 12px;

          text-transform: uppercase;

          margin-bottom: 16px;

          letter-spacing: 0.5px;

        }

        h1 {

          font-size: 24px;

          margin-bottom: 8px;

          color: #58a6ff;

        }

        p.subtitle {

          color: #8b949e;

          font-size: 14px;

          margin-bottom: 24px;

          line-height: 1.5;

        }

        .info-grid {

          display: grid;

          grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));

          gap: 12px;

          margin-bottom: 24px;

        }

        .info-box {

          background: rgba(0, 0, 0, 0.35);

          padding: 12px 14px;

          border-radius: 8px;

          border-left: 3px solid #1f6feb;

        }

        .label {

          font-size: 11px;

          color: #8b949e;

          text-transform: uppercase;

          letter-spacing: 0.5px;

          margin-bottom: 4px;

        }

        .value {

          font-size: 14px;

          font-weight: 600;

          color: #f0f6fc;

          word-break: break-all;

        }

        .footer {

          border-top: 1px solid rgba(240, 246, 252, 0.1);

          padding-top: 14px;

          font-size: 12px;

          color: #7ee787;

          text-align: center;

        }

      </style>

    </head>

    <body>

      <div class="card">

        <span class="badge">Backend Saludable</span>

        <h1>Google Cloud Networking Lab ☁️</h1>

        <p class="subtitle">Instancia autogestionada aprovisionada con <strong>Terraform</strong> para demostración de arquitectura de redes, MIG y balanceo de carga.</p>

       

        <div class="info-grid">

          <div class="info-box">

            <div class="label">Instancia</div>

            <div class="value">$VM_NAME</div>

          </div>

          <div class="info-box">

            <div class="label">Zona</div>

            <div class="value">$VM_ZONE</div>

          </div>

          <div class="info-box">

            <div class="label">IP Interna</div>

            <div class="value">$VM_INTERNAL_IP</div>

          </div>

          <div class="info-box">

            <div class="label">Tipo de Máquina</div>

            <div class="value">$VM_MACHINE_TYPE</div>

          </div>

        </div>



        <div class="footer">

          🚀 Portafolio Técnico - Rumbo a la certificación <strong>Professional Cloud Network Engineer</strong>

        </div>

      </div>

    </body>

    </html>

HTML



    # Reiniciar y habilitar Nginx

    systemctl restart nginx

    systemctl enable nginx

  EOF



  lifecycle {

    create_before_destroy = true

  }

}
# 9. Health Check para Auto-recuperación (Autohealing)
resource "google_compute_health_check" "http_health_check" {
  name                = "mig-http-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# 10. Regional Managed Instance Group (MIG Multizona)
resource "google_compute_region_instance_group_manager" "web_mig" {
  name                      = "web-mig-multizone"
  region                    = "us-central1"
  base_instance_name        = "web-srv"
  distribution_policy_zones = ["us-central1-a", "us-central1-b"]

  version {
    instance_template = google_compute_instance_template.web_server_template.id
    name              = "primary"
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.http_health_check.id
    initial_delay_sec = 180
  }

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_surge_fixed       = 2
    max_unavailable_fixed = 0
  }
}

# 11. Autoscaler Regional asociado al MIG
resource "google_compute_region_autoscaler" "web_autoscaler" {
  name   = "web-mig-autoscaler"
  region = "us-central1"
  target = google_compute_region_instance_group_manager.web_mig.id

  autoscaling_policy {
    min_replicas    = 1
    max_replicas    = 2
    cooldown_period = 60

    cpu_utilization {
      target = 0.6
    }
  }

}

# -------------------------------------------------------------
# 12. Dirección IP Global Estática (Anycast IPv4)
# -------------------------------------------------------------
resource "google_compute_global_address" "alb_ip" {
  name        = "alb-global-static-ip"
  description = "Dirección IP Anycast estática para el frontend del ALB"
  ip_version  = "IPV4"
}

# -------------------------------------------------------------
# 13. Comprobación de Estado (Health Check)
# -------------------------------------------------------------
resource "google_compute_health_check" "alb_health_check" {
  name                = "alb-backend-health-check"
  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# -------------------------------------------------------------
# 14. Backend Service para el Application Load Balancer
# -------------------------------------------------------------
resource "google_compute_backend_service" "alb_backend_service" {
  name                  = "alb-backend-service"
  description           = "Servicio backend que dirige el tráfico al MIG multizona"
  protocol              = "HTTP"
  port_name             = "http" # Debe coincidir con el named_port del MIG
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  health_checks         = [google_compute_health_check.alb_health_check.id]

  backend {
    group           = google_compute_region_instance_group_manager.web_mig.instance_group
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
    capacity_scaler = 1.0
  }
  security_policy = google_compute_security_policy.cloud_armor_lab.id
}

# -------------------------------------------------------------
# 15. Mapa de URLs (URL Map)
# -------------------------------------------------------------
resource "google_compute_url_map" "alb_url_map" {
  name            = "alb-url-map"
  description     = "Mapa de URL principal que enruta al backend service"
  default_service = google_compute_backend_service.alb_backend_service.id
}

# -------------------------------------------------------------
# 5. Target HTTP Proxy
# -------------------------------------------------------------
resource "google_compute_target_http_proxy" "alb_http_proxy" {
  name    = "alb-target-http-proxy"
  url_map = google_compute_url_map.alb_url_map.id
}

# -------------------------------------------------------------
# 16. Global Forwarding Rule (Frontend HTTP - Puerto 80)
# -------------------------------------------------------------
resource "google_compute_global_forwarding_rule" "alb_http_forwarding_rule" {
  name                  = "alb-http-forwarding-rule"
  description           = "Regla de reenvío global Anycast en el puerto 80"
  target                = google_compute_target_http_proxy.alb_http_proxy.id
  ip_address            = google_compute_global_address.alb_ip.address
  ip_protocol           = "TCP"
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  network_tier          = "PREMIUM"
}

# -------------------------------------------------------------
# 17. Salida: IP Pública para pruebas
# -------------------------------------------------------------
output "load_balancer_ip" {
  description = "Dirección IP pública Anycast del Load Balancer"
  value       = google_compute_global_address.alb_ip.address

}


# -------------------------------------------------------------
# 18. Creacion politica basica de Cloud Armor
# -------------------------------------------------------------
resource "google_compute_security_policy" "cloud_armor_lab" {
  name        = "cl-cloud-armor-basico"
  description = "Politica basica de Cloud Armor para el laboratorio"

  # REGLA 1: Regla de prueba (Bloquea una IP específica)
  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["9.9.9.9/32"] # Cámbiala por tu IP pública para probar el bloqueo 403 en vivo
      }
    }
    description = "Bloquea una IP de prueba"
  }

  # REGLA 2: Regla por defecto (Obligatoria)
  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Permitir todo el trafico restante"
  }
}