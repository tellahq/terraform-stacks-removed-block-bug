resource "random_pet" "cache_name" {
  length = 2
  prefix = "${var.name_prefix}-${var.environment}-cache"
}

output "cache_endpoint" {
  value = random_pet.cache_name.id
}
