<#
.SYNOPSIS
  Start StackPort (https://github.com/DaviReisVieira/stackport), a web console
  for the emulator, on http://127.0.0.1:<StackportPort>.

.DESCRIPTION
  Runs in the emulator container's network namespace (same pattern as
  aws.ps1/tf.ps1/kubectl.ps1) so the endpoint stays https://127.0.0.1:<Port>
  and matches the emulator's self-signed certificate. The port is published
  by start-emulator.ps1 (a container joining another's netns can't publish
  its own).

.EXAMPLE
  .\scripts\stackport.ps1                        # http://127.0.0.1:8080
  .\scripts\stackport.ps1 -StackportPort 8090
#>
param(
    [int]$Port = 9297,
    [int]$StackportPort = 8080
)
$ErrorActionPreference = 'Continue'
$Image = 'davireis/stackport'
$Name = 'stackport'
$EmulatorContainer = 'aws-emulator'
$emu = Join-Path $env:USERPROFILE ".aws\emulator\$Port"

if (-not (docker ps -q --filter "name=^${EmulatorContainer}$")) {
    throw "Emulator container '$EmulatorContainer' is not running. Run .\scripts\start-emulator.ps1 first."
}

docker rm -f $Name 2>$null | Out-Null

docker run -d --rm --name $Name `
    --network "container:$EmulatorContainer" `
    -v "${emu}:/emu:ro" `
    -e AWS_ENDPOINT_URL="https://127.0.0.1:$Port" `
    -e AWS_CA_BUNDLE=/emu/ca.pem `
    -e AWS_ACCESS_KEY_ID=emulator `
    -e AWS_SECRET_ACCESS_KEY=emulator `
    -e AWS_REGION=us-east-1 `
    -e AWS_DEFAULT_REGION=us-east-1 `
    -e STACKPORT_PORT=$StackportPort `
    $Image | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'docker run failed' }

Write-Host "StackPort is up: http://127.0.0.1:$StackportPort"
