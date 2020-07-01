resource "azurerm_resource_group"  "rsg"{
    name     = var.rsgname
    location = var.location
}

resource "azurerm_virtual_network" "wvnet" {
    name                = var.vnetname
    address_space      = var. address_space
    location            = azurerm_resource_group.rsg.location
    resource_group_name = azurerm_resource_group.rsg.name
 }

 resource "azurerm_subnet" "wsubnet" {
    name                 = var.subnetname
    resource_group_name  = azurerm_resource_group.rsg.name
    virtual_network_name = azurerm_virtual_network.wvnet.name
    address_prefix       = var.address_prefix

}
resource "azurerm_network_security_group" "wnsg" {
    name                = var.nsgname[count.index]
    location            = azurerm_resource_group.rsg.location
    resource_group_name = azurerm_resource_group.rsg.name
    count               = length(var.nsgname)
    security_rule {
        name                       = "HTTP"
        priority                   = 100
       direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = azurerm_network_interface.wnic[count.index].private_ip_address
    }
 security_rule {
        name                       = "RDP"
        priority                   = 102
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = azurerm_network_interface.wnic[count.index].private_ip_address
    }
}

resource "azurerm_public_ip" "publicip_vm" {
      name=var.publicipname[count.index]
      resource_group_name=azurerm_resource_group.rsg.name
      location=azurerm_resource_group.rsg.location
      allocation_method="Dynamic"
      domain_name_label   = var.dns_name[count.index]
  count=length(var.publicipname)
}

resource "azurerm_network_interface" "wnic" {
    name                        = var.nicname[count.index]
    location                    = azurerm_resource_group.rsg.location
    resource_group_name         = azurerm_resource_group.rsg.name
    count                       = length(var.nicname)

    ip_configuration {
        name                          = var.nicname[count.index]
        subnet_id                     = azurerm_subnet.wsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.publicip_vm[count.index].id
    }
}

resource "azurerm_network_interface_security_group_association" "wass" {
    network_interface_id      = azurerm_network_interface.wnic[count.index].id
    network_security_group_id = azurerm_network_security_group.wnsg[count.index].id
    count = 2
 }


resource "azurerm_windows_virtual_machine" "vm1" {
  name                            = var.vmname[count.index]
  resource_group_name             = azurerm_resource_group.rsg.name
  location                        = azurerm_resource_group.rsg.location
  size                            = var.size
  admin_username                  = "swarna"
  admin_password                  = "A12s@00001234"
  network_interface_ids           = [azurerm_network_interface.wnic[count.index].id]
  availability_set_id             = azurerm_availability_set.availability.id
  count                           = length(var.vmname)



  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
 os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
}

resource "azurerm_availability_set" "availability"{
name    = var.availabilityname
location =var.location
resource_group_name=azurerm_resource_group.rsg.name
managed =true
platform_fault_domain_count=2
platform_update_domain_count=2
}
resource "azurerm_traffic_manager_profile" "example" {
  name                   = "swarnaTMprofile"
  resource_group_name    = azurerm_resource_group.rsg.name
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "swarna"
    ttl           = 30
  }

  monitor_config {
    protocol = "http"
    port     = 80
    path     = "/"
  }
}

resource "azurerm_traffic_manager_endpoint" "endpoints" {
  name                = "end1"
  resource_group_name = azurerm_resource_group.rsg.name
  profile_name        = azurerm_traffic_manager_profile.example.name
  target_resource_id  = azurerm_public_ip.publicip_vm[0].id
  type                = "azureEndpoints"
  weight              = 100

}
resource "azurerm_traffic_manager_endpoint" "endpoints1" {
  name                = "end2"
  resource_group_name = azurerm_resource_group.rsg.name
  profile_name        = azurerm_traffic_manager_profile.example.name
  target_resource_id  = azurerm_public_ip.publicip_vm[01].id
  type                = "azureEndpoints"
  weight              = 50

}