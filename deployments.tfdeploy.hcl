# REPRODUCTION STEPS:
#   1. Push with enable_database = true in "stage", apply ALL deployments in TFC.
#   2. Change stage to enable_database = false, push again, apply — triggers the bug.
#
# KEY INSIGHT: The bug triggers because the removed block evaluates for ALL
# deployments, including "dev" which NEVER had database enabled. When TFC
# evaluates the removed block for "dev", PlanPrevInputs() returns an empty
# map (no prior state for this component), but checkInputVariables() still
# finds declared variables in the module and errors with "Unassigned variable".

# Dev deployment — NEVER enables database.
# The removed block still evaluates here with for_each = var.regions,
# trying to claim component instances that never existed in dev's state.
deployment "dev" {
  inputs = {
    environment     = "dev"
    name_prefix     = "dev-repro"
    regions         = ["us-east-1"]
    pet_count       = 1
    enable_database = false
    enable_cache    = false
  }
}

# Stage deployment — had database enabled, now disabling.
# This is the deployment where the destroy actually runs.
deployment "stage" {
  inputs = {
    environment     = "stage"
    name_prefix     = "stage-repro"
    regions         = ["us-east-1"]
    pet_count       = 2
    enable_database = true  # Step 1: deploy with true. Step 2: flip to false.
    enable_cache    = false
  }
}
