#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$apiKey = $env:PSGALLERY_API_KEY
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw 'PSGALLERY_API_KEY is not set. Set it to your PowerShell Gallery API key and rerun.'
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$startScript = Join-Path $repoRoot 'Start-OpenSshServer.ps1'
$stopScript = Join-Path $repoRoot 'Stop-OpenSshServer.ps1'

Publish-Script -Path $startScript -Repository PSGallery -NuGetApiKey $apiKey -ErrorAction Stop
Publish-Script -Path $stopScript -Repository PSGallery -NuGetApiKey $apiKey -ErrorAction Stop
