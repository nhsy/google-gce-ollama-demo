resource "google_compute_instance" "ollama" {
  name         = var.service_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = [var.service_name]

  boot_disk {
    initialize_params {
      # Ubuntu 22.04 with CUDA 12.9 + NVIDIA driver 580 pre-installed
      image = "deeplearning-platform-release/common-cu129-ubuntu-2204-nvidia-580"
      size  = var.boot_disk_size_gb
      type  = "hyperdisk-balanced"
    }
  }

  network_interface {
    network    = google_compute_network.default.name
    subnetwork = google_compute_subnetwork.default.name
    # Ephemeral external IP — provides internet egress for Ollama install + model pulls.
    # Ingress is still restricted to IAP only via the firewall rule above.
    access_config {}
  }

  scheduling {
    preemptible                 = true
    automatic_restart           = false
    on_host_maintenance         = "TERMINATE"
    provisioning_model          = "SPOT"
    instance_termination_action = "STOP"
  }

  service_account {
    email  = google_service_account.gce.email
    scopes = ["cloud-platform"]
  }

  # Config passed to startup script via GCE metadata — avoids template escaping issues
  metadata = {
    "ollama-model"     = jsonencode(var.ollama_models)
    "ramdisk-size-gb"  = tostring(var.ramdisk_size_gb)
    "gcs-model-bucket" = google_storage_bucket.models.name
    startup-script     = file("${path.module}/templates/startup.sh")
  }

  depends_on = [
    google_project_service.apis,
    google_compute_subnetwork.default,
    google_service_account.gce,
    google_storage_bucket_iam_member.gce,
    google_project_iam_member.gce,
  ]
}
