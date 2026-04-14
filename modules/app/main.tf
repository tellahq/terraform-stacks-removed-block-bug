resource "random_pet" "app_name" {
  length = 2
  prefix = "${var.name_prefix}-${var.environment}"
}

output "app_id" {
  value = random_pet.app_name.id
}

output "db_connection" {
  value = var.database_endpoint
}
