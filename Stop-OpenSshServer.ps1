<#PSScriptInfo
.VERSION 0.3.8
.GUID d6e03cb4-a92f-4550-bdda-81093864c6a4
.AUTHOR metyatech
.COMPANYNAME metyatech
.COPYRIGHT (c) 2026 metyatech. All rights reserved.
.TAGS OpenSSH, SSH, Windows, Server, Stop
.DESCRIPTION Stop Windows OpenSSH Server and verify shutdown.
.LICENSEURI https://github.com/metyatech/windows-openssh-server-startup/blob/main/LICENSE
.PROJECTURI https://github.com/metyatech/windows-openssh-server-startup
.RELEASENOTES Suppress summary output when no action is needed.
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

$summaryPath = Join-Path $PSScriptRoot 'WindowsOpenSshServerStartup\Private\Output-OpenSshServerResult.ps1'
$modulePath = Join-Path $PSScriptRoot 'WindowsOpenSshServerStartup\Private\Stop-OpenSshServer.ps1'
. $summaryPath
. $modulePath

if ($Version -or $Help) {
    Invoke-OpenSshServerStop @PSBoundParameters
    exit 0
}

$result = Invoke-OpenSshServerStop @PSBoundParameters

if ($Json) {
    Write-Output ($result | ConvertTo-Json -Depth 6)
} else {
    $wantsDetailed = $Trace -or $Quiet -or ($VerbosePreference -ne 'SilentlyContinue')
    if ($wantsDetailed) {
        Write-Output $result
    } else {
        if (-not (Test-OpenSshServerResultSuppressSummary -Result $result)) {
            Write-Output (Get-OpenSshServerResultSummary -Result $result -Operation 'stop')
        }
    }
}

if ($null -ne $result -and $result.status -eq 'error') {
    exit 1
}

exit 0
