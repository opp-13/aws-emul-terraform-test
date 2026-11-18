#!/usr/bin/env bash
# Run Terraform inside a container that shares the emulator container's network.
#
# This keeps all traffic off the host network stack (useful when something on the
# host, e.g. an AV HTTPS scanner, re-signs/intercepts local TLS and breaks
# Terraform's own plugin mTLS).
#
# Example:
#   ./scripts/tf.sh init
#   ./scripts/tf.sh apply -auto-approve
#   ./scripts/tf.sh --env eks-test1 output
set -uo pipefail

env_name=eks-test1
port=9297
terraform_version=1.13.4
emulator_container=aws-emulator

if [[ "${1:-}" == "--env" && -n "${2:-}" ]]; then
    env_name="$2"
    shift 2
fi

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
emu="$HOME/.aws/emulator/$port"

if [[ -z "$(docker ps -q --filter "name=^${emulator_container}$")" ]]; then
    echo "Emulator container '$emulator_container' is not running. Run ./scripts/start-emulator.sh first." >&2
    exit 1
fi

# Container-run provider binaries go to a separate data dir so they don't mix
# with a host-side .terraform directory.
docker run --rm -i --user 0 \
    --network "container:$emulator_container" \
    -v "${root}:/work" \
    -v "${emu}:/emu:ro" \
    -v "aws-emul-tf-plugin-cache:/plugin-cache" \
    -w "/work/env/$env_name" \
    -e TF_DATA_DIR=.terraform-linux \
    -e TF_PLUGIN_CACHE_DIR=/plugin-cache \
    -e TF_IN_AUTOMATION=1 \
    -e AWS_ENDPOINT_URL="https://127.0.0.1:$port" \
    -e AWS_CA_BUNDLE=/emu/ca.pem \
    -e AWS_ACCESS_KEY_ID=emulator \
    -e AWS_SECRET_ACCESS_KEY=emulator \
    -e AWS_REGION=us-east-1 \
    -e AWS_DEFAULT_REGION=us-east-1 \
    -e AWS_EC2_METADATA_DISABLED=true \
    -e AWS_DISABLE_HOST_PREFIX_INJECTION=true \
    "hashicorp/terraform:$terraform_version" "$@"
exit $?
