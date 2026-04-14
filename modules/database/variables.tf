variable "environment" {
  type    = string
  default = "removed"
}

variable "name_prefix" {
  type    = string
  default = "myapp"
}

variable "pet_count" {
  type    = number
  default = 2
}

# Variables with defaults that are NOT passed in component inputs.
# In the real infra, temporal-aurora has variables like reader_instance_class,
# default_store_username, visibility_store_username that have defaults but
# are not in the component's inputs block.
#
# BUG: After destroy clears stored inputs, PlanPrevInputs() returns an empty
# map. checkInputVariables() then finds these declared variables unassigned
# and errors with "Unassigned variable... This is a bug in Terraform."
variable "extra_tags" {
  type    = map(string)
  default = {}
}

variable "storage_size_gb" {
  type    = number
  default = 10
}

variable "enable_backups" {
  type    = bool
  default = true
}
