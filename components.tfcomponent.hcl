# =============================================================================
# Conditional database component (like temporal-aurora in real infra)
# Enabled per-deployment via enable_database variable.
# =============================================================================

component "database" {
  for_each = var.enable_database ? var.regions : toset([])

  source = "./modules/database"
  inputs = {
    environment = var.environment
    name_prefix = "${var.environment}-repro"
    # NOTE: NOT all module variables are passed here.
    # reader_instance_class, extra_tags, storage_size_gb, enable_backups
    # are declared in the module with defaults but intentionally omitted.
  }
  providers = {
    random = provider.random.this
    time   = provider.time.this
  }
}

# Claim database instances in state for destroy when enable_database = false.
# The module variables have defaults so the removed block can resolve them
# without inputs from the component block.
# Safe to delete this block once TFC state no longer contains database.
removed {
  for_each = var.enable_database ? toset([]) : var.regions
  from     = component.database[each.value]
  source   = "./modules/database"

  providers = {
    random = provider.random.this
    time   = provider.time.this
  }
}

# =============================================================================
# Legacy component — fully removed (no component block remains).
# This mirrors temporal-aurora-mysql in real infra: the component was deleted
# in a previous version, only the removed block remains to clean up state.
# Safe to delete once TFC state no longer contains legacy.
# =============================================================================

removed {
  for_each = var.regions
  from     = component.legacy[each.value]
  source   = "./modules/legacy"

  providers = {
    random = provider.random.this
  }
}

# =============================================================================
# App component — always deployed, references conditional database outputs.
# This mirrors eks-addons referencing temporal-aurora outputs in real infra.
# =============================================================================

component "app" {
  for_each = var.regions

  source = "./modules/app"
  inputs = {
    environment       = var.environment
    database_endpoint = var.enable_database ? component.database[each.value].endpoint : "none"
  }
  providers = {
    random = provider.random.this
  }
}
