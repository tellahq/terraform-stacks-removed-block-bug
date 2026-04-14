required_providers {
  random = {
    source  = "hashicorp/random"
    version = "~> 3.6"
  }
  time = {
    source  = "hashicorp/time"
    version = "~> 0.12"
  }
}

# Singleton providers (for app module)
provider "random" "this" {}
provider "time" "this" {}

# for_each-keyed provider (for database and legacy modules — matches real infra pattern)
# Real infra uses: provider "aws" "configurations" { for_each = var.regions; config { region = each.value } }
# The random provider doesn't need per-region config, but the for_each evaluation path is what matters.
provider "random" "regional" {
  for_each = var.regions
}
