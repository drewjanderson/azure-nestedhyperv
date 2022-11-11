resource "azurerm_resource_group" "rg" {
  name     = "hyperv-rg"
  location = var.resource_group_location
}

# Create virtual network
resource "azurerm_virtual_network" "hypervnetwork" {
  name                = "hyperv-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
resource "azurerm_subnet" "hosts" {
  name                 = "hosts"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.hypervnetwork.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "hypervpublicip" {
  name                = "${var.vmname}-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "hostnsg" {
  name                = "${var.vmname}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "RDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "${var.publicipaddress}"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "hypervnic" {
  name                = "${var.vmname}-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "${var.vmname}-ipconfig"
    subnet_id                     = azurerm_subnet.hosts.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.hypervpublicip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsgattach" {
  network_interface_id      = azurerm_network_interface.hypervnic.id
  network_security_group_id = azurerm_network_security_group.hostnsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "diagstorage" {
  name                     = "diag${random_id.randomId.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create virtual machine
resource "azurerm_windows_virtual_machine" "hypervvm" {
  name                  = var.vmname
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.hypervnic.id]
  size                  = "Standard_D8s_v3"
  admin_username        = var.adminuser
  admin_password        = var.adminpassword

  os_disk {
    name                 = "${var.vmname}-os"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-datacenter-with-containers-g2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagstorage.primary_blob_endpoint
  }
}

resource "azurerm_managed_disk" "datadisk" {
  name                 = "${var.vmname}-disk1"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Premium_LRS"
  create_option        = "Empty"
  disk_size_gb         = 256
}

resource "azurerm_virtual_machine_data_disk_attachment" "datadiskattach" {
  managed_disk_id    = azurerm_managed_disk.datadisk.id
  virtual_machine_id = azurerm_windows_virtual_machine.hypervvm.id
  lun                = "0"
  caching            = "ReadOnly"
}


resource "azurerm_virtual_machine_extension" "hypervvmext" {
  depends_on = [
    azurerm_virtual_machine_data_disk_attachment.datadiskattach
  ]
  name                 = "${var.vmname}-vmext"
  virtual_machine_id   = azurerm_windows_virtual_machine.hypervvm.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
    {
      "fileUris": [ "https://raw.githubusercontent.com/drewjanderson/azure-nestedhyperv/main/ConfigureHyperV.ps1" ],
      "commandToExecute":"powershell.exe -executionpolicy unrestricted -file ConfigureHyperV.ps1"
    }
SETTINGS
}