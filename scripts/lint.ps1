Set-StrictMode -Version Latest

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$paths = @(
    (Join-Path $repoRoot 'Start-OpenSshServer.ps1'),
    (Join-Path $repoRoot 'Stop-OpenSshServer.ps1'),
    (Join-Path $repoRoot 'WindowsOpenSshServerStartup'),
    (Join-Path $repoRoot 'scripts'),
    (Join-Path $repoRoot 'tests')
)

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Error 'PSScriptAnalyzer is not installed. Run: Install-Module PSScriptAnalyzer -Scope CurrentUser'
    exit 1
}

$hasErrors = $false

Write-Output 'Running ScriptAnalyzer...'
$analyzerResults = foreach ($path in $paths) {
    Invoke-ScriptAnalyzer -Path $path -Recurse -Severity @('Warning', 'Error')
}
if ($analyzerResults) {
    $analyzerResults | Format-Table
    $hasErrors = $true
}

Write-Output 'Checking formatting...'
foreach ($path in $paths) {
    $files = if (Test-Path $path -PathType Leaf) { @($path) } else { Get-ChildItem -Path $path -Filter *.ps*1 -Recurse | Select-Object -ExpandProperty FullName }
    foreach ($file in $files) {
        $content = Get-Content -Raw -Path $file
        $formatted = Invoke-Formatter -ScriptDefinition $content
        if ($content -ne $formatted) {
            Write-Error "File is not formatted correctly: $file"
            $hasErrors = $true
        }
    }
}

if ($hasErrors) {
    exit 1
}

Write-Output 'Lint OK.'