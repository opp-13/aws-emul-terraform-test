#!/usr/bin/env bash
# Run the AWS CLI inside a container on the emulator's network (bypasses local HTTPS interception).
#
# Example:
#   ./scripts/aws.sh s3 ls
#   ./scripts/aws.sh ec2 describe-vpcs --output table
#   ./scripts/aws.sh eks describe-cluster --name eks-test1
set -uo pipefail

port=9297
aws_cli_version=2.27.50
emulator_container=aws-emulator
emu="$HOME/.aws/emulator/$port"

if [[ -z "$(docker ps -q --filter "name=^${emulator_container}$")" ]]; then
    echo "Emulator container '$emulator_container' is not running. Run ./scripts/start-emulator.sh first." >&2
    exit 1
fi

docker run --rm -i --user 0 \
    --network "container:$emulator_container" \
    -v "${emu}:/emu:ro" \
    -e AWS_ENDPOINT_URL="https://127.0.0.1:$port" \
    -e AWS_CA_BUNDLE=/emu/ca.pem \
    -e AWS_ACCESS_KEY_ID=emulator \
    -e AWS_SECRET_ACCESS_KEY=emulator \
    -e AWS_REGION=us-east-1 \
    -e AWS_DEFAULT_REGION=us-east-1 \
    -e AWS_EC2_METADATA_DISABLED=true \
    -e AWS_DISABLE_HOST_PREFIX_INJECTION=true \
    -e AWS_PAGER= \
    "amazon/aws-cli:$aws_cli_version" "$@"
exit $?
