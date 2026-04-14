# REPRODUCTION STEPS:
#   1. Push with enable_database = true, apply in TFC, wait for success.
#   2. Change to enable_database = false, push again, apply — this triggers the bug.
deployment "default" {
  inputs = {
    environment     = "demo"
    name_prefix     = "repro"
    pet_count       = 2
    enable_database = false # Step 2: toggled to false to trigger the removed block bug.
  }
}
