resource "random_pet" "legacy_name" {
  length = 3
  prefix = "${var.name_prefix}-${var.environment}"
}
