#!/usr/bin/env bash
# Run kubectl against an emulated EKS cluster.
#
# The cluster's Kubernetes API listens only inside the emulator container
# (https://127.0.0.1:<port>). This script:
#   1. reads the endpoint + CA via DescribeCluster and an EKS token via `aws eks get-token`
#      (using scripts/aws.sh),
#   2. runs the official kubectl image on the emulator's network with those values.
#
# Notes (emulator limits):
#   - The emulator does NOT run containers: pods are accepted but end in phase Failed.
#   - Only core v1, rbac.authorization.k8s.io/v1, authentication.k8s.io/v1 are served
#     (no apps/v1 -> no Deployments).
#   - /openapi/v2 is missing, so `apply`/`create -f` need --validate=false.
#   - DELETE on pods is refused (MethodNotAllowed).
#   - The token is valid ~15 minutes; it is fetched fresh on every call.
#   - -f paths are relative to the project root (mounted at /work).
#
# Example:
#   ./scripts/kubectl.sh get nodes
#   ./scripts/kubectl.sh get ns
#   ./scripts/kubectl.sh apply --validate=false -f k8s/nginx-pod.yaml
#   ./scripts/kubectl.sh --cluster other get pod,svc -n demo
set -uo pipefail

cluster=eks-test1
kubectl_version=v1.33.0
emulator_container=aws-emulator

if [[ "${1:-}" == "--cluster" && -n "${2:-}" ]]; then
    cluster="$2"
    shift 2
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
aws_sh="$script_dir/aws.sh"

info="$("$aws_sh" eks describe-cluster --name "$cluster" \
    --query 'cluster.[endpoint,certificateAuthority.data]' --output text)"
if [[ $? -ne 0 || -z "$info" ]]; then echo "describe-cluster failed for '$cluster'" >&2; exit 1; fi
read -r endpoint ca_data <<< "$info"

token="$("$aws_sh" eks get-token --cluster-name "$cluster" --query status.token --output text)"
if [[ $? -ne 0 || -z "$token" ]]; then echo "get-token failed for '$cluster'" >&2; exit 1; fi

# CA file in a per-run temp dir (mounted read-only into the kubectl container).
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
echo "$ca_data" | base64 -d > "$tmp/ca.crt"

# Project root is mounted at /work (working dir), so `-f k8s/nginx-pod.yaml` works.
root="$(cd "$script_dir/.." && pwd)"
docker run --rm -i \
    --network "container:$emulator_container" \
    -v "${tmp}:/kube:ro" \
    -v "${root}:/work:ro" -w /work \
    "registry.k8s.io/kubectl:$kubectl_version" \
    --server="$endpoint" \
    --certificate-authority=/kube/ca.crt \
    --token="$token" \
    "$@"
exit $?
