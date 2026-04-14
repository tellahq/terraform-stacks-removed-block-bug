resource "random_pet" "database_name" {
  count  = var.pet_count
  length = 3
  prefix = "${var.name_prefix}-${var.environment}-${var.storage_size_gb}gb"
}

output "database_names" {
  value = random_pet.database_name[*].id
}

output "backups_enabled" {
  value = var.enable_backups
}

output "tags" {
  value = var.extra_tags
}
