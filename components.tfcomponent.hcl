# Active component — creates resources when enabled
component "database" {
  for_each = var.enable_database ? toset(["this"]) : toset([])

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

# Removal block — destroys resources when disabled.
# After successful destroy, this block triggers the bug:
# "Unassigned variable... This is a bug in Terraform"
removed {
  from   = component.database
  source = "./modules/database"

  for_each = var.enable_database ? toset([]) : toset(["this"])

  providers = {
    random = provider.random.this
  }
}
