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

# 1.1 Crear el bucket de Cloud Storage optimizado para CDN
resource "google_storage_bucket" "cdn_bucket" {
  name          = "cl-demo-learn-cdn-bucket-lab" # Modifica este nombre (debe ser globalmente único)
  location      = "US"                             # O "SOUTHAMERICA-WEST1" / "EU"
  force_destroy = true                             # Permite borrar el bucket con 'terraform destroy' aunque tenga archivos

  # Configuración para servir contenido web estático
  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  # Configuración de CORS para permitir peticiones web desde cualquier origen
  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  # Desactivar la prevención de acceso público (necesario para buckets de lectura pública)
  public_access_prevention = "inherited"
}

# 1.2 Hacer que todos los objetos dentro del bucket sean de lectura pública (AllUsers)
resource "google_storage_bucket_iam_member" "public_read" {
  bucket = google_storage_bucket.cdn_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# 1.3 Subir un archivo index.html de prueba automáticamente
resource "google_storage_bucket_object" "index_html" {
  name         = "index.html"
  bucket       = google_storage_bucket.cdn_bucket.name
  content      = "<h1>Hola desde mi CDN Lab en GCP!_cache invalidation test</h1>"
  content_type = "text/html"
}

# Output para obtener la URL directa de lectura del objeto
output "bucket_url" {
  value = "https://storage.googleapis.com/${google_storage_bucket.cdn_bucket.name}/index.html"
}

# ------------------------------------------------------------------------------
# 2. CONFIGURACIÓN DEL BACKEND BUCKET CON CLOUD CDN
# ------------------------------------------------------------------------------
resource "google_compute_backend_bucket" "cdn_backend" {
  name        = "cdn-backend-bucket"
  bucket_name = google_storage_bucket.cdn_bucket.name
  enable_cdn  = true

  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    default_ttl       = 3600
    max_ttl           = 86400
    client_ttl        = 3600
    negative_caching  = true
  }
}


# ------------------------------------------------------------------------------
# 3. LOAD BALANCER & COMPONENTES DE RED GLOBAL
# ------------------------------------------------------------------------------

# IP pública estática global para el Load Balancer
resource "google_compute_global_address" "lb_ip" {
  name = "cdn-lb-ip"
}

# Mapa de URLs (Rutas de entrada hacia el Backend Bucket)
resource "google_compute_url_map" "cdn_url_map" {
  name            = "cdn-url-map"
  default_service = google_compute_backend_bucket.cdn_backend.id
}

# Target HTTP Proxy
resource "google_compute_target_http_proxy" "cdn_http_proxy" {
  name    = "cdn-http-proxy"
  url_map = google_compute_url_map.cdn_url_map.id
}

# Regla de Reenvío (Forwarding Rule) en Puerto 80
resource "google_compute_global_forwarding_rule" "cdn_forwarding_rule" {
  name                  = "cdn-forwarding-rule"
  ip_protocol           = "TCP"
  port_range            = "80"
  target                = google_compute_target_http_proxy.cdn_http_proxy.id
  ip_address            = google_compute_global_address.lb_ip.address
  load_balancing_scheme = "EXTERNAL"
}

# ------------------------------------------------------------------------------
# 4. OUTPUTS DE VERIFICACIÓN
# ------------------------------------------------------------------------------
output "load_balancer_ip" {
  description = "IP pública del Load Balancer para probar la CDN"
  value       = google_compute_global_address.lb_ip.address
}

output "bucket_direct_url" {
  description = "URL directa del bucket para probar el comportamiento sin CDN"
  value       = "https://storage.googleapis.com/${google_storage_bucket.cdn_bucket.name}/index.html"
}