<#
.SYNOPSIS
  Build (if needed) and start AWS Emulator in Docker on 127.0.0.1:<Port>.

.PARAMETER Auth
  'off' (default) disables SigV4 checks. Needed for aws_s3_bucket because of
  https://github.com/aws/aws-emulator/issues/353 (anonymous HeadBucket -> 403).
#>
param(
    [int]$Port = 9297,
    [ValidateSet('on', 'off')][string]$Auth = 'off',
    [switch]$Rebuild,
    [string]$Image = 'aws-emulator',
    [string]$Name = 'aws-emulator'
)
# 'Continue': in Windows PowerShell 5.1, docker's progress output on stderr would
# otherwise be raised as a terminating error. Failures are checked via $LASTEXITCODE.
$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot

if ($Rebuild -or -not (docker images -q $Image)) {
    docker build -t $Image (Join-Path $root 'emulator')
    if ($LASTEXITCODE -ne 0) { throw 'docker build failed' }
}

$shared = Join-Path $env:USERPROFILE '.aws\emulator'
New-Item -ItemType Directory -Force $shared | Out-Null

# Remove a previous container with the same name (state is in-memory anyway).
docker rm -f $Name 2>$null | Out-Null

docker run -d --rm --name $Name --memory=2g --memory-swap=2g `
    -p "127.0.0.1:${Port}:${Port}" `
    -v "${shared}:/home/emulator/.aws/emulator" `
    $Image -p $Port -a $Auth --telemetry off | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'docker run failed' }

$ca = Join-Path $shared "$Port\ca.pem"
Write-Host "Waiting for https://127.0.0.1:$Port/__admin/health ..."
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $ca) {
        $out = curl.exe -s --cacert $ca "https://127.0.0.1:$Port/__admin/health"
        if ($out -eq 'ok') { Write-Host "Emulator is up (auth=$Auth). Next: . .\scripts\env.ps1"; exit 0 }
    }
}
docker logs $Name
throw 'Emulator did not become healthy within 60s'
