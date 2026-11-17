<#
.SYNOPSIS
  Run Terraform inside a container that shares the emulator container's network.

.DESCRIPTION
  On this PC, Avast Web Shield intercepts local HTTPS (it re-signs 127.0.0.1:9297 and
  breaks Terraform's own plugin mTLS). Running Terraform in a container on the emulator's
  network namespace keeps all traffic off the Windows network stack, so nothing is
  intercepted, and 127.0.0.1:9297 still matches the emulator's certificate.

.EXAMPLE
  .\scripts\tf.ps1 init
  .\scripts\tf.ps1 apply -auto-approve
  .\scripts\tf.ps1 -Env eks-test1 output
#>
# No param() block on purpose: PowerShell would swallow Terraform flags such as
# -out=... (ambiguous with -OutVariable). Only a leading "-Env <name>" is taken here.
$Env = 'eks-test1'
$Port = 9297
$TerraformVersion = '1.13.4'
$EmulatorContainer = 'aws-emulator'
$TfArgs = @($args)
if ($TfArgs.Count -ge 2 -and $TfArgs[0] -eq '-Env') {
    $Env = $TfArgs[1]
    $TfArgs = @($TfArgs | Select-Object -Skip 2)
}
$root = Split-Path -Parent $PSScriptRoot
$emu  = Join-Path $env:USERPROFILE ".aws\emulator\$Port"

if (-not (docker ps -q --filter "name=^${EmulatorContainer}$")) {
    throw "Emulator container '$EmulatorContainer' is not running. Run .\scripts\start-emulator.ps1 first."
}

# Linux provider binaries go to a separate data dir so they don't mix with a
# Windows-side .terraform directory.
docker run --rm -i --user 0 `
    --network "container:$EmulatorContainer" `
    -v "${root}:/work" `
    -v "${emu}:/emu:ro" `
    -v "aws-emul-tf-plugin-cache:/plugin-cache" `
    -w "/work/env/$Env" `
    -e TF_DATA_DIR=.terraform-linux `
    -e TF_PLUGIN_CACHE_DIR=/plugin-cache `
    -e TF_IN_AUTOMATION=1 `
    -e AWS_ENDPOINT_URL="https://127.0.0.1:$Port" `
    -e AWS_CA_BUNDLE=/emu/ca.pem `
    -e AWS_ACCESS_KEY_ID=emulator `
    -e AWS_SECRET_ACCESS_KEY=emulator `
    -e AWS_REGION=us-east-1 `
    -e AWS_DEFAULT_REGION=us-east-1 `
    -e AWS_EC2_METADATA_DISABLED=true `
    -e AWS_DISABLE_HOST_PREFIX_INJECTION=true `
    "hashicorp/terraform:$TerraformVersion" @TfArgs
exit $LASTEXITCODE
