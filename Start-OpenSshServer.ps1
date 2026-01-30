<#PSScriptInfo
.VERSION 0.3.3
.GUID 5ca8d653-4ca4-4520-a61e-ca6c61b75618
.AUTHOR metyatech
.COMPANYNAME metyatech
.COPYRIGHT (c) 2026 metyatech. All rights reserved.
.TAGS OpenSSH, SSH, Windows, Server, Startup
.DESCRIPTION Start and validate Windows OpenSSH Server with optional remediation.
.LICENSEURI https://github.com/metyatech/windows-openssh-server-startup/blob/main/LICENSE
.PROJECTURI https://github.com/metyatech/windows-openssh-server-startup
.RELEASENOTES Use encoded command for elevation to support module paths.
#>
#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [switch]$AutoFix,
    [switch]$NoAutoFix,
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

$modulePath = Join-Path $PSScriptRoot 'WindowsOpenSshServerStartup\Private\Start-OpenSshServer.ps1'
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
