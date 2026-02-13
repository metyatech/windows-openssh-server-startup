Set-StrictMode -Version Latest

Write-Output "Running Lint..."
pwsh -NoProfile -File (Join-Path $PSScriptRoot 'lint.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Error "Lint failed."
    exit $LASTEXITCODE
}

Write-Output "Running Tests..."
pwsh -NoProfile -File (Join-Path $PSScriptRoot 'test.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Error "Tests failed."
    exit $LASTEXITCODE
}

Write-Output "Verification Passed."
