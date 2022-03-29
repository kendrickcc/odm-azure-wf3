#-------------------------------
# Create resource group
#-------------------------------
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rsg"
  location = var.location
  tags     = merge(local.common_tags)
}
#-------------------------------
# Networking
#-------------------------------
resource "azurerm_public_ip" "odm" {
  name                = "${var.prefix}-webodm${count.index}-pip"
  count               = var.nodeodm_servers
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
  sku                 = "Basic"
  tags                = merge(local.common_tags)
}
resource "azurerm_virtual_network" "rg" {
  name                = "${var.prefix}-network"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = merge(local.common_tags)
}
resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.rg.name
  address_prefixes     = [var.subnet_cidr]
}
resource "azurerm_network_interface" "nodeodm" {
  name                = "${var.prefix}-nodeodm${count.index}-nic"
  count               = var.nodeodm_servers
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.odm[count.index].id
  }
  tags = merge(local.common_tags)
}
#-------------------------------
# Network security group
#-------------------------------
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = merge(local.common_tags)
  #/* when needed to connect to VM, add a leading "#"
  security_rule {
    name                       = "SSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  } # */
  security_rule {
    name                       = "AllowClusterODMInBound"
    priority                   = 401
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10000"
    source_address_prefix      = "0.0.0.0/0"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "sec_group" {
  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
#-------------------------------
# Create virtual machines
#-------------------------------
resource "azurerm_linux_virtual_machine" "nodeodm" {
  name                = "${var.prefix}-nodeodm${count.index}-vm"
  count               = var.nodeodm_servers
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = var.vmSize
  admin_username      = var.adminUser
  network_interface_ids = [
    azurerm_network_interface.nodeodm[count.index].id,
  ]
  computer_name                   = "${var.prefix}-nodeodm${count.index}-vm"
  disable_password_authentication = true
  custom_data                     = base64encode(data.template_file.cloud-init.rendered)
  source_image_reference {
    publisher = element(split(",", lookup(var.standard_os, var.simple_os, "")), 0)
    offer     = element(split(",", lookup(var.standard_os, var.simple_os, "")), 1)
    sku       = element(split(",", lookup(var.standard_os, var.simple_os, "")), 2)
    version   = "latest"
  }
  os_disk {
    storage_account_type = var.storageAccountType
    caching              = "ReadWrite"
    disk_size_gb         = var.diskSizeGB
  }
  admin_ssh_key {
    username   = var.adminUser
    public_key = var.pub_key_data
  }
  connection {
    timeout     = "2m"
    type        = "ssh"
    user        = var.adminUser
    private_key = file(var.pem_key)
    host        = self.public_ip_address
  }
  provisioner "file" {
    source      = var.rcloneConf
    destination = "/home/${var.adminUser}/rclone.conf"
  }
  tags = merge(local.common_tags)
}
#-------------------------------
# create cloud-init template file
#-------------------------------
#/*
data "template_file" "cloud-init" {
  template = <<EOT
#!/bin/bash
sudo useradd odm
sudo apt-get update && apt-get -y install docker docker.io docker-compose 
sudo usermod -aG sudu,docker odm
sudo rsync --archive --chown=odm:odm /home/${var.adminUser}/.ssh /home/odm
sudo mkdir -p /home/odm/.config/rclone
sudo mv /home/${var.adminUser}/rclone.conf /home/odm/.config/rclone
sudo chown -R odm:odm /home/odm
sudo chmod 600 /home/odm/.config/rclone/rclone.conf
cd /home/${var.adminUser}
# install rclone
curl https://rclone.org/install.sh | sudo bash
sudo mkdir -p /odm/datasets/project/images
#git clone https://github.com/OpenDroneMap/WebODM --config core.autocrlf=input --depth 1 /odm/WebODM
sudo chown -R odm:odm /odm
#sudo --set-home --user=odm docker run --detach --rm --tty --publish 3000:3000 --publish 10000:10000 --publish 8080:8080 opendronemap/clusterodm
#sudo --set-home --user=odm docker run --detach --rm --publish 3001:3000 opendronemap/nodeodm
#sudo --set-home --user=odm /odm/WebODM/webodm.sh start --detached --default-nod
EOT
}