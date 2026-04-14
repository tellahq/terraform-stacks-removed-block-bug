# Terraform Stacks `removed` Block Bug — Minimal Reproduction

Demonstrates a bug where a `removed` block errors with "Unassigned variable...
This is a bug in Terraform" for module variables that have defaults but were not
explicitly passed in the component's `inputs` block.

Tracked in: hashicorp/terraform#XXXXX

## Theory: Convergence Plans After Slow Destroys

We believe the bug only triggers during **convergence plans** that TFC schedules
after a **long-running destroy**. With `random_pet` (which destroys instantly),
the destroy completes before TFC schedules a convergence plan, so the removed
block is never re-evaluated against cleared state.

Real AWS resources like Aurora clusters take 5-15 minutes to delete. During that
window, TFC schedules convergence plans that re-evaluate the removed block. At
that point, `PlanPrevInputs()` returns an empty map (destroy has cleared the
component state), and `checkInputVariables()` finds declared module variables
that were never in the component's `inputs` block, erroring on each one.

To simulate this, we use `time_sleep` with `destroy_duration = "300s"` — this
forces the destroy to take 5 minutes, giving TFC enough time to schedule a
convergence plan while the destroy is still in progress.

## The Bug Trigger

Two ingredients are required:

### 1. Module variables with defaults not in component inputs

The `database` module declares `extra_tags`, `storage_size_gb`, and
`enable_backups` with defaults. These are NOT passed in the component's `inputs`
block. After destroy clears stored inputs, `PlanPrevInputs()` returns an empty
map, and `checkInputVariables()` errors on every declared variable not found in
that map.

### 2. A long-running destroy that triggers a convergence plan

When TFC runs a destroy that takes minutes (not milliseconds), it schedules a
convergence plan while the destroy is still running. The convergence plan
re-evaluates the `removed` block against state that has already been partially
or fully cleared, triggering the variable validation bug.

## Prerequisites

- An HCP Terraform account with Stacks enabled
- A Stack connected to a fork/clone of this repository
- No cloud credentials needed — uses only `hashicorp/random` and `hashicorp/time`

## Repository Structure

```
components.tfcomponent.hcl   # database component (conditional) + removed block
deployments.tfdeploy.hcl     # Single deployment with enable_database = true
providers.tfcomponent.hcl    # random + time providers
variables.tfcomponent.hcl    # Stack-level variables
modules/
  database/                  # Uses random_pet + time_sleep (5min destroy). Has vars with defaults not in inputs.
```

## Steps to Reproduce

> **Important:** Each step is a separate git push that triggers a separate TFC
> Stack deployment run. Wait for each run to complete before proceeding.

### Step 1: Deploy with the component enabled

1. Verify `deployments.tfdeploy.hcl` has `enable_database = true`.
2. Push this repo to the branch your Stack is tracking.
3. In HCP Terraform, approve and apply the deployment.
4. **Wait for the run to complete.** The deployment creates `random_pet` and
   `time_sleep` resources.

### Step 2: Disable the component (triggers the bug)

1. In `deployments.tfdeploy.hcl`, change `enable_database = true` to
   `enable_database = false`.
2. Commit and push. This triggers a new TFC Stack run.
3. In HCP Terraform, approve and apply.
4. The `removed` block activates. The destroy begins and takes ~5 minutes
   (due to `time_sleep.simulate_slow_destroy`).
5. **Expected bug:** During the slow destroy, TFC schedules a convergence plan
   that re-evaluates the removed block. `PlanPrevInputs()` returns an empty map,
   and `checkInputVariables()` errors:

```
Error: Unassigned variable
The input variable "extra_tags" has not been assigned a value.
This is a bug in Terraform; please report it in a GitHub issue.
```

### Step 3: Observe the catch-22 (no resolution possible)

The stack is now stuck. Every option leads to an error:

- **Keep the `removed` block** -> same "Unassigned variable" error on every subsequent plan
- **Delete the `removed` block** -> "Unclaimed component instance" error (orphaned state)
- **No `terraform stacks state rm` command exists** to manually clean up
- **Stacks state API is read-only** -> cannot remove the orphaned component entry

## Workaround (from production experience)

The only workaround found was to temporarily empty all module files (zero
variables, zero resources, zero outputs) so `checkInputVariables()` iterates
zero times. After applying that, restore module files and delete removed blocks.
This required 4 separate PRs/applies in production.
