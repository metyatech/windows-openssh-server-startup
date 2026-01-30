Set-StrictMode -Version Latest

$moduleRoot = Split-Path -Parent $PSCommandPath

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
    return $result
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
    return $result
}

Export-ModuleMember -Function Start-OpenSshServer, Stop-OpenSshServer
