output "endpoint" {
  value = random_pet.database_name.id
}

output "default_store_username" {
  value = var.default_store_username
}

output "visibility_store_username" {
  value = var.visibility_store_username
}
