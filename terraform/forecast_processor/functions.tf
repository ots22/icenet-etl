# Create the resource group
resource "azurerm_resource_group" "this" {
  name     = "rg-${var.project_name}-fcproc"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "forecastprocessor" {
  name                     = "st${var.project_name}appfcproc"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "LRS"

  network_rules {
    default_action         = "Allow"
#    virtual_network_subnet_ids = [var.subnet_id]
#    bypass                 = ["AzureServices"]
  }

  tags                     = local.tags
}

#resource "azurerm_private_endpoint" "evtproc_app_storage_endpoint" {
#  name                = "pvt-${var.project_name}-evtproc-app"
#  location            = var.location
#  resource_group_name = azurerm_resource_group.this.name
#  subnet_id           = var.subnet_id
#
#  private_service_connection {
#    name              = "pvt-${var.project_name}-evtproc-app"
#    is_manual_connection = "false"
#    private_connection_resource_id = azurerm_storage_account.forecastprocessor.id
#    subresource_names = ["blob"]
#  }
#
#  private_dns_zone_group {
#    name                 = "default"
#    private_dns_zone_ids = [var.dns_zone.id]
#  }
#}

resource "azurerm_application_insights" "this" {
  name                = "insights-${var.project_name}-fcproc"
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  application_type    = "web"
  tags                = local.tags
}

resource "azurerm_communication_service" "comms" {
  name                = "${var.project_name}-comms"
  resource_group_name = azurerm_resource_group.this.name
  # This cannot be UK due to email being global - US only
  # data_location       = "UK"
  data_location       = "United States"
  tags                = local.tags
}

resource "azurerm_email_communication_service" "emails" {
  name                = "${var.project_name}-emails"
  resource_group_name = azurerm_resource_group.this.name
  # This cannot be UK due to email being global - US only
  # data_location       = "UK"
  data_location       = "United States"
  tags                = local.tags
}

# Service plan that functions belong to
resource "azurerm_service_plan" "this" {
  name                         = "plan-${var.project_name}-evtproc"
  resource_group_name          = azurerm_resource_group.this.name
  location                     = var.location
  os_type                      = "Linux"
  maximum_elastic_worker_count = 2
  sku_name                     = local.app_sku
  tags                         = local.tags
}

# Functions to be deployed
resource "azurerm_linux_function_app" "this" {
  name                       = local.app_name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.this.name
  service_plan_id            = azurerm_service_plan.this.id

  storage_account_name       = azurerm_storage_account.forecastprocessor.name
  storage_account_access_key = azurerm_storage_account.forecastprocessor.primary_access_key

  site_config {
    elastic_instance_minimum  = 1
    use_32_bit_worker         = false
    application_insights_connection_string = "InstrumentationKey=${azurerm_application_insights.this.instrumentation_key}"
    application_insights_key  = "${azurerm_application_insights.this.instrumentation_key}"
    application_stack {
      docker {
        registry_url            = "https://registry.hub.docker.com"
        registry_username       = var.docker_username
        registry_password       = var.docker_password
        image_name              = "jimcircadian/iceneteventprocessor"
        image_tag               = "latest"
      }
    }
    #ip_restriction {
    #  virtual_network_subnet_id = var.subnet_id
    #}
    vnet_route_all_enabled = true
  }
  # virtual_network_subnet_id = var.subnet_id
  app_settings = {
    "COMMS_ENDPOINT"                 = azurerm_communication_service.comms.primary_connection_string
    "COMMS_TO_EMAIL"                 = var.notification_email
    "COMMS_FROM_EMAIL"               = var.sendfrom_email
    "FORECAST_PROCESSING_CONFIG"     = "/data/event-processing.yaml"
    # For building on deploy
    #"ENABLE_ORYX_BUILD"              = "true"
    #"SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    #
    # Must have this for using docker containers, or persistent storage will be
    # enabled which mounts over the contents of the container.
    # https://github.com/Azure/azure-functions-docker/issues/642
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }
  identity {
    type          = "SystemAssigned"
    identity_ids  = []
  }
  storage_account {
    account_name  = var.data_storage_account.name
    access_key    = var.data_storage_account.primary_access_key
    name          = "data"
    share_name    = "data"
    type          = "AzureFiles"
    mount_path    = "/data"
  }
  tags = local.tags
  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_role_assignment" "storage_blob_data_reader_assoc" {
  scope              = var.data_storage_account.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id       = azurerm_linux_function_app.this.identity.0.principal_id
}

#resource "azurerm_private_endpoint" "event_proc_endpoint" {
#  name                = "pvt-${var.project_name}-event-processing"
#  location            = var.location
#  resource_group_name = azurerm_resource_group.this.name
#  subnet_id           = var.subnet_id
#
#  private_service_connection {
#    name              = "pvt-${var.project_name}-event-processing"
#    is_manual_connection = "false"
#    private_connection_resource_id = azurerm_linux_function_app.this.id
#    subresource_names = ["sites"]
#  }
#
#  private_dns_zone_group {
#    name                 = "default"
#    private_dns_zone_ids = [var.dns_zone.id]
#  }
#}
#
