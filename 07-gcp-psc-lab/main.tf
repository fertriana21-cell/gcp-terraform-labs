# 1. Llamamos al Módulo Productor

module "producer" {
  source = "./modules/vpc_producer"
  project_id = var.project_id
  region = var.region
}

# 2. Llamamos al Módulo Consumidor
module "consumer" {
    source = "./modules/vpc_consumer"
    project_id = var.project_id
    region = var.region
    service_attachment_uri = module.producer.service_attachment_uri
}