resource "random_pet" "database_name" {
  count  = var.pet_count
  length = 3
  prefix = "${var.name_prefix}-${var.environment}-${var.storage_size_gb}gb"
}

# Simulate a long-running destroy (like an Aurora cluster deletion).
# random_pet destroys instantly, so convergence plans never overlap with
# an in-progress destroy. Real AWS resources (Aurora, OpenSearch) take
# 5-15 minutes to delete. This time_sleep forces a 5-minute destroy,
# giving TFC time to schedule a convergence plan while the destroy is
# still running — which is when we believe the bug triggers.
resource "time_sleep" "simulate_slow_destroy" {
  destroy_duration = "300s"

  triggers = {
    pet_id = random_pet.database_name[0].id
  }
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
