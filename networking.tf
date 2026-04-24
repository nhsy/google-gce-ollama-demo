resource "google_compute_network" "default" {
  name                    = var.service_name
  auto_create_subnetworks = false

  depends_on = [google_project_service.apis["compute.googleapis.com"]]
}

resource "google_compute_subnetwork" "default" {
  name                     = "${var.service_name}-${var.region}"
  region                   = var.region
  network                  = google_compute_network.default.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true

  lifecycle {
    create_before_destroy = true
  }
}

# Allow IAP to reach instance on SSH (22) and Ollama API (11434)
resource "google_compute_firewall" "iap" {
  name    = "${var.service_name}-allow-iap"
  network = google_compute_network.default.name

  allow {
    protocol = "tcp"
    ports    = ["22", "11434"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = [var.service_name]
}
