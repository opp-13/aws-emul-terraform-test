<#
.SYNOPSIS
  Run kubectl against an emulated EKS cluster.

.DESCRIPTION
  The cluster's Kubernetes API listens only inside the emulator container
  (https://127.0.0.1:<port>). This script:
    1. reads the endpoint + CA via DescribeCluster and an EKS token via `aws eks get-token`
       (using scripts/aws.ps1),
    2. runs the official kubectl image on the emulator's network with those values.

  Notes (emulator limits):
    - The emulator does NOT run containers: pods are accepted but end in phase Failed.
    - Only core v1, rbac.authorization.k8s.io/v1, authentication.k8s.io/v1 are served
      (no apps/v1 -> no Deployments).
    - /openapi/v2 is missing, so `apply`/`create -f` need --validate=false.
    - DELETE on pods is refused (MethodNotAllowed).
    - The token is valid ~15 minutes; it is fetched fresh on every call.
    - Quote comma lists in PowerShell: 'pod,svc' (unquoted, PowerShell splits it).
    - -f paths are relative to the project root (mounted at /work).

.EXAMPLE
  .\scripts\kubectl.ps1 get nodes
  .\scripts\kubectl.ps1 get ns
  .\scripts\kubectl.ps1 apply --validate=false -f k8s/nginx-pod.yaml
  .\scripts\kubectl.ps1 -Cluster other get 'pod,svc' -n demo
#>
# No param() block on purpose: PowerShell would swallow kubectl flags such as -o
# (ambiguous with -OutVariable). Only a leading "-Cluster <name>" is taken here.
$Cluster = 'eks-test1'
$KubectlVersion = 'v1.33.0'
$EmulatorContainer = 'aws-emulator'
$KubectlArgs = @($args)
if ($KubectlArgs.Count -ge 2 -and $KubectlArgs[0] -eq '-Cluster') {
    $Cluster = $KubectlArgs[1]
    $KubectlArgs = @($KubectlArgs | Select-Object -Skip 2)
}
$aws = Join-Path $PSScriptRoot 'aws.ps1'

$info = & $aws eks describe-cluster --name $Cluster `
    --query 'cluster.[endpoint,certificateAuthority.data]' --output text
if ($LASTEXITCODE -ne 0 -or -not $info) { throw "describe-cluster failed for '$Cluster'" }
$endpoint, $caData = ($info -split '\s+') | Where-Object { $_ }

$token = & $aws eks get-token --cluster-name $Cluster --query status.token --output text
if ($LASTEXITCODE -ne 0 -or -not $token) { throw "get-token failed for '$Cluster'" }

# CA file in a per-run temp dir (mounted read-only into the kubectl container).
$tmp = Join-Path ([IO.Path]::GetTempPath()) "emu-kube-$Cluster"
New-Item -ItemType Directory -Force $tmp | Out-Null
[IO.File]::WriteAllBytes((Join-Path $tmp 'ca.crt'), [Convert]::FromBase64String($caData.Trim()))

# Project root is mounted at /work (working dir), so `-f k8s/nginx-pod.yaml` works.
$root = Split-Path -Parent $PSScriptRoot
docker run --rm -i `
    --network "container:$EmulatorContainer" `
    -v "${tmp}:/kube:ro" `
    -v "${root}:/work:ro" -w /work `
    "registry.k8s.io/kubectl:$KubectlVersion" `
    --server=$($endpoint.Trim()) `
    --certificate-authority=/kube/ca.crt `
    --token=$($token.Trim()) `
    @KubectlArgs
exit $LASTEXITCODE
