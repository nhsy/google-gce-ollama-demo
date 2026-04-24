variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region for all resources."
  type        = string
  default     = "us-east4"
}

variable "zone" {
  description = "GCP zone for the GCE instance. Must support G4 machine types (e.g., us-east4-b or us-east4-c)."
  type        = string
  default     = "us-east4-c"
}

variable "service_name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "gce-ollama"
}

variable "machine_type" {
  description = "GCE machine type. G4 machine types include an RTX PRO 6000 GPU (96 GB GDDR7)."
  type        = string
  default     = "g4-standard-48"
}

variable "ollama_models" {
  description = "Ollama model(s) to pull on instance startup."
  type        = list(string)
  default     = ["qwen3-coder-next"]
}

variable "subnet_cidr" {
  description = "IP CIDR range for the VPC subnet."
  type        = string
  default     = "10.128.0.0/16"
}

variable "ramdisk_size_gb" {
  description = "Size in GB of the tmpfs RAM disk mounted at /root/.ollama/models."
  type        = number
  default     = 150
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB. G4 machine types require hyperdisk-balanced."
  type        = number
  default     = 100
}
