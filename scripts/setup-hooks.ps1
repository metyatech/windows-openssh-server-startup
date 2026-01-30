Set-StrictMode -Version Latest

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot
try {
    git config core.hooksPath .githooks
    Write-Output 'Git hooks configured to use .githooks.'
} finally {
    Pop-Location
}
