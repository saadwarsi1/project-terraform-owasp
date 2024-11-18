# Resource Group
resource "azurerm_resource_group" "owasp" {
  name     = "owasp-resources"
  location = "West US"
}

# Virtual Network
resource "azurerm_virtual_network" "owasp_vnet" {
  name                = "owasp-vnet"
  resource_group_name = azurerm_resource_group.owasp.name
  location            = azurerm_resource_group.owasp.location
  address_space       = ["10.0.0.0/16"]
}

# Subnet
resource "azurerm_subnet" "owasp_subnet" {
  name                 = "owasp-subnet"
  resource_group_name  = azurerm_resource_group.owasp.name
  virtual_network_name = azurerm_virtual_network.owasp_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP
resource "azurerm_public_ip" "owasp" {
  name                = "owasp-vm-pip"
  resource_group_name = azurerm_resource_group.owasp.name
  location            = azurerm_resource_group.owasp.location
  allocation_method   = "Static"
}

# Network Security Group
resource "azurerm_network_security_group" "owasp_sg" {
  name                = "owasp-vm-nsg"
  resource_group_name = azurerm_resource_group.owasp.name
  location            = azurerm_resource_group.owasp.location

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAllOutbound"
    priority                   = 1003
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Interface
resource "azurerm_network_interface" "owasp_server_nic" {
  name                = "owasp-vm-nic"
  resource_group_name = azurerm_resource_group.owasp.name
  location            = azurerm_resource_group.owasp.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.owasp_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.owasp.id
  }
}

# Associate the Network Security Group with each Network Interface
resource "azurerm_network_interface_security_group_association" "http_server_sg_association" {
  network_interface_id      = azurerm_network_interface.owasp_server_nic.id
  network_security_group_id = azurerm_network_security_group.owasp_sg.id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "owasp_http_server" {
  name                            = "owasp-vm"
  resource_group_name             = azurerm_resource_group.owasp.name
  location                        = azurerm_resource_group.owasp.location
  size                            = "Standard_D4s_v3"
  admin_username                  = "saaduser"
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.owasp_server_nic.id
  ]

  admin_ssh_key {
    username   = "saaduser"
    public_key = file("~/.ssh/owasp_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  tags = {
    environment = "dev"
  }
}
########################