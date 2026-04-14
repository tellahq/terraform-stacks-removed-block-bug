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
    time   = provider.time.this
  }
}

removed {
  from   = component.database[each.value]
  source = "./modules/database"

  for_each = var.enable_database ? toset([]) : toset(["this"])

  providers = {
    random = provider.random.this
    time   = provider.time.this
  }
}
