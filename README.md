# AWS EKS Terraform Template

A batteries-included Terraform template for spinning up a production-ready EKS cluster on AWS. Click **Use this template** to start your own repo.

## What's included

| File | Purpose |
|---|---|
| `terraform/versions.tf` | Provider version pins |
| `terraform/providers.tf` | AWS, Helm, Kubernetes, kubectl providers |
| `terraform/variables.tf` | All input variables |
| `terraform/network.tf` | VPC + subnets (3 AZs, single NAT gateway) |
| `terraform/cluster.tf` | EKS cluster + bootstrap managed node group |
| `terraform/karpenter.tf` | Karpenter IAM, Helm release, EC2NodeClass, NodePool |
| `terraform/argocd.tf` | Argo CD Helm release + root app-of-apps Application |
| `terraform/outputs.tf` | Useful post-deploy commands |
| `Makefile` | `init` / `plan` / `apply` / `destroy` / `validate` / `fmt` |

### Cluster shape

- **VPC**: 3 private + 3 public subnets, single NAT gateway (~$32/mo)
- **Bootstrap node group**: 2× `t3.medium` (managed, always-on) — runs system pods and Karpenter controller
- **Karpenter NodePool**: spot-first, c/m/r families, 2–8 vCPU, x86, auto-consolidation
- **Argo CD**: insecure mode (port-forward), app-of-apps pattern watching `gitops/`
- **State backend**: S3 (configurable per environment via `backend.tfvars`)

## Prerequisites

- Terraform >= 1.6
- AWS CLI with SSO configured
- `kubectl`, `helm`

## Quick start

```bash
# 1. Copy example config files
cp terraform/env/dev/backend.tfvars.example  terraform/env/dev/dev.backend.tfvars
cp terraform/env/dev/terraform.tfvars.example terraform/env/dev/dev.terraform.tfvars

# 2. Fill in both files (S3 bucket, AWS profile, cluster name, GitOps repo URL)

# 3. Log in and init
aws sso login --profile <your-profile>
make init dev

# 4. Review and apply
make plan  dev
make apply dev
```

## Makefile reference

```
make init    dev
make plan    dev
make plan    dev  target='module.eks'
make apply   dev
make apply   dev  auto=true
make destroy dev  target='module.karpenter'  auto=true
make fmt
```

## Environments

The Makefile supports `dev`, `staging`, and `prod`. Add an env by creating:

```
terraform/env/<env>/<env>.backend.tfvars
terraform/env/<env>/<env>.terraform.tfvars
```

Then run `make init <env>`.

## Post-deploy

Terraform outputs the commands you need:

```bash
# Wire kubectl
aws eks update-kubeconfig --region <region> --name <cluster-name>

# Get Argo CD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo

# Access Argo CD UI at http://localhost:8080
kubectl port-forward -n argocd svc/argocd-server 8080:80
```
