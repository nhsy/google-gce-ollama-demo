resource "google_service_account" "gce" {
  account_id   = "${var.service_name}-sa"
  display_name = "${var.service_name} GCE Service Account"

  depends_on = [google_project_service.apis["compute.googleapis.com"]]
}

resource "google_storage_bucket_iam_member" "gce" {
  for_each = toset([
    "roles/storage.objectAdmin",
    "roles/storage.bucketViewer",
  ])

  bucket = google_storage_bucket.models.name
  role   = each.value
  member = "serviceAccount:${google_service_account.gce.email}"
}

resource "google_project_iam_member" "gce" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gce.email}"
}
