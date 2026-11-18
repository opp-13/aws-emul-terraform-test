#!/usr/bin/env bash
# Start StackPort (https://github.com/DaviReisVieira/stackport), a web console
# for the emulator, on http://127.0.0.1:<stackport-port>.
#
# Runs in the emulator container's network namespace (same pattern as
# aws.sh/tf.sh/kubectl.sh) so the endpoint stays https://127.0.0.1:<port> and
# matches the emulator's self-signed certificate. The port is published by
# start-emulator.sh (a container joining another's netns can't publish its own).
#
# Example:
#   ./scripts/stackport.sh                  # http://127.0.0.1:8080
#   ./scripts/stackport.sh --stackport-port 8090
set -uo pipefail

port=9297
stackport_port=8080
image=davireis/stackport
name=stackport
emulator_container=aws-emulator

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port) port="$2"; shift 2 ;;
        --stackport-port) stackport_port="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

emu="$HOME/.aws/emulator/$port"

if [[ -z "$(docker ps -q --filter "name=^${emulator_container}$")" ]]; then
    echo "Emulator container '$emulator_container' is not running. Run ./scripts/start-emulator.sh first." >&2
    exit 1
fi

docker rm -f "$name" >/dev/null 2>&1 || true

docker run -d --rm --name "$name" \
    --network "container:$emulator_container" \
    -v "${emu}:/emu:ro" \
    -e AWS_ENDPOINT_URL="https://127.0.0.1:$port" \
    -e AWS_CA_BUNDLE=/emu/ca.pem \
    -e AWS_ACCESS_KEY_ID=emulator \
    -e AWS_SECRET_ACCESS_KEY=emulator \
    -e AWS_REGION=us-east-1 \
    -e AWS_DEFAULT_REGION=us-east-1 \
    -e STACKPORT_PORT="$stackport_port" \
    "$image" >/dev/null
if [[ $? -ne 0 ]]; then echo "docker run failed" >&2; exit 1; fi

echo "StackPort is up: http://127.0.0.1:$stackport_port"
