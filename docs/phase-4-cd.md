# Phase 4: Continuous Deployment

**Goal:** a merge deploys itself. Merging into `dev`, `staging`, or `prod`
builds the image, pushes it to ECR, and applies that environment's Terraform,
with no AWS keys stored in GitHub. Prod waits for a manual approval.

**Status:** in progress.

## Decisions So Far

- **Ephemeral environments.** Merges create or update an environment, and a
  scheduled workflow destroys all of them every night (plus a manual destroy
  button). An always-on environment costs about $35–40/month (load balancer,
  Fargate, public IPs), so three of them would blow past the $10 budget.
- **One domain per environment** in the existing Route 53 zone:
  `dev.project1.keshawnbarbary.com`, `staging.project1.keshawnbarbary.com`,
  and `project1.keshawnbarbary.com` for prod.
- **Branching stays the same:** `dev` → `staging` → `prod` through PRs. Each
  branch's merge deploys its own environment, and each builds its own image
  (the tradeoff noted in the README).

## Progress

### Step 1: Terraform checks in CI

Added a `Terraform` job to `ci.yml` that runs in parallel with `Lint`:

- `terraform fmt -check -recursive infra` fails on unformatted files.
- `terraform init -backend=false` and `terraform validate` for the bootstrap
  and dev stacks catch syntax errors and broken references.
- Pinned to Terraform 1.16.4, the same version I use locally.

Then added `Terraform` to the `environment-branches` ruleset's required
checks (after merging, so PRs never wait on a check that doesn't exist yet),
and verified the effective rules on `dev`: `Lint`, `Docker build`,
`Terraform`.

### Step 2: The dev stack as a reusable module

Moved the network, security group, IAM, ECS, ALB, and HTTPS files into
`infra/modules/app/` and replaced every hardcoded `dev` value with inputs:
`environment` (names and the SSM path), `domain` (the hostname and app URLs),
`zone_name`, `region`, `image_tag`, and `stripe_price_id`. `infra/envs/dev/`
now holds only the backend, the provider, and one `module "app"` call.

I did the refactor while dev was destroyed. Moving resources into a module
changes their addresses (`aws_vpc.main` becomes `module.app.aws_vpc.main`),
which would normally mean destroying and recreating everything or writing
`moved` blocks. With empty state, nothing had to move. The plan showed the
same 27 resources under `module.app.`, with dev now at
`dev.project1.keshawnbarbary.com`.

### Step 3: Certificate and stacks for every environment

- Added `dev.` and `staging.` to the ACM certificate as Subject Alternative
  Names. SANs can't be edited, so Terraform replaced the certificate. The
  plan showed `+/-` (create, then destroy) because of
  `create_before_destroy`, and the new certificate was issued before the old
  one was deleted. I chose explicit SANs over a wildcard, because ACM gives a
  wildcard and the bare name the same validation record, which collides in
  the `for_each` over validation records.
- Created `infra/envs/staging` and `infra/envs/prod` from dev's files: backend
  (`staging/terraform.tfstate`, `prod/terraform.tfstate`), provider tags, and
  one module call each. Prod uses the bare `project1.keshawnbarbary.com`.
  Each plans 27 resources with its own names, SSM path, and DNS record.
- CI now validates `infra/bootstrap` and every folder matching
  `infra/envs/*`, so a new environment is checked automatically.

## Problems I Solved

### 1. `validate` in CI failed with "No valid credential sources found"

- **Problem:** the new Terraform job passed for the bootstrap stack but failed for the dev stack during `init`, at `Initializing the backend...`, with `No valid credential sources found` and an `EC2 IMDS` error. (A planned drill.)
- **Cause:** the bootstrap stack keeps local state, so its `init` needs nothing from AWS. The dev stack's `backend "s3"` makes `init` connect to the state bucket, and the CI runner has no AWS credentials. It works on my laptop because of my SSO session. The `EC2 IMDS` message was just the AWS SDK's last fallback failing.
- **Fix:** `terraform init -backend=false`. `validate` only checks code against provider schemas and never needs state, so the check stays credential-free. Only the deploy job will get AWS access, through OIDC.

### 2. Commands that worked interactively failed in a pipe

- **Problem:** `gh run view --log-failed` showed a menu to pick a run, but `gh run view --log-failed | grep Error` failed with `run or job ID required when not running interactively`.
- **Cause:** when its output goes to a pipe instead of a terminal, `gh` can't show menus, so it needs explicit IDs.
- **Fix:** look up the run ID first (`gh run list -b <branch> -L 1 --json databaseId -q '.[0].databaseId'`), then `gh run view $R --log-failed | cut -f3- | grep -B3 -A10 "Error:"`. That cuts a 200-line log down to the few lines that explain the failure.

### 3. Updating the ruleset from the CLI

- **Problem:** the GitHub API needs the whole ruleset in an update, and a one-line pipeline to edit it wrapped when pasted. The `--jq` flag lost its argument, and the request failed before sending anything.
- **Fix:** broke it into steps with a file in the middle: fetch the ruleset, add the check with a small script, inspect the file (`grep` for the check names), then `PUT` it. Reviewing the file before sending it is the same habit as reading a Terraform plan before applying.

### 4. A certificate change replaced a record I expected to stay

- **Problem:** I expected the existing `project1` validation record to stay untouched, since the records are keyed by domain name. The plan showed it as `-/+`.
- **Cause:** the record's name comes from the new certificate's validation options, which are `(known after apply)` at plan time. Terraform can't know the new value will match, so it plans a replacement. ACM usually reuses the same validation record for the same domain, so the result was harmless.
- **Fix:** none needed. Applied while no listener used the certificate. Keying by domain still kept the record's identity, so nothing got renumbered.

## What I Learned (so far)

- "Works locally, fails in CI" usually means an environment difference:
  credentials, environment variables, files, or tool versions.
- Code checks shouldn't need cloud credentials. Keep linting and validation
  credential-free, and give access only to the jobs that deploy.
- A check only protects a branch once it's required. Merge the job first,
  then require it.
- A module is Terraform's function: write the infrastructure once and call
  it per environment. `terraform init` is needed again after adding one.
- When pasted code looks shifted, run `terraform fmt` right away. If `fmt`
  fails instead of fixing it, the block structure is broken.
- `forces replacement` next to `(known after apply)` often means "might
  change," not "will change." Think through what the real new value will be.
- Run `terraform fmt -recursive infra` before every commit. A longer
  argument name realigns every `=` in its block, and the CI check fails
  otherwise.
- Read CI logs from the bottom up: find the first `Error:` and the
  `##[group]Run` line before it, and ignore the setup noise.
