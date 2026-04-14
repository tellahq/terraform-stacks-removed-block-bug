resource "random_id" "config_hash" {
  byte_length = 4
  keepers = {
    endpoint = var.database_endpoint
  }
}

output "applied_endpoint" {
  value = var.database_endpoint
}

output "config_hash" {
  value = random_id.config_hash.hex
}
