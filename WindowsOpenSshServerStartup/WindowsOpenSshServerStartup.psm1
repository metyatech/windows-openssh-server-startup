Set-StrictMode -Version Latest

$moduleRoot = Split-Path -Parent $PSCommandPath

. (Join-Path $moduleRoot 'Private\Output-OpenSshServerResult.ps1')
. (Join-Path $moduleRoot 'Private\Confirm-AutoFix.ps1')
. (Join-Path $moduleRoot 'Private\Start-OpenSshServer.ps1')
. (Join-Path $moduleRoot 'Private\Stop-OpenSshServer.ps1')

function Start-OpenSshServer {
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
        [Parameter(DontShow)]
        [hashtable]$Dependencies
    )

    if (-not $PSCmdlet.ShouldProcess('OpenSSH Server', 'Start')) {
        if (-not $WhatIfPreference) {
            return
        }
    }

    $result = Invoke-OpenSshServerStartup @PSBoundParameters
    if ($Json) {
        return ($result | ConvertTo-Json -Depth 6)
    }

    $wantsDetailed = $Trace -or $Quiet -or ($VerbosePreference -ne 'SilentlyContinue')
    if ($wantsDetailed) {
        return $result
    }

    if (Test-OpenSshServerResultSuppressSummary -Result $result) {
        return
    }

    return (Get-OpenSshServerResultSummary -Result $result -Operation 'start')
}

function Stop-OpenSshServer {
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
        [Parameter(DontShow)]
        [hashtable]$Dependencies
    )

    if (-not $PSCmdlet.ShouldProcess('OpenSSH Server', 'Stop')) {
        if (-not $WhatIfPreference) {
            return
        }
    }

    $result = Invoke-OpenSshServerStop @PSBoundParameters
    if ($Json) {
        return ($result | ConvertTo-Json -Depth 6)
    }

    $wantsDetailed = $Trace -or $Quiet -or ($VerbosePreference -ne 'SilentlyContinue')
    if ($wantsDetailed) {
        return $result
    }

    if (Test-OpenSshServerResultSuppressSummary -Result $result) {
        return
    }

    return (Get-OpenSshServerResultSummary -Result $result -Operation 'stop')
}

Export-ModuleMember -Function Start-OpenSshServer, Stop-OpenSshServer
