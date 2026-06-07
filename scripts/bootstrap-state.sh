#!/usr/bin/env bash
# =============================================================================
#  bootstrap-state.sh — one-time creation of the S3 bucket that holds Terraform
#  state for a given environment, before the first `make init <env>`.
#
#  Chicken-and-egg: the bucket storing Terraform state can't be managed by that
#  same state. So we create it here, out-of-band. Idempotent — safe to re-run.
#
#  Reads profile / region / bucket from terraform/env/<env>/<env>.backend.tfvars.
#  If `bucket` is still a placeholder, a globally-unique name is derived from
#  your AWS account id + region and written back into that file.
#
#  The bucket gets versioning, default encryption, and a full public-access
#  block. State locking uses S3's native lockfile (set `use_lockfile = true` in
#  your backend config) — no DynamoDB table required on Terraform >= 1.10.
#
#  Usage:  ./scripts/bootstrap-state.sh <env>     # env: dev | staging | prod
#  Or via: make bootstrap <env>
# =============================================================================
set -euo pipefail

ENV="${1:-}"
if [ -z "${ENV}" ]; then
  echo "✗ usage: $0 <env>   (dev | staging | prod)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_TFVARS="${SCRIPT_DIR}/../terraform/env/${ENV}/${ENV}.backend.tfvars"

if [ ! -f "${BACKEND_TFVARS}" ]; then
  echo "✗ backend config not found: ${BACKEND_TFVARS}" >&2
  exit 1
fi

# Pull a (possibly quoted) value out of the backend tfvars:
#   profile = "foo"   ->  foo
tfvar() {
  grep -E "^[[:space:]]*$1[[:space:]]*=" "${BACKEND_TFVARS}" | head -1 \
    | sed -E 's/^[^=]*=[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/'
}

PROFILE="$(tfvar profile)"
REGION="$(tfvar region)"
BUCKET="$(tfvar bucket)"
REGION="${REGION:-us-east-1}"

if [ -z "${PROFILE}" ]; then
  echo "✗ no 'profile' set in ${BACKEND_TFVARS}" >&2
  exit 1
fi

echo "» Verifying credentials for profile '${PROFILE}'..."
if ! ACCOUNT_ID="$(aws sts get-caller-identity --profile "${PROFILE}" --query Account --output text 2>/dev/null)"; then
  echo "✗ No valid session. Run: aws sso login --profile ${PROFILE}" >&2
  exit 1
fi
echo "  account: ${ACCOUNT_ID}  region: ${REGION}"

# Derive a globally-unique bucket name if the tfvars still holds a placeholder.
case "${BUCKET}" in
  "" | your-terraform-state-bucket | CHANGE_ME*)
    BUCKET="tfstate-${ACCOUNT_ID}-${REGION}"
    echo "» No real bucket set — deriving: ${BUCKET}"
    ;;
  *)
    echo "» Using bucket from backend config: ${BUCKET}"
    ;;
esac

if aws s3api head-bucket --bucket "${BUCKET}" --profile "${PROFILE}" 2>/dev/null; then
  echo "  already exists — skipping create."
else
  echo "  creating..."
  # us-east-1 is special: the API rejects a LocationConstraint for it.
  if [ "${REGION}" = "us-east-1" ]; then
    aws s3api create-bucket --bucket "${BUCKET}" --profile "${PROFILE}" >/dev/null
  else
    aws s3api create-bucket --bucket "${BUCKET}" --profile "${PROFILE}" \
      --create-bucket-configuration "LocationConstraint=${REGION}" >/dev/null
  fi
fi

echo "» Enabling versioning (lets us recover a clobbered state file)..."
aws s3api put-bucket-versioning --bucket "${BUCKET}" --profile "${PROFILE}" \
  --versioning-configuration Status=Enabled

echo "» Enabling default encryption (SSE-S3 / AES256)..."
aws s3api put-bucket-encryption --bucket "${BUCKET}" --profile "${PROFILE}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "» Blocking all public access..."
aws s3api put-public-access-block --bucket "${BUCKET}" --profile "${PROFILE}" \
  --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

# Persist the resolved bucket name back into the backend config.
# Portable in-place edit (no GNU/BSD `sed -i` divergence).
if [ "$(tfvar bucket)" != "${BUCKET}" ]; then
  echo "» Writing bucket name into ${ENV}.backend.tfvars..."
  tmp="$(mktemp)"
  sed -E "s|^([[:space:]]*bucket[[:space:]]*=).*|\\1 \"${BUCKET}\"|" "${BACKEND_TFVARS}" >"${tmp}"
  mv "${tmp}" "${BACKEND_TFVARS}"
fi

echo ""
echo "✓ State backend ready for '${ENV}'. Next:"
echo "    make init ${ENV}"
