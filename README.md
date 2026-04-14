# Terraform Stacks `removed` Block Bug — Reproduction

Demonstrates a bug where a `removed` block errors with "Unassigned variable...
This is a bug in Terraform" for module variables that have defaults but were not
explicitly passed in the component's `inputs` block.

Tracked in: hashicorp/terraform#XXXXX

## Architecture (mirrors real infra)

This repo replicates the exact patterns from a production Terraform Stack where
the bug was first observed. Key structural elements:

### Three deployments (dev, stage, prod)
Only `stage` has `enable_database = true`. Dev and prod keep it `false`.
This means the `removed` block is active in 2 of 3 deployments simultaneously.

### Conditional component with `var.regions` for_each
The `database` component uses `var.enable_database ? var.regions : toset([])`
— NOT `toset(["this"])`. The region value flows through as `each.value`.

### Inverse-conditional removed block
The removed block uses the inverse: `var.enable_database ? toset([]) : var.regions`.

### Standalone removed block (no corresponding component)
The `legacy` removed block has NO component block — it only exists to clean up
state from a component that was fully deleted in a previous version. This mirrors
the `temporal-aurora-mysql` pattern in real infra.

### Cross-component output references
The `app` component references `component.database[each.value].endpoint`
conditionally, mirroring how `eks-addons` references `temporal-aurora` outputs.

### Module variables with ALL defaults (critical)
The `database` module has variables with defaults that are NOT passed in the
component's `inputs` block. This includes a `default = null` variable (like
`reader_instance_class` in real infra). After destroy clears stored inputs,
`PlanPrevInputs()` returns an empty map, and `checkInputVariables()` errors.

## Theory: Convergence Plans After Slow Destroys

The bug only triggers during **convergence plans** that TFC schedules after a
**long-running destroy**. With `random_pet` (which destroys instantly), the
destroy completes before TFC schedules a convergence plan, so the removed block
is never re-evaluated against cleared state.

Real AWS resources like Aurora clusters take 5-15 minutes to delete. During that
window, TFC schedules convergence plans that re-evaluate the removed block. At
that point, `PlanPrevInputs()` returns an empty map (destroy has cleared the
component state), and `checkInputVariables()` finds declared module variables
that were never in the component's `inputs` block, erroring on each one.

To simulate this, we use `time_sleep` with `destroy_duration = "300s"`.

## Prerequisites

- An HCP Terraform account with Stacks enabled
- A Stack connected to a fork/clone of this repository
- No cloud credentials needed — uses only `hashicorp/random` and `hashicorp/time`

## Repository Structure

```
components.tfcomponent.hcl   # database + app components, removed blocks for database + legacy
deployments.tfdeploy.hcl     # 3 deployments: dev, stage (database enabled), prod
providers.tfcomponent.hcl    # random + time providers
variables.tfcomponent.hcl    # Stack-level variables
modules/
  database/                  # random_pet + time_sleep (300s destroy). Has vars with defaults not in inputs.
  legacy/                    # random_pet only. Standalone removed block — no component exists.
  app/                       # random_pet. References database endpoint conditionally.
```

## Steps to Reproduce

> **Important:** Each step is a separate git push that triggers a separate TFC
> Stack deployment run. Wait for each run to complete before proceeding.

### Step 1: Deploy with database enabled in stage

1. Verify `deployments.tfdeploy.hcl` has `enable_database = true` in the
   `stage` deployment (dev and prod have it `false`).
2. Push this repo to the branch your Stack is tracking.
3. In HCP Terraform, approve and apply all three deployments.
4. **Wait for all runs to complete.** Stage creates `random_pet` and
   `time_sleep` resources. Dev and prod only create `app` resources.

### Step 2: Disable the database in stage (triggers the bug)

1. In `deployments.tfdeploy.hcl`, change stage's `enable_database = true` to
   `enable_database = false`.
2. Commit and push. This triggers a new TFC Stack run.
3. In HCP Terraform, approve and apply.
4. The `removed` block activates in stage. The destroy begins and takes ~5
   minutes (due to `time_sleep.simulate_slow_destroy`).
5. **Expected bug:** During the slow destroy, TFC schedules a convergence plan.
   `PlanPrevInputs()` returns an empty map, and `checkInputVariables()` errors:

```
Error: Unassigned variable
The input variable "reader_instance_class" has not been assigned a value.
This is a bug in Terraform; please report it in a GitHub issue.
```

### Step 3: Observe the catch-22 (no resolution possible)

The stack is now stuck. Every option leads to an error:

- **Keep the `removed` block** -> same "Unassigned variable" error on every plan
- **Delete the `removed` block** -> "Unclaimed component instance" error
- **No `terraform stacks state rm` command exists** to manually clean up
- **Stacks state API is read-only** -> cannot remove orphaned component entries

## Workaround (from production experience)

The only workaround found was to temporarily empty all module files (zero
variables, zero resources, zero outputs) so `checkInputVariables()` iterates
zero times. After applying that, restore module files and delete removed blocks.
This required 4 separate PRs/applies in production.
