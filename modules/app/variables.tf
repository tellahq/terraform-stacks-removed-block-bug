variable "environment" {
  type = string
}

variable "name_prefix" {
  type = string
}

variable "database_endpoint" {
  type    = string
  default = ""
}

variable "cache_endpoint" {
  type    = string
  default = ""
}
