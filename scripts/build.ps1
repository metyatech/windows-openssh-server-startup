Set-StrictMode -Version Latest

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$scriptPath = Join-Path $repoRoot 'Start-OpenSshServer.ps1'
$stopScriptPath = Join-Path $repoRoot 'Stop-OpenSshServer.ps1'

$version = & $scriptPath -Version
if (-not $version) {
    Write-Error 'Build failed: version output is empty.'
    exit 1
}

$stopVersion = & $stopScriptPath -Version
if (-not $stopVersion) {
    Write-Error 'Build failed: stop script version output is empty.'
    exit 1
}

$licensePath = Join-Path $repoRoot 'LICENSE'
$modulePath = Join-Path $repoRoot 'WindowsOpenSshServerStartup'
$moduleLicensePath = Join-Path $modulePath 'LICENSE'

if (Test-Path $licensePath) {
    Copy-Item -Path $licensePath -Destination $moduleLicensePath -Force
    Write-Output "Copied LICENSE to $moduleLicensePath"
} else {
    Write-Warning "LICENSE file not found at $licensePath"
}

Write-Output "Build OK. Version: $version"
