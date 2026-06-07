# aws-stack-tf-default-template

Base scaffold for AWS Terraform stacks. Use **Use this template** (or `gh repo create --template espresso20/aws-stack-tf-default-template`) to start a new stack repo.

## Structure

```
.
├── Makefile                          # bootstrap / init / plan / apply / destroy / validate / fmt
├── scripts/
│   └── bootstrap-state.sh            # one-time S3 state-bucket creation
└── terraform/
    ├── main.tf                       # empty — add your resources here
    └── env/
        └── dev/
            ├── dev.backend.tfvars    # tf backend state variables
            └── dev.terraform.tfvars  # tf stack variables
        └── stage/
            ├── stage.backend.tfvars
            ├── stage.terraform.tfvars
```

## Quick start

```bash
aws sso login --profile <your-profile>
make bootstrap dev   # one-time: creates the versioned/encrypted S3 state bucket
make init dev
```

`make bootstrap` solves the chicken-and-egg of remote state — the bucket holding
Terraform state can't be managed by that same state. It reads profile/region from
`env/<env>/<env>.backend.tfvars`, and if `bucket` is still a placeholder it derives
a unique name (`tfstate-<account>-<region>`) and writes it back. Idempotent.

State locking uses S3's native lockfile (`use_lockfile = true`) — no DynamoDB
table required on Terraform >= 1.10.

## Makefile reference

```
make bootstrap dev
make init      dev
make plan      dev
make plan      dev  target='module.foo'
make apply     dev
make apply     dev  auto=true
make destroy   dev  target='module.foo'  auto=true
make fmt
```

Environments: `dev` | `staging` | `prod`
Add an env by creating `terraform/env/<env>/<env>.backend.tfvars` and `terraform/env/<env>/<env>.terraform.tfvars`.
