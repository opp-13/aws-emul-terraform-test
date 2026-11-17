# Dot-source in the current shell:  . .\scripts\env.ps1
# Points AWS CLI / SDKs / Terraform AWS provider at the local emulator.
param([int]$Port = 9297)

$dir = Join-Path $env:USERPROFILE ".aws\emulator\$Port"

# Never let real credentials leak into emulator runs.
Remove-Item Env:AWS_ACCESS_KEY_ID, Env:AWS_SECRET_ACCESS_KEY, Env:AWS_SESSION_TOKEN, Env:AWS_PROFILE -ErrorAction SilentlyContinue

$env:AWS_ENDPOINT_URL                  = "https://127.0.0.1:$Port"   # keep 127.0.0.1 (not localhost) for S3 path-style

$credFile = Join-Path $dir 'emulator_credentials'
if (Test-Path $credFile) {
    # Emulator started with -a on: use the key pair it generated.
    $env:AWS_SHARED_CREDENTIALS_FILE = $credFile
} else {
    # Emulator started with -a off: no credentials file is written, but SDKs still
    # need *some* key to sign with. Dummy values; never real ones.
    $env:AWS_SHARED_CREDENTIALS_FILE = Join-Path $dir 'none'
    $env:AWS_ACCESS_KEY_ID           = 'emulator'
    $env:AWS_SECRET_ACCESS_KEY       = 'emulator'
}
$env:AWS_CONFIG_FILE                   = Join-Path $dir 'config'
$env:AWS_CA_BUNDLE                     = Join-Path $dir 'ca.pem'
$env:AWS_EC2_METADATA_DISABLED         = 'true'
$env:AWS_DISABLE_HOST_PREFIX_INJECTION = 'true'
$env:AWS_REGION                        = 'us-east-1'
$env:AWS_DEFAULT_REGION                = 'us-east-1'

Write-Host "AWS env -> emulator at $env:AWS_ENDPOINT_URL"
