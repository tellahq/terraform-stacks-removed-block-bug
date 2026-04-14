# Terraform Stacks `removed` Block Bug — Minimal Reproduction

Demonstrates a bug where a `removed` block that successfully destroys resources
errors with "Unassigned variable... This is a bug in Terraform" for every module
variable that was not explicitly passed in the component's `inputs` block.

Tracked in: hashicorp/terraform#XXXXX

## The Bug Trigger

There are TWO ingredients required:

### 1. Module variables with defaults not in component inputs

Modules often have many variables with sensible defaults — only a subset are
overridden via component inputs. Those default-only variables are never stored
in state. After destroy, `PlanPrevInputs()` returns an empty map, and
`checkInputVariables()` errors on every declared variable.

### 2. Multiple deployments where some NEVER had the component enabled

This is the critical detail. When multiple deployments share the same component
configuration, the `removed` block evaluates for ALL deployments. A deployment
that never created the component still has the removed block claim instances
via `for_each`. TFC evaluates the module for that deployment's state (which is
empty for this component), and the variable validation fails.

In the real-world case: three deployments (dev, stage, prod). Only stage ever
had Aurora/OpenSearch enabled. Dev and prod never did. When stage disables
Aurora, the removed block evaluates for all three deployments. Dev and prod
have no prior state for this component, triggering the bug.

## Prerequisites

- An HCP Terraform account with Stacks enabled
- A Stack connected to a fork/clone of this repository
- No cloud credentials needed — uses only `hashicorp/random` provider

## Repository Structure

```
components.tfcomponent.hcl   # 3 components: database (conditional), cache (conditional), app (always)
deployments.tfdeploy.hcl     # 2 deployments: dev (never enables database), stage (enables then disables)
variables.tfcomponent.hcl    # Stack-level variables
modules/
  database/                  # Conditional component (like temporal-aurora). Has vars with defaults not in inputs.
  cache/                     # Second conditional component (like temporal-opensearch). Tests multiple removed blocks.
  app/                       # Always-on component that references database/cache outputs cross-component.
```

## How the reproduction works

This repro mirrors the real infrastructure pattern:

- **Two deployments** ("dev" and "stage") — dev never enables database, stage does
- **Conditional components** using `var.enable_database ? var.regions : toset([])`
- **Cross-component references** — the "app" component reads database/cache outputs
- **Multiple removed blocks** — both database and cache have removed blocks
- **Unpassed module variables** — database and cache modules declare variables with
  defaults that are never passed via component inputs

**This requires TWO separate deployment runs** — you cannot reproduce it in a single apply.

## Steps to Reproduce

> **Important:** Each step is a separate git push that triggers a separate TFC
> Stack deployment run. Wait for each run to complete before proceeding.

### Step 1: Deploy with the component enabled (first apply)

1. Verify `deployments.tfdeploy.hcl` has `enable_database = true` in the "stage" deployment.
2. Push this repo to the branch your Stack is tracking.
3. In HCP Terraform, approve and apply BOTH deployments (dev and stage).
4. **Wait for both runs to complete successfully.** Stage creates `random_pet` resources.
   Dev creates only the "app" component (no database).

### Step 2: Disable the component and deploy again (second apply — triggers the bug)

1. In `deployments.tfdeploy.hcl`, change stage's `enable_database = true` to `enable_database = false`.
2. Commit and push the change. This triggers new TFC Stack runs for both deployments.
3. In HCP Terraform, approve and apply.
4. **Expected bug:** The removed block evaluates for BOTH deployments:
   - **Stage:** Destroy runs, removes resources. Post-destroy validation may fail.
   - **Dev:** Removed block tries to claim `component.database["us-east-1"]` which
     never existed in dev's state. `PlanPrevInputs()` returns empty map.
     `checkInputVariables()` finds declared variables (`extra_tags`, `storage_size_gb`,
     `enable_backups`) unassigned and errors:

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

The only workaround found was to temporarily empty all module files (zero variables,
zero resources, zero outputs) so `checkInputVariables()` iterates zero times. After
applying that, restore module files and delete removed blocks. This required 4
separate PRs/applies in production.
