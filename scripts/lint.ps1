Set-StrictMode -Version Latest

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$paths = @(
    (Join-Path $repoRoot 'Start-OpenSshServer.ps1'),
    (Join-Path $repoRoot 'src'),
    (Join-Path $repoRoot 'scripts'),
    (Join-Path $repoRoot 'tests')
)

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Error 'PSScriptAnalyzer is not installed. Run: Install-Module PSScriptAnalyzer -Scope CurrentUser'
    exit 1
}

$results = foreach ($path in $paths) {
    Invoke-ScriptAnalyzer -Path $path -Recurse -Severity @('Warning', 'Error')
}
if ($results) {
    $results | Format-Table
    exit 1
}

Write-Output 'Lint OK.'
