# Variables that ARE passed in component inputs
variable "environment" {
  type    = string
  default = "removed"
}

variable "name_prefix" {
  type    = string
  default = "myapp"
}

# Variables that are NOT passed in component inputs.
# In real infra, temporal-aurora has reader_instance_class (default = null),
# default_store_username, visibility_store_username, enable_reader — all with
# defaults but not in the component inputs block.
#
# BUG: After destroy clears stored inputs, PlanPrevInputs() returns an empty
# map. checkInputVariables() then finds these declared variables unassigned
# and errors with "Unassigned variable... This is a bug in Terraform."

variable "reader_instance_class" {
  type        = string
  default     = null
  description = "Mirrors temporal-aurora reader_instance_class with default = null"
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}

variable "storage_size_gb" {
  type    = number
  default = 10
}

variable "enable_backups" {
  type        = bool
  default     = true
  description = "Mirrors temporal-aurora enable_reader with a bool default"
}

variable "allowed_cidrs" {
  type    = list(string)
  default = ["10.0.0.0/16"]
  description = "Mirrors temporal-aurora private_subnet_ids — list(string) with dummy default"
}

variable "default_store_username" {
  type    = string
  default = "temporal_default"
}

variable "visibility_store_username" {
  type    = string
  default = "temporal_visibility"
}
