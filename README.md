# Terraform Stacks `removed` Block Bug — Minimal Reproduction

Demonstrates a bug where a `removed` block that successfully destroys resources
errors with "Unassigned variable... This is a bug in Terraform" for every module
variable — even when all variables have defaults.

Tracked in: hashicorp/terraform#XXXXX

## Prerequisites

- An HCP Terraform account with Stacks enabled
- A Stack connected to a fork/clone of this repository (so you can push changes that trigger runs)
- No cloud credentials needed — the repro uses only the `hashicorp/random` provider

## How the reproduction works

This repro uses a single component (`database`) that creates `random_pet` resources.
A boolean variable `enable_database` controls whether the component is active (via
`for_each`) or being destroyed (via a `removed` block). The bug is triggered by
deploying with the component enabled, then deploying again with it disabled.

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
The input variable "environment" has not been assigned a value.
This is a bug in Terraform; please report it in a GitHub issue.
```

This error repeats for every variable declared in the module (`environment`,
`name_prefix`, `pet_count`), even though all three have defaults.

### Step 3: Observe the catch-22 (no resolution possible)

The stack is now stuck. Every option leads to an error:

- **Keep the `removed` block** → same "Unassigned variable" error on every subsequent plan
- **Delete the `removed` block** → "Unclaimed component instance" error (orphaned state)
- **No `terraform stacks state rm` command exists** to manually clean up
- **Stacks state API is read-only** — cannot remove the orphaned component entry
