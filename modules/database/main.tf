resource "random_pet" "database_name" {
  count  = var.pet_count
  length = 3
  prefix = "${var.name_prefix}-${var.environment}"
}

output "database_names" {
  value = random_pet.database_name[*].id
}
