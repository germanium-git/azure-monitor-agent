variable "subscription_id" {}

variable "location" {
  description = "Environment location (Azure region)"
  default = "westeurope"
}

variable "env" {
  description = "Environment (dev/test/prod)"
  default = "dev"
}

variable "app" {
  description = "Application name"
  default = "azmonitoragent"
}

locals {
  name = "mylocal"
}

# Specify rules in the Network Security Group protecting the management access to FortiGate Firewall
variable "nsg_rules" {
  description = "Network Security Group"
  type = map(list(string))

  # Structure is as follows name = [priority, direction, access, protocol, source_port_range, destination_port_range, source_address_prefix, destination_address_prefix]
  default = {
    #allowall            = ["100", "Inbound", "Allow", "*",   "*", "*",   "*",                 "*",]
    BastionFromInternet  = ["110", "Inbound", "Allow", "Tcp", "*", "443", "185.230.172.74/32", "*",]
    GatewayManager       = ["120", "Inbound", "Allow", "Tcp", "*", "443", "GatewayManager",    "*",]
    OutAll               = ["100", "Outbound", "Allow", "*",  "*", "*",   "*",                 "*",]
  }
}

#--The Account to access VM(s)
variable "admin_username" {
  default = "azureuser"
}

#--The path on the virtual machine where the public key will be saved.
variable "keypath" {
  default = "/home/azureuser/.ssh/authorized_keys"
}

#--Local path to the public key used to authenticate on linux VM
variable "pubkey" {
  default = "./key/id_rsa.pub"
}