Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$paths = @(
    (Join-Path $repoRoot 'Start-OpenSshServer.ps1'),
    (Join-Path $repoRoot 'WindowsOpenSshServerStartup'),
    (Join-Path $repoRoot 'scripts'),
    (Join-Path $repoRoot 'tests')
)

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Error 'PSScriptAnalyzer is not installed. Run: Install-Module PSScriptAnalyzer -Scope CurrentUser'
    exit 1
}

$settingsPath = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
$analyzerParams = @{
    Recurse = $true
    Severity = @('Warning', 'Error')
}

if (Test-Path $settingsPath) {
    $analyzerParams['Settings'] = $settingsPath
}

$results = foreach ($path in $paths) {
    Invoke-ScriptAnalyzer -Path $path @analyzerParams
}

if ($results) {
    $results | Format-Table
    exit 1
}

Write-Output 'Lint OK.'
