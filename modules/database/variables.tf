variable "environment" {
  type    = string
  default = "dev"
}

variable "name_prefix" {
  type    = string
  default = "myapp"
}

variable "pet_count" {
  type    = number
  default = 2
}

# These variables have defaults and are intentionally NOT passed
# in the component inputs block. This is the trigger for the bug —
# they're never stored in state, so PlanPrevInputs() won't include them.
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
