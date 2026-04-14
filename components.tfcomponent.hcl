# ------------------------------------------------------------------
# database: conditionally enabled, like temporal-aurora in real infra
# Uses var.regions for for_each (not toset(["this"])) to match real pattern
# ------------------------------------------------------------------
component "database" {
  for_each = var.enable_database ? var.regions : toset([])

  source = "./modules/database"
  inputs = {
    environment = var.environment
    name_prefix = var.name_prefix
    pet_count   = var.pet_count
  }
  providers = {
    random = provider.random.this
  }
}

# Removed block for database — mirrors real infra pattern.
# Activates when enable_database = false, for ALL regions.
# BUG TRIGGER: evaluates for deployments that NEVER had database enabled.
removed {
  from   = component.database[each.value]
  source = "./modules/database"

  for_each = var.enable_database ? toset([]) : var.regions

  providers = {
    random = provider.random.this
  }
}

# ------------------------------------------------------------------
# cache: second conditional component, like temporal-opensearch
# ------------------------------------------------------------------
component "cache" {
  for_each = var.enable_cache ? var.regions : toset([])

  source = "./modules/cache"
  inputs = {
    environment = var.environment
    name_prefix = var.name_prefix
  }
  providers = {
    random = provider.random.this
  }
}

# Removed block for cache — second removed block in same config
removed {
  from   = component.cache[each.value]
  source = "./modules/cache"

  for_each = var.enable_cache ? toset([]) : var.regions

  providers = {
    random = provider.random.this
  }
}

# ------------------------------------------------------------------
# app: always enabled, references conditional component outputs
# Like eks-addons referencing temporal-aurora outputs in real infra
# ------------------------------------------------------------------
component "app" {
  for_each = var.regions

  source = "./modules/app"
  inputs = {
    environment = var.environment
    name_prefix = var.name_prefix

    # Cross-component references — conditional on enable flags
    # Mirrors: temporal_server_default_store_user = var.enable_temporal_aurora ? component.temporal-aurora[each.value].default_store_username : ""
    database_endpoint = var.enable_database ? component.database[each.value].database_names[0] : ""
    cache_endpoint    = var.enable_cache ? component.cache[each.value].cache_endpoint : ""
  }
  providers = {
    random = provider.random.this
  }
}
