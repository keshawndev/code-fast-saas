# Notes for Claude

Context and rules for working in this repo. The README has the full project
story; this is what matters when making changes.

## This repo is public

`keshawndev/code-fast-saas` on GitHub is public. Every push publishes. Only
this project's own work belongs here: no personal notes, no other projects'
code, nothing from outside the repo.

## Branches

- `dev` is the default branch. `staging` and `prod` are promoted from it.
- All three are protected (ruleset `environment-branches`): changes go in only
  through a pull request with passing checks. Never push to them directly.
- Work on a feature branch and open a PR into `dev`.
- Merging a PR deploys that branch's environment. `prod` waits for a required
  reviewer. Treat anything that reaches `prod` as live.

## Secrets

- Never commit `.env*` files (only `.env.example` is tracked) or put secrets
  in code, the Docker image, Terraform, or workflow files.
- In AWS, app secrets live in SSM Parameter Store and are injected when the
  container starts.
- CI reaches AWS through GitHub OIDC. There are no stored AWS keys, and none
  should be added.

## Infrastructure (Terraform, `infra/`)

- See `infra/README.md` for the layers and their order.
- `infra/bootstrap` (layer 00) is shared and long-lived: state bucket, ECR,
  Route 53 zone, certificate, deploy roles, budget, alerts. It's applied by
  hand and never destroyed (`prevent_destroy` on the state bucket and zone).
  Don't rework it casually.
- `infra/envs/{dev,staging,prod}` each have `10-network` and `20-app` layers.
  Apply in number order, destroy in reverse.
- `.github/workflows/destroy.yml` tears down `20-app` in every environment
  nightly; a manual run can remove the network too.
- Be careful with IAM, security groups, networking, and anything named `prod`.
  Show the plan and ask before applying changes to those.
- Ask before destructive AWS commands, such as `aws s3 rm` or deleting stacks
  or resources by hand.

## Checks a PR must pass (`.github/workflows/ci.yml`)

Lint (warnings fail the build), a Docker build, a container smoke test, and a
Trivy scan (HIGH/CRITICAL fail the build). Run what you can locally before
opening a PR.
