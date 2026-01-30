<#PSScriptInfo
.VERSION 0.2.1
.GUID d6e03cb4-a92f-4550-bdda-81093864c6a4
.AUTHOR metyatech
.COMPANYNAME metyatech
.COPYRIGHT (c) 2026 metyatech. All rights reserved.
.TAGS OpenSSH, SSH, Windows, Server, Stop
.LICENSEURI https://github.com/metyatech/windows-openssh-server-startup/blob/main/LICENSE
.PROJECTURI https://github.com/metyatech/windows-openssh-server-startup
.RELEASENOTES Add PowerShell Gallery metadata for distribution.
#>
#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [switch]$Force,
    [switch]$Yes,
    [switch]$DryRun,
    [ValidateRange(1, 65535)]
    [int]$Port = 22,
    [switch]$Json,
    [switch]$Quiet,
    [switch]$Trace,
    [switch]$Version,
    [switch]$Help
)

Set-StrictMode -Version Latest

$modulePath = Join-Path $PSScriptRoot 'src\Stop-OpenSshServer.ps1'
. $modulePath

if ($Version -or $Help) {
    Invoke-OpenSshServerStop @PSBoundParameters
    exit 0
}

$result = Invoke-OpenSshServerStop @PSBoundParameters

if ($Json) {
    Write-Output ($result | ConvertTo-Json -Depth 6)
}

if ($null -ne $result -and $result.status -eq 'error') {
    exit 1
}

exit 0
