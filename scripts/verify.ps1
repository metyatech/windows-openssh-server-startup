Set-StrictMode -Version Latest

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptsPath = Join-Path $repoRoot 'scripts'

Write-Output "Starting verification..."

Write-Output "`n[1/3] Running Lint..."
& (Join-Path $scriptsPath 'lint.ps1')
if (-not $?) {
    Write-Error "Lint failed."
    exit 1
}

Write-Output "`n[2/3] Running Build..."
& (Join-Path $scriptsPath 'build.ps1')
if (-not $?) {
    Write-Error "Build failed."
    exit 1
}

Write-Output "`n[3/3] Running Tests..."
& (Join-Path $scriptsPath 'test.ps1')
if (-not $?) {
    Write-Error "Tests failed."
    exit 1
}

Write-Output "`nVerification successful!"