terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

variable "subscription_id" {
  description = "Azure subscription GUID. Placeholder is for validate only."
  type        = string
  default     = "00000000-0000-0000-0000-000000000000"
}

variable "environment" {
  description = "dev, staging or prod."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "uksouth"
}

variable "name" {
  description = "Name prefix."
  type        = string
}

variable "hub_cidr" {
  description = "Hub VNet CIDR."
  type        = string
}

variable "spoke_cidr" {
  description = "Spoke VNet CIDR."
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
  tags = {
    Environment        = var.environment
    Owner              = var.owner
    CostCentre         = var.cost_centre
    Service            = var.name
    DataClassification = "internal"
    ManagedBy          = "terraform"
  }
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-${var.name}-${var.environment}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name}-hub-${var.environment}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  address_space       = [var.hub_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "gateway" {
  # checkov:skip=CKV2_AZURE_31:GatewaySubnet cannot have an NSG
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_cidr, 3, 0)]
}

resource "azurerm_subnet" "firewall" {
  # checkov:skip=CKV2_AZURE_31:AzureFirewallSubnet cannot have an NSG
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [cidrsubnet(var.hub_cidr, 3, 1)]
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name}-spoke-${var.environment}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  address_space       = [var.spoke_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [cidrsubnet(var.spoke_cidr, 2, 0)]
}

resource "azurerm_network_security_group" "aks" {
  name                = "nsg-${var.name}-aks-${var.environment}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "hub-to-spoke"
  resource_group_name          = azurerm_resource_group.platform.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "spoke-to-hub"
  resource_group_name          = azurerm_resource_group.platform.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
  allow_virtual_network_access = true
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "log-${var.name}-${var.environment}"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = local.tags
}

output "resource_group_name" {
  description = "Platform resource group."
  value       = azurerm_resource_group.platform.name
}

output "hub_vnet_id" {
  description = "Hub virtual network ID."
  value       = azurerm_virtual_network.hub.id
}

output "spoke_vnet_id" {
  description = "Spoke virtual network ID."
  value       = azurerm_virtual_network.spoke.id
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID."
  value       = azurerm_log_analytics_workspace.this.id
}
