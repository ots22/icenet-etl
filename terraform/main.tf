# Network module
module "network" {
  source              = "./network"
  location            = var.location
  project_name        = local.project_name
  default_tags        = local.tags
  users_ip_addresses  = var.users_ip_addresses
}

# Secrets module
module "secrets" {
  source              = "./secrets"
  developers_group_id = var.developers_group_id
  location            = var.location
  project_name        = local.project_name
  default_tags        = local.tags
  tenant_id           = var.tenant_id
}

# Data storage
module "data" {
  source = "./data"
  default_tags        = local.tags
  location            = var.location
  project_name        = local.project_name
  private_subnet_id   = module.network.private_subnet.id
  public_subnet_id    = module.network.public_subnet.id
  storage_mb          = 8192
  key_vault_id        = module.secrets.key_vault_id
}

# NetCDF processing
module "processing" {
  source                       = "./processing"
  data_storage_account         = module.data.inputs_storage_account
  database_resource_group_name = module.data.resource_group.name
  database_fqdn                = module.data.server_fqdn
  database_host                = module.data.server_name
  database_name                = module.data.database_names[0]
  database_user                = module.data.admin_username
  database_password            = module.data.admin_password
  location                     = var.location
  project_name                 = local.project_name
  default_tags                 = local.tags
  subnet_id                    = module.network.private_subnet.id
}

module "web" {
  source                      = "./web"
  default_tags                = local.tags
  project_name                = local.project_name
  location                    = var.location
}

# PyGeoAPI app
module "pygeoapi" {
  source                      = "./pygeoapi"
  postgres_db_name            = module.data.database_names[0]
  postgres_db_host            = module.data.server_fqdn
  postgres_db_reader_username = module.data.reader_username
  postgres_db_reader_password = module.data.reader_password
  pygeoapi_input_port         = "8000"
  default_tags                = local.tags
  project_name                = local.project_name
  location                    = var.location
  subnet_id                   = module.network.private_subnet.id
  dns_zone                    = module.network.dns_zone
  webapps_resource_group      = module.web.resource_group
}

##
# Downstream processing elements, quite likely should always be at the end of the run
#

# Forecast event processing and event grid subs
module "forecast_processor" {
  source                       = "./forecast_processor"
  location                     = var.location
  project_name                 = local.project_name
  default_tags                 = local.tags
  input_storage_account        = module.data.inputs_storage_account
  input_storage_resource_group = module.data.resource_group
  processing_storage_account   = module.data.processors_storage_account
  subnet_id                    = module.network.private_subnet.id
}
