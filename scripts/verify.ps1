Set-StrictMode -Version Latest

# Initialize LASTEXITCODE to avoid strict mode errors if no external command has run yet
$global:LASTEXITCODE = 0

Write-Output "Running Lint..."
& (Join-Path $PSScriptRoot 'lint.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output "`nRunning Tests..."
& (Join-Path $PSScriptRoot 'test.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output "`nRunning Build..."
& (Join-Path $PSScriptRoot 'build.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output "`nVerification Successful!"
exit 0