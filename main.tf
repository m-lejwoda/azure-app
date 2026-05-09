resource "azurerm_resource_group" "main_rgp" {
  name     = "main-rgp"
  location = "West Europe"
}

resource "azurerm_virtual_network" "main_vnet" {
  name                = "main-vnet"
  location            = azurerm_resource_group.main_rgp.location
  resource_group_name = azurerm_resource_group.main_rgp.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "backend_subnet" {
  name                 = "backend-subnet"
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
  name                 = "storage-subnet"
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
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.main_rgp.name
  virtual_network_name = azurerm_virtual_network.main_vnet.name
  address_prefixes     = ["10.0.3.0/24"]
}

resource "azurerm_service_plan" "fastapi_plan" {
  name                = "fastapi-plan"
  resource_group_name = azurerm_resource_group.main_rgp.name
  location            = azurerm_resource_group.main_rgp.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "prod_fastapi" {
  name                      = "prod-fastapi"
  location                  = azurerm_resource_group.main_rgp.location
  resource_group_name       = azurerm_resource_group.main_rgp.name
  service_plan_id           = azurerm_service_plan.fastapi_plan.id
  virtual_network_subnet_id = azurerm_subnet.backend_subnet.id

  site_config {
    application_stack {
      python_version = "3.13"
    }

    app_command_line       = "uvicorn main:app --host 0.0.0.0 --port 8000"
    vnet_route_all_enabled = true
    http2_enabled          = true
    always_on              = true
  }
  app_settings = {
    "DATABASE_URL" = "postgresql://psqladmin:H@Sh1CoR3!@${azurerm_postgresql_flexible_server.postgres_database.fqdn}:5432/app_prod"
  }
}

resource "azurerm_linux_web_app_slot" "staging_fastapi" {
  name                      = "staging-fastapi"
  app_service_id            = azurerm_linux_web_app.prod_fastapi.id
  virtual_network_subnet_id = azurerm_subnet.backend_subnet.id
  site_config {
    application_stack {
      python_version = "3.13"
    }
    app_command_line       = "uvicorn main:app --host 0.0.0.0 --port 8000"
    vnet_route_all_enabled = true
    http2_enabled          = true
    always_on              = true
  }
  app_settings = {
    "DATABASE_URL" = "postgresql://psqladmin:H@Sh1CoR3!@${azurerm_postgresql_flexible_server.postgres_database.fqdn}:5432/app_stage"
  }
}

resource "azurerm_private_dns_zone" "postgres_dns" {
  name                = "azure-project.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main_rgp.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_zone_link" {
  name                  = "dns-zone-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres_dns.name
  virtual_network_id    = azurerm_virtual_network.main_vnet.id
  resource_group_name   = azurerm_resource_group.main_rgp.name
}

resource "azurerm_postgresql_flexible_server" "postgres_database" {
  name                          = "postgres-database"
  resource_group_name           = azurerm_resource_group.main_rgp.name
  location                      = azurerm_resource_group.main_rgp.location
  version                       = "16"
  delegated_subnet_id           = azurerm_subnet.storage_subnet.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres_dns.id
  public_network_access_enabled = false
  administrator_login           = "psqladmin"
  administrator_password        = "H@Sh1CoR3!"
  zone                          = "1"

  storage_mb   = 32768 //32Gbs
  storage_tier = "P4"

  sku_name = "B_Standard_B1ms"
  depends_on = [azurerm_private_dns_zone_virtual_network_link.dns_zone_link]

}



