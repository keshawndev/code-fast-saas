# Infrastructure

Terraform for code-fast-saas on AWS, split into **layers**. Each layer is its
own stack with its own state, applied in number order and destroyed in reverse.

```
infra/
├── bootstrap/            layer 00: shared, long-lived, applied once by hand
├── envs/
│   ├── dev/
│   │   ├── 10-network/   VPC, subnets, internet gateway, routes
│   │   └── 20-app/       security groups, ALB, ECS, DNS record, alarms
│   ├── staging/          same two layers
│   └── prod/             same two layers
└── modules/
    ├── network/          code for 10-network
    └── app/              code for 20-app
```

## Layers

| Layer | Holds | Changes | Cost while idle | Destroyed |
|---|---|---|---|---|
| `bootstrap` (00) | State bucket, ECR, Route 53 zone, certificate, deploy roles, budget, alerts topic | Rarely | ~$0.50/month | Never (`prevent_destroy` on state and zone) |
| `10-network` | VPC, 2 public subnets, internet gateway, route table | Almost never | $0 | Only on request |
| `20-app` | Security groups, ALB, target group, listeners, ECS, IAM roles, log group, DNS record, alarms, dashboard | Every deploy | ALB + Fargate | Every night at 07:00 UTC |

**Why two layers per environment:** the app changes on every deploy and costs
money; the network almost never changes and is free. Splitting them means a
deploy can't touch the VPC, and the nightly teardown only removes what costs
money.

## How the layers connect

`20-app` finds the network **by tag** (`Name = code-fast-saas-<env>`,
`Tier = public`) with data sources in `modules/app/network.tf`. It doesn't read
`10-network`'s state, so the layers stay loosely coupled. Keep those tags
stable.

State keys follow the folders: `s3://code-fast-saas-tfstate-929751801956/<env>/<layer>/terraform.tfstate`.
Each environment's deploy role can only reach its own `<env>/` prefix.

## Order

| Action | Order | Where |
|---|---|---|
| Deploy | `10-network` → `20-app` | `.github/workflows/ci.yml` (on push to dev, staging, prod) |
| Nightly teardown | `20-app` only | `.github/workflows/destroy.yml` (schedule) |
| Full teardown | `20-app` → `10-network` | Destroy workflow, **layers: everything** |

## Running a layer by hand

```bash
cd infra/envs/dev/10-network && terraform init && terraform apply
cd ../20-app && terraform init && terraform apply   # needs terraform.tfvars (see .example)
```

Destroy in reverse: `20-app` first, then `10-network`.
