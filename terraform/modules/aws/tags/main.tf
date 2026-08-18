terraform {
  required_version = ">= 1.6.0"
}

variable "environment" {
  description = "dev, staging or prod."
  type        = string
}

variable "owner" {
  description = "Owning team."
  type        = string
}

variable "cost_centre" {
  description = "Cost centre or budget code."
  type        = string
}

variable "service" {
  description = "Service or platform component name."
  type        = string
}

variable "data_classification" {
  description = "Data classification label."
  type        = string
  default     = "internal"
}

variable "extra" {
  description = "Additional tags merged last."
  type        = map(string)
  default     = {}
}

output "tags" {
  description = "Mandatory allocation tags plus extras."
  value = merge(
    {
      Environment        = var.environment
      Owner              = var.owner
      CostCentre         = var.cost_centre
      Service            = var.service
      DataClassification = var.data_classification
      ManagedBy          = "terraform"
    },
    var.extra
  )
}
