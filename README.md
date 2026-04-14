# Terraform Stacks `removed` Block Bug — Minimal Reproduction

Demonstrates a bug where a `removed` block that successfully destroys resources
errors with "Unassigned variable... This is a bug in Terraform" for every module
variable that was not explicitly passed in the component's `inputs` block.

Tracked in: hashicorp/terraform#XXXXX

## The Bug Trigger

The key pattern is **module variables with defaults that are NOT passed in the
component's `inputs` block**. In a real-world setup, modules often have many
variables with sensible defaults — only a subset are overridden via component
inputs. Those default-only variables are never stored in state.

After destroy, `PlanPrevInputs()` calls `InputsForComponent()` which only returns
variables that were explicitly stored (i.e., passed via `inputs`). Variables that
relied on their defaults are missing from the returned map. When
`checkInputVariables()` iterates over ALL declared module variables and checks
each one exists in `SetVariables`, the default-only variables fail the check.

In this repro, the module declares 6 variables but only 3 are passed in the
component `inputs` block. The other 3 (`extra_tags`, `storage_size_gb`,
`enable_backups`) have defaults and are intentionally omitted from `inputs`.

## Prerequisites

- An HCP Terraform account with Stacks enabled
- A Stack connected to a fork/clone of this repository (so you can push changes that trigger runs)
- No cloud credentials needed — the repro uses only the `hashicorp/random` provider

## How the reproduction works

This repro uses a single component (`database`) that creates `random_pet` resources.
A boolean variable `enable_database` controls whether the component is active (via
`for_each`) or being destroyed (via a `removed` block). The module has 6 variables
but only 3 are passed in the component's `inputs` block — the other 3 rely on their
defaults and are never stored in state.

The bug is triggered by deploying with the component enabled, then deploying again
with it disabled.

**This requires TWO separate deployment runs** — you cannot reproduce it in a single apply.

## Steps to Reproduce

> **Important:** Each "Push and apply" below is a separate git push to your
> connected branch, which triggers a separate TFC Stack deployment run. You must
> wait for each run to complete successfully before proceeding to the next step.

### Step 1: Deploy with the component enabled (first apply)

1. Verify `deployments.tfdeploy.hcl` has `enable_database = true` (this is the default).
2. Push this repo to the branch your Stack is tracking.
3. In HCP Terraform, approve and apply the deployment.
4. **Wait for the run to complete successfully.** You should see `random_pet` resources created.

### Step 2: Disable the component and deploy again (second apply — triggers the bug)

1. In `deployments.tfdeploy.hcl`, change `enable_database = true` to `enable_database = false`.
2. Commit and push the change. This triggers a new TFC Stack run.
3. In HCP Terraform, approve and apply the deployment.
4. The destroy phase executes and removes the `random_pet` resources from state.
5. A post-destroy validation then re-evaluates the module and **fails** with:

```
Error: Unassigned variable
The input variable "extra_tags" has not been assigned a value.
This is a bug in Terraform; please report it in a GitHub issue.
```

This error fires for every variable that was NOT in the component's `inputs`
block (`extra_tags`, `storage_size_gb`, `enable_backups`). These variables have
defaults and work fine during normal plans — the error only appears after destroy,
when `PlanPrevInputs()` can't find them in state because they were never stored.

### Step 3: Observe the catch-22 (no resolution possible)

The stack is now stuck. Every option leads to an error:

- **Keep the `removed` block** → same "Unassigned variable" error on every subsequent plan
- **Delete the `removed` block** → "Unclaimed component instance" error (orphaned state)
- **No `terraform stacks state rm` command exists** to manually clean up
- **Stacks state API is read-only** — cannot remove the orphaned component entry
