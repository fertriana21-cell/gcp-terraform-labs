output "consumer_vm_ip" {
  value = google_compute_instance.vm_consumer.network_interface[0].network_ip
}

output "psc_endpoint_ip" {
  value = google_compute_address.psc_endpoint_ip.address
}