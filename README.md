# aws-stack-tf-default-template

Base scaffold for AWS Terraform stacks. Use **Use this template** (or `gh repo create --template espresso20/aws-stack-tf-default-template`) to start a new stack repo.

## Structure

```
.
├── Makefile                          # init / plan / apply / destroy / validate / fmt
└── terraform/
    ├── main.tf                       # empty — add your resources here
    └── env/
        └── dev/
            ├── backend.tfvars.example
            └── terraform.tfvars.example
```

## Quick start

```bash
cp terraform/env/dev/backend.tfvars.example  terraform/env/dev/dev.backend.tfvars
cp terraform/env/dev/terraform.tfvars.example terraform/env/dev/dev.terraform.tfvars
# fill in both files, then:
aws sso login --profile <your-profile>
make init dev
```

## Makefile reference

```
make init     dev
make plan     dev
make plan     dev  target='module.foo'
make apply    dev
make apply    dev  auto=true
make destroy  dev  target='module.foo'  auto=true
make fmt
```

Environments: `dev` | `staging` | `prod`
Add an env by creating `terraform/env/<env>/<env>.backend.tfvars` and `terraform/env/<env>/<env>.terraform.tfvars`.
