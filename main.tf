terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.104.2"
    }
  }
}

provider "azurerm" {
  subscription_id = "d5d25c85-c63a-4f0b-8896-c4ce1e506799"
  client_id       = "d8d07156-919b-4767-914c-e31fd8a9f91b"
  client_secret   = "P3R8Q~OAzKVPg3ZHH3-oSUqiM5wG7muvX94dub-K"
  tenant_id       = "be9b9493-d1e5-4fdd-a59f-f4c8506067e5"
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = "flipkart-rg"
  location = "East US 2"
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "flipkart-Vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a subnet
resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create a network security group
resource "azurerm_network_security_group" "nsg" {
  name                = "flipkart-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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
}

# Create a public IP address
resource "azurerm_public_ip" "flipkart-ip" {
  name                = "flipkart-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create a network interface
resource "azurerm_network_interface" "nic" {
  name                = "flipkart-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "myNicConfiguration"
    subnet_id                     = azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.flipkart-ip.id
  }
}

# Associate the network security group with the network interface
resource "azurerm_network_interface_security_group_association" "nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create a managed disk
resource "azurerm_managed_disk" "data_disk" {
  name                 = "Hadiya-DataDisk"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

# Create a virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "flipkart-VM"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = "Standard_B1s"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  computer_name                   = "Ajwad"
  admin_username                  = "Ajwad"
  admin_password                  = "1@34567890ad!"
  disable_password_authentication = false

  custom_data = base64encode(
    <<-EOT
      #!/bin/bash
      sudo apt-get update
      sudo apt-get install -y mysql-server=8.0* mysql-client=8.0*
      sudo systemctl start mysql
      sudo systemctl enable mysql

      # Setup MySQL
      sudo mysql -e "CREATE USER 'Ajwad'@'localhost' IDENTIFIED BY '1@34567890ad';"
      sudo mysql -e "CREATE DATABASE db_database;"
      sudo mysql -e "GRANT ALL PRIVILEGES ON db_database.* TO 'Ajwad'@'localhost';"
      sudo mysql -e "FLUSH PRIVILEGES;"
      
      # Clone the repository and restore the database
      sudo apt-get install -y git
      git clone https://github.com/Shoaib720/hadiya-products-database.git
      sudo mysql db_database < /hadiya-products-database/sql/your_sql_file.sql
    EOT
  )
}

# Attach the managed disk to the virtual machine
resource "azurerm_virtual_machine_data_disk_attachment" "data_disk_attachment" {
  managed_disk_id    = azurerm_managed_disk.data_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id
  lun                = 0
  caching            = "ReadWrite"
}

