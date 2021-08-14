#--Create vNet
resource "azurerm_resource_group" "rg" {
  name     = "${local.name}-${var.env}-${var.app}-rg"
  location = var.location
  tags = {
    environment = var.env
    owner       = local.name
    location    = var.location
    app         = var.app
  }
}

#--Create vNet
resource "azurerm_virtual_network" "vnet" {
  name                = "vNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

#--Create subnet for VMs
resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes      = ["10.0.1.0/24"]
}

#--Create bastion subnet
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.100.0/24"]
}

#--Associate NSG with bastion subnet
resource "azurerm_subnet_network_security_group_association" "nsg-bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

#--Create public IP for bastion
resource "azurerm_public_ip" "bastionpubip" {
    name                   = "bastionpubip"
    location               = "westeurope"
    resource_group_name    = azurerm_resource_group.rg.name
    allocation_method      = "Static"
    sku                    = "Standard"

    tags = {
        environment = "test"
    }
}

#--Create bastion host
resource "azurerm_bastion_host" "mybast" {
  name                = "${local.name}-${var.env}-bastion"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name


  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastionpubip.id
  }
}


#--Create NIC for Windows server
resource "azurerm_network_interface" "nic-win01" {
  name                = "win01-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}


#--Create NSG to protect bastion
resource "azurerm_network_security_group" "nsg" {
    name                = "nsg-bastion"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name

    tags = {
        environment = "test"
    }
}


#--Create NSG rules protecting bastion
resource "azurerm_network_security_rule" "sec_rule" {
    for_each                    = var.nsg_rules
    resource_group_name         = azurerm_resource_group.rg.name
    network_security_group_name = azurerm_network_security_group.nsg.name
    name                        = each.key
    priority                    = each.value[0]
    direction                   = each.value[1]
    access                      = each.value[2]
    protocol                    = each.value[3]
    source_port_range           = each.value[4]
    destination_port_range      = each.value[5]
    source_address_prefix       = each.value[6]
    destination_address_prefix  = each.value[7]
}


#--Create virtual machine Windows server 2019
#--Managed system identity must be enabled on Azure virtual machines.
#-- https://docs.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-install?tabs=ARMAgentPowerShell%2CPowerShellWindows%2CPowerShellWindowsArc%2CCLIWindows%2CCLIWindowsArc#prerequisites
resource "azurerm_windows_virtual_machine" "win01" {
  name                          = "${local.name}-win01"
  resource_group_name           = azurerm_resource_group.rg.name
  location                      = azurerm_resource_group.rg.location
  size                          = "Standard_DS1_v2"
  admin_username                = "adminuser"
  admin_password                = "P@$$w0rd1234!"
  network_interface_ids         = [azurerm_network_interface.nic-win01.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  identity {
    type = "SystemAssigned"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}


#--Create NIC for Linux server
resource "azurerm_network_interface" "nic-ubuntu01" {
  name                = "ubuntu01-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}


# --Create Linux VM
resource "azurerm_virtual_machine" "ubuntu01" {
    name                    = "${local.name}-ubuntu01"
    location                = azurerm_resource_group.rg.location
    resource_group_name     = azurerm_resource_group.rg.name
    network_interface_ids   = [azurerm_network_interface.nic-ubuntu01.id]
    vm_size                 = "Standard_DS1_v2"
    delete_os_disk_on_termination = true

    storage_os_disk {
        name                = "osdisk-ubuntu01"
        caching             = "ReadWrite"
        create_option       = "FromImage"
        managed_disk_type   = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    identity {
        type = "SystemAssigned"
    }

    os_profile {
        computer_name  = "${local.name}-ubuntu01"
        admin_username = var.admin_username
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = var.keypath
            key_data = file(var.pubkey)
        }
    }
}

