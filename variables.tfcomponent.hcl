variable "environment" {
  type = string
}

variable "regions" {
  type = set(string)
}

variable "enable_database" {
  type    = bool
  default = false
}
