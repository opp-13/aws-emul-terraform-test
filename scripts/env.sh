#!/usr/bin/env bash
# Source in the current shell:  source ./scripts/env.sh [port]
# Points AWS CLI / SDKs / Terraform AWS provider at the local emulator.

if ! (return 0 2>/dev/null); then
    echo "This script must be sourced, not executed: source ./scripts/env.sh" >&2
    exit 1
fi

_env_port="${1:-9297}"
_env_dir="$HOME/.aws/emulator/$_env_port"

# Never let real credentials leak into emulator runs.
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE

export AWS_ENDPOINT_URL="https://127.0.0.1:$_env_port"   # keep 127.0.0.1 (not localhost) for S3 path-style

_env_credfile="$_env_dir/emulator_credentials"
if [[ -f "$_env_credfile" ]]; then
    # Emulator started with -a on: use the key pair it generated.
    export AWS_SHARED_CREDENTIALS_FILE="$_env_credfile"
else
    # Emulator started with -a off: no credentials file is written, but SDKs still
    # need *some* key to sign with. Dummy values; never real ones.
    export AWS_SHARED_CREDENTIALS_FILE="$_env_dir/none"
    export AWS_ACCESS_KEY_ID=emulator
    export AWS_SECRET_ACCESS_KEY=emulator
fi
export AWS_CONFIG_FILE="$_env_dir/config"
export AWS_CA_BUNDLE="$_env_dir/ca.pem"
export AWS_EC2_METADATA_DISABLED=true
export AWS_DISABLE_HOST_PREFIX_INJECTION=true
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1

echo "AWS env -> emulator at $AWS_ENDPOINT_URL"

unset _env_port _env_dir _env_credfile
