terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "project_id" {
  description = "GCP project for this composition. Use a dedicated project, not the org seed project."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west2"
}

variable "environment" {
  description = "dev, staging or prod."
  type        = string
}

variable "name" {
  description = "Name prefix."
  type        = string
}

variable "host_cidr" {
  description = "Shared VPC primary CIDR."
  type        = string
}

variable "owner" {
  description = "Owning team."
  type        = string
  default     = "platform"
}

variable "cost_centre" {
  description = "Cost centre."
  type        = string
  default     = "platform-engineering"
}

locals {
  labels = {
    environment        = var.environment
    owner              = var.owner
    costcentre         = var.cost_centre
    service            = var.name
    dataclassification = "internal"
    managedby          = "terraform"
  }
}

resource "google_compute_network" "shared" {
  name                    = "${var.name}-${var.environment}"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_firewall" "internal" {
  name    = "${var.name}-${var.environment}-internal"
  network = google_compute_network.shared.name
  allow {
    protocol = "tcp"
  }
  allow {
    protocol = "udp"
  }
  allow {
    protocol = "icmp"
  }
  source_ranges = [var.host_cidr]
}

resource "google_compute_firewall" "deny_internet_ingress" {
  name      = "${var.name}-${var.environment}-deny-internet"
  network   = google_compute_network.shared.name
  direction = "INGRESS"
  priority  = 65534
  deny {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_subnetwork" "nodes" {
  name                     = "${var.name}-${var.environment}-nodes"
  ip_cidr_range            = cidrsubnet(var.host_cidr, 2, 0)
  region                   = var.region
  network                  = google_compute_network.shared.id
  private_ip_google_access = true
  purpose                  = "PRIVATE"

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = cidrsubnet(var.host_cidr, 1, 1)
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = cidrsubnet(var.host_cidr, 4, 8)
  }
}

resource "google_compute_router" "this" {
  name    = "${var.name}-${var.environment}"
  network = google_compute_network.shared.id
  region  = var.region
}

resource "google_compute_router_nat" "this" {
  name                               = "${var.name}-${var.environment}"
  router                             = google_compute_router.this.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.nodes.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

output "labels" {
  description = "Allocation labels used on this composition."
  value       = local.labels
}

output "network_name" {
  description = "VPC network name."
  value       = google_compute_network.shared.name
}

output "nodes_subnetwork" {
  description = "GKE nodes subnetwork name."
  value       = google_compute_subnetwork.nodes.name
}
