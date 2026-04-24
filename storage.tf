resource "google_storage_bucket" "models" {
  name                        = "${var.project_id}-${var.service_name}"
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  depends_on = [google_project_service.apis["storage.googleapis.com"]]
}
