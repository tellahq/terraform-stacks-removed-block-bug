variable "environment" {
  type    = string
  default = "removed"
}

variable "name_prefix" {
  type    = string
  default = "myapp"
}

# Variables with defaults NOT passed in component inputs.
# These are the trigger: PlanPrevInputs() returns empty map after destroy,
# then checkInputVariables() finds these declared vars unassigned.
variable "node_count" {
  type    = number
  default = 3
}

variable "instance_type" {
  type    = string
  default = "cache.m6g.large"
}
