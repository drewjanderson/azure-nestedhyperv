variable "resource_group_location" {
  default     = "eastus"
  description = "Location of the resource group."
}

variable "vmname" {
  default = "hyperv01"
}

variable "adminuser" {
  default = "winadmin"
  type    = string
}

variable "adminpassword" {
  type = string
}

variable "publicipaddress" {
  type = string
}