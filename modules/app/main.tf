resource "random_pet" "app_name" {
  length = 3
  prefix = "${var.environment}-app-${var.database_endpoint}"
}
