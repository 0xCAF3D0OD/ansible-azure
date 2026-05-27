variable "location" {
  description = "Azure region"
  type        = string
  default     = "West US 2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "VM size (important pour les coûts!)"
  type        = string
  default     = "Standard_D2als_v7"
}

variable "pub_key" {
  description = "Public key for accessing ssh"
  type        = string
  default     = "~/.ssh/azure_ssh_key.pub"
}

variable "subscription_id" {
  description = "Subscription ID azure User"
  type = string
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type = string
}

variable "tenant_id" {
  type = string
}