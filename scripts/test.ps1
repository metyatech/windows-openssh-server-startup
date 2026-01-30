Set-StrictMode -Version Latest

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$testsPath = Join-Path $repoRoot 'tests'

if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Error 'Pester is not installed. Run: Install-Module Pester -Scope CurrentUser'
    exit 1
}

Import-Module Pester -MinimumVersion 5.0 -Force
Invoke-Pester -Path $testsPath -CI
