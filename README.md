# Terraform Stacks `removed` Block Bug — Reproduction

Demonstrates a bug where a **convergence plan** errors with "Unassigned variable...
This is a bug in Terraform" for module variables that have defaults but were not
explicitly passed in the component's `inputs` block.

Tracked in: hashicorp/terraform#XXXXX

## The Bug: Convergence Plans

The bug triggers on a **convergence plan**, not the initial plan. Convergence plans
happen when TFC sees both component **deletions** AND **updates** to other components
in the same apply. The sequence is:

1. Plan detects: delete `database` (for_each becomes empty) + update `app` (resource change)
2. Apply runs: destroys database resources, updates app resources
3. TFC schedules a **convergence plan** to verify everything settled
4. The convergence plan re-evaluates the deleted `database` component
5. `PlanPrevInputs()` returns an empty map (destroy cleared stored inputs)
6. `checkInputVariables()` finds declared module variables that were never in the
   component's `inputs` block and errors:

```
Error: Unassigned variable
The input variable "reader_instance_class" has not been assigned a value.
This is a bug in Terraform; please report it in a GitHub issue.
```

### Why implicit deletion (not `removed` blocks)

Explicit `removed` blocks complete the deletion in a single plan-apply pass. No
convergence plan is needed because TFC knows exactly what to expect. With implicit
deletion via `for_each = toset([])`, TFC must verify the deletion settled correctly,
which triggers the convergence plan — and the bug.

### Why cross-component updates matter

The `app` component's `random_id` resource uses `database_endpoint` as a keeper.
When `enable_database` switches from `true` to `false`, the endpoint changes from
a real value to `"none"`, which forces `random_id` to be recreated. This real
resource change means the apply includes both a deletion (database) and an update
(app), which is the condition that triggers a convergence plan.

## Architecture

### Two components
- **database**: Conditional via `for_each = var.enable_database ? var.regions : toset([])`
  Has module variables with defaults NOT passed in the component `inputs` block.
- **app**: Always deployed (`for_each = var.regions`). References database endpoint
  conditionally. Uses `random_id` with keepers so the endpoint change causes a
  real resource update.

### Three deployments (dev, stage, prod)
Only `stage` starts with `enable_database = true`. Dev and prod keep it `false`.

### Module variables with ALL defaults (critical)
The `database` module has variables with defaults that are NOT passed in the
component's `inputs` block. This includes a `default = null` variable (like
`reader_instance_class` in real infra). After destroy clears stored inputs,
`PlanPrevInputs()` returns an empty map, and `checkInputVariables()` errors.

### Slow destroy via time_sleep
The `database` module includes `time_sleep` with `destroy_duration = "300s"` to
simulate real AWS resource deletion times (Aurora clusters take 5-15 minutes).
This ensures the destroy is still running when TFC evaluates the convergence plan.

## Prerequisites

- An HCP Terraform account with Stacks enabled
- A Stack connected to a fork/clone of this repository
- No cloud credentials needed — uses only `hashicorp/random` and `hashicorp/time`

## Repository Structure

```
components.tfcomponent.hcl   # database + app components (no removed blocks)
deployments.tfdeploy.hcl     # 3 deployments: dev, stage (database enabled), prod
providers.tfcomponent.hcl    # random + time providers
variables.tfcomponent.hcl    # Stack-level variables
modules/
  database/                  # random_pet + time_sleep (300s destroy). Has vars with defaults not in inputs.
  app/                       # random_id with keepers. Endpoint change forces resource recreation.
```

## Steps to Reproduce

> **Important:** Each step is a separate git push that triggers a separate TFC
> Stack deployment run. Wait for each run to complete before proceeding.

### Step 1: Deploy with database enabled in stage

1. Verify `deployments.tfdeploy.hcl` has `enable_database = true` in the
   `stage` deployment (dev and prod have it `false`).
2. Push this repo to the branch your Stack is tracking.
3. In HCP Terraform, approve and apply all three deployments.
4. **Wait for all runs to complete.** Stage creates `random_pet`, `time_sleep`,
   and `random_id` resources. Dev and prod only create `random_id` (app) resources.

### Step 2: Disable the database in stage (triggers the bug)

1. In `deployments.tfdeploy.hcl`, change stage's `enable_database = true` to
   `enable_database = false`.
2. Commit and push. This triggers a new TFC Stack run.
3. In HCP Terraform, approve and apply.
4. TFC plans two actions in the same apply:
   - **Delete** database component (for_each becomes empty)
   - **Update** app component (random_id recreated because endpoint changes to "none")
5. The apply begins: database resources start destroying (5-min time_sleep),
   app resources get updated.
6. **Expected bug:** TFC schedules a convergence plan. The convergence plan
   re-evaluates the deleted database component. `PlanPrevInputs()` returns an
   empty map, and `checkInputVariables()` errors:

```
Error: Unassigned variable
The input variable "reader_instance_class" has not been assigned a value.
This is a bug in Terraform; please report it in a GitHub issue.
```

### Step 3: Observe the catch-22 (no resolution possible)

The stack is now stuck. Every option leads to an error:

- **Add a `removed` block** -> same "Unassigned variable" error on every plan
- **Leave the component as-is** -> convergence plans keep failing
- **No `terraform stacks state rm` command exists** to manually clean up
- **Stacks state API is read-only** -> cannot remove orphaned component entries

## Workaround (from production experience)

The only workaround found was to temporarily empty all module files (zero
variables, zero resources, zero outputs) so `checkInputVariables()` iterates
zero times. After applying that, restore module files and remove the component.
This required 4 separate PRs/applies in production.
