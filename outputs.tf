output "instance_name" {
  description = "GCE instance name."
  value       = google_compute_instance.ollama.name
}

output "project_id" {
  description = "GCP project ID."
  value       = var.project_id
}

output "zone" {
  description = "GCE instance zone."
  value       = google_compute_instance.ollama.zone
}

output "instance_internal_ip" {
  description = "Internal IP address of the GCE instance."
  value       = google_compute_instance.ollama.network_interface[0].network_ip
}

output "instance_external_ip" {
  description = "Ephemeral external IP of the GCE instance (used for internet egress only; ingress is IAP-only)."
  value       = google_compute_instance.ollama.network_interface[0].access_config[0].nat_ip
}

output "model_name" {
  description = "Ollama model(s) configured for this deployment."
  value       = join(",", var.ollama_models)
}

output "gcs_bucket" {
  description = "GCS bucket used for persistent model cache."
  value       = google_storage_bucket.models.name
}

output "tunnel_cmd" {
  description = "Command to open an IAP tunnel to the Ollama API on localhost:11434."
  value       = "gcloud compute start-iap-tunnel ${google_compute_instance.ollama.name} 11434 --local-host-port=localhost:11434 --zone=${google_compute_instance.ollama.zone} --project=${var.project_id}"
}

output "ssh_cmd" {
  description = "Command to SSH into the instance via IAP."
  value       = "gcloud compute ssh ${google_compute_instance.ollama.name} --zone=${google_compute_instance.ollama.zone} --project=${var.project_id} --tunnel-through-iap"
}
