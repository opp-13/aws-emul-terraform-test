#!/usr/bin/env bash
# Build (if needed) and start AWS Emulator in Docker on 127.0.0.1:<port>.
#
# --auth off (default) disables SigV4 checks. Needed for aws_s3_bucket because of
# https://github.com/aws/aws-emulator/issues/353 (anonymous HeadBucket -> 403).
#
# Also publishes --stackport-port (default 8080) so scripts/stackport.sh can
# join this container's network afterwards and be reachable from the host.
set -uo pipefail

port=9297
auth=off
rebuild=0
image=aws-emulator
name=aws-emulator
stackport_port=8080

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port) port="$2"; shift 2 ;;
        --auth) auth="$2"; shift 2 ;;
        --rebuild) rebuild=1; shift ;;
        --image) image="$2"; shift 2 ;;
        --name) name="$2"; shift 2 ;;
        --stackport-port) stackport_port="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$rebuild" -eq 1 || -z "$(docker images -q "$image")" ]]; then
    docker build -t "$image" "$root/emulator"
    if [[ $? -ne 0 ]]; then echo "docker build failed" >&2; exit 1; fi
fi

shared="$HOME/.aws/emulator"
mkdir -p "$shared"

# Remove a previous container with the same name (state is in-memory anyway).
docker rm -f "$name" >/dev/null 2>&1 || true

# Also publish the StackPort web console port here: a container that joins
# this container's network (--network container:aws-emulator, see stackport.sh)
# cannot publish its own ports, so the port has to be published by this one.
docker run -d --rm --name "$name" --memory=2g --memory-swap=2g \
    -p "127.0.0.1:${port}:${port}" \
    -p "127.0.0.1:${stackport_port}:${stackport_port}" \
    -v "${shared}:/home/emulator/.aws/emulator" \
    "$image" -p "$port" -a "$auth" --telemetry off >/dev/null
if [[ $? -ne 0 ]]; then echo "docker run failed" >&2; exit 1; fi

ca="$shared/$port/ca.pem"
echo "Waiting for https://127.0.0.1:$port/__admin/health ..."
for ((i = 0; i < 60; i++)); do
    sleep 1
    if [[ -f "$ca" ]]; then
        out="$(curl -s --cacert "$ca" "https://127.0.0.1:$port/__admin/health")"
        if [[ "$out" == "ok" ]]; then
            echo "Emulator is up (auth=$auth). Next: source ./scripts/env.sh"
            exit 0
        fi
    fi
done
docker logs "$name"
echo "Emulator did not become healthy within 60s" >&2
exit 1
