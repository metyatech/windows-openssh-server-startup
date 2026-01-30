#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [switch]$AutoFix,
    [Alias('Force')]
    [switch]$Yes,
    [switch]$DryRun,
    [ValidateRange(1, 65535)]
    [int]$Port = 22,
    [string]$FirewallRuleName = 'OpenSSH-Server-In-TCP',
    [switch]$Json,
    [switch]$Quiet,
    [switch]$Trace,
    [switch]$Version,
    [switch]$Help
)

Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot 'src\Start-OpenSshServer.ps1'
. $modulePath

if ($Version -or $Help) {
    Invoke-OpenSshServerStartup @PSBoundParameters
    exit 0
}

$result = Invoke-OpenSshServerStartup @PSBoundParameters

if ($Json) {
    Write-Output ($result | ConvertTo-Json -Depth 6)
}

if ($null -ne $result -and $result.status -eq 'error') {
    exit 1
}

exit 0
