deployment "dev" {
  inputs = {
    environment     = "dev"
    regions         = ["us-east-2"]
    enable_database = false
    enable_cache    = false
  }
}

deployment "stage" {
  inputs = {
    environment     = "stage"
    regions         = ["us-east-2"]
    enable_database = false
    enable_cache    = false
  }
}

deployment "prod" {
  inputs = {
    environment     = "prod"
    regions         = ["us-east-2"]
    enable_database = false
    enable_cache    = false
  }
}
