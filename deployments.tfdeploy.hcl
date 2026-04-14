deployment "dev" {
  inputs = {
    environment     = "dev"
    name_prefix     = "dev-repro"
    pet_count       = 2
    enable_database = false
  }
}
