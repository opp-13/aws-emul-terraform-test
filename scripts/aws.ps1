<#
.SYNOPSIS
  Run the AWS CLI inside a container on the emulator's network (bypasses Avast HTTPS scanning).

.EXAMPLE
  .\scripts\aws.ps1 s3 ls
  .\scripts\aws.ps1 ec2 describe-vpcs --output table
  .\scripts\aws.ps1 eks describe-cluster --name eks-test1
#>
# No param() block on purpose: every argument goes to the AWS CLI unchanged.
$Port = 9297
$AwsCliVersion = '2.27.50'
$EmulatorContainer = 'aws-emulator'
$AwsArgs = @($args)
$emu = Join-Path $env:USERPROFILE ".aws\emulator\$Port"

if (-not (docker ps -q --filter "name=^${EmulatorContainer}$")) {
    throw "Emulator container '$EmulatorContainer' is not running. Run .\scripts\start-emulator.ps1 first."
}

docker run --rm -i --user 0 `
    --network "container:$EmulatorContainer" `
    -v "${emu}:/emu:ro" `
    -e AWS_ENDPOINT_URL="https://127.0.0.1:$Port" `
    -e AWS_CA_BUNDLE=/emu/ca.pem `
    -e AWS_ACCESS_KEY_ID=emulator `
    -e AWS_SECRET_ACCESS_KEY=emulator `
    -e AWS_REGION=us-east-1 `
    -e AWS_DEFAULT_REGION=us-east-1 `
    -e AWS_EC2_METADATA_DISABLED=true `
    -e AWS_DISABLE_HOST_PREFIX_INJECTION=true `
    -e AWS_PAGER= `
    "amazon/aws-cli:$AwsCliVersion" @AwsArgs
exit $LASTEXITCODE
