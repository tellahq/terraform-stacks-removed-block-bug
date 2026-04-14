# =============================================================================
# Conditional database component (like temporal-aurora in real infra)
# Enabled per-deployment via enable_database variable.
#
# Deletion happens implicitly via for_each switching to toset([]).
# There is NO explicit removed block — TFC handles the destroy automatically.
# This is what triggers a convergence plan: the apply includes both a component
# deletion (database) AND an update to another component (app), so TFC runs
# Plan → Apply → Convergence Plan. The bug fires on the convergence plan.
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
    random = provider.random.regional[each.value]
    time   = provider.time.this
  }
}

# =============================================================================
# App component — always deployed, references conditional database outputs.
# This mirrors eks-addons referencing temporal-aurora outputs in real infra.
#
# The random_id resource uses database_endpoint as a keeper, so when the
# endpoint changes from a real value to "none" (database disabled), the
# resource gets recreated — a real change that forces TFC to include app
# in the same apply as the database deletion.
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
