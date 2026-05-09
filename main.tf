resource "azurerm_resource_group" "main_rgp" {
  name     = "main_rgp"
  location = "West Europe"
}

resource "azurerm_virtual_network" "main_vnet" {
  name                = "main_vnet"
  location            = azurerm_resource_group.main_rgp.location
  resource_group_name = azurerm_resource_group.main_rgp.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "backend_subnet" {
  name                 = "backend_subnet"
  resource_group_name  = azurerm_resource_group.main_rgp.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  delegation {
    name = "fastapi-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "storage_subnet" {
  name                 = "storage_subnet"
  resource_group_name  = azurerm_resource_group.main_rgp.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  delegation {
    name = "storage-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
    }
  }
}

resource "azurerm_subnet" "public_subnet" {
  name                 = "public_subnet"
  resource_group_name  = azurerm_resource_group.main_rgp.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

