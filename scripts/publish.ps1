#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$apiKey = $env:PSGALLERY_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'PSGALLERY_API_KEY is not set. Set it to your PowerShell Gallery API key and rerun.'
}

$env:DOTNET_CLI_UI_LANGUAGE = 'en-US'

Write-Output "Running build to prepare artifacts..."
$buildScript = Join-Path $PSScriptRoot 'build.ps1'
& $buildScript
if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$moduleName = 'WindowsOpenSshServerStartup'
$modulePath = Join-Path $repoRoot $moduleName

Publish-Module -Path $modulePath -Repository PSGallery -NuGetApiKey $apiKey -ErrorAction Stop

$installed = Get-InstalledModule -Name $moduleName -ErrorAction SilentlyContinue
if ($installed) {
    Update-Module -Name $moduleName -Scope CurrentUser -Force -ErrorAction Stop
}
