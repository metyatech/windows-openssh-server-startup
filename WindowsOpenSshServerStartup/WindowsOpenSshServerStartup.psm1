Set-StrictMode -Version Latest

$moduleRoot = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $moduleRoot

. (Join-Path $repoRoot 'src\Start-OpenSshServer.ps1')
. (Join-Path $repoRoot 'src\Stop-OpenSshServer.ps1')

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

    $result = Invoke-OpenSshServerStop @PSBoundParameters
    if ($Json) {
        return ($result | ConvertTo-Json -Depth 6)
    }
    return $result
}

Export-ModuleMember -Function Start-OpenSshServer, Stop-OpenSshServer
