# The emulator keeps everything in memory. After it restarts, local tfstate
# points at resources that no longer exist; run this to start clean.
param([string]$Env = 'eks-test1')
$dir = Join-Path (Split-Path -Parent $PSScriptRoot) "env\$Env"
Get-ChildItem $dir -Filter 'terraform.tfstate*' -ErrorAction SilentlyContinue | Remove-Item -Force
Write-Host "Removed tfstate in $dir"
