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

variable "enable_database" {
  type    = bool
  default = true
}

variable "enable_cache" {
  type    = bool
  default = false
}

# Mimics var.regions in the real infra — used in for_each
variable "regions" {
  type    = set(string)
  default = ["us-east-1"]
}
