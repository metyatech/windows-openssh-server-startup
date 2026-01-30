Set-StrictMode -Version Latest

function Get-OpenSshServerStopVersion {
    '0.1.0'
}

function Get-OpenSshServerStopHelp {
    @"
Stop-OpenSshServer.ps1

Usage:
  .\Stop-OpenSshServer.ps1 [options]

Options:
  -Force             Force stop the sshd service.
  -DryRun            Preview actions without applying changes.
  -Port <int>        TCP port to verify sshd is no longer listening (default: 22).
  -Json              Emit machine-readable JSON output only.
  -Quiet             Suppress non-error output.
  -Trace             Emit verbose diagnostic output.
  -Version           Print version and exit.
  -Help              Print this help and exit.

Notes:
  - Use -WhatIf to simulate changes (PowerShell common parameter).
  - Use -Confirm to force confirmation prompts (PowerShell common parameter).
"@
}

function Test-IsAdmin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

$script:OpenSshStopDependencies = @{
    GetCommand = { param($Name) Get-Command -Name $Name -ErrorAction SilentlyContinue }
    GetService = { param($Name) Get-Service -Name $Name -ErrorAction Stop }
    StopService = { param($Name, $Force) Stop-Service -Name $Name -Force:$Force -ErrorAction Stop }
    GetNetTcpConnection = { param($Port) Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue }
    GetProcess = { param($Id) Get-Process -Id $Id -ErrorAction Stop }
}

function Get-StopResult {
    [pscustomobject]@{
        version = Get-OpenSshServerStopVersion
        status = 'success'
        stopped = $false
        checks = @()
        actions = @()
        warnings = @()
        errors = @()
    }
}

function Add-ResultItem {
    param(
        [Parameter(Mandatory)]
        [object]$Result,
        [Parameter(Mandatory)]
        [string]$Collection,
        [Parameter(Mandatory)]
        [object]$Item
    )

    $Result.$Collection += $Item
}

function Invoke-OpenSshServerStop {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [switch]$Force,
        [switch]$DryRun,
        [ValidateRange(1, 65535)]
        [int]$Port = 22,
        [switch]$Json,
        [switch]$Quiet,
        [switch]$Trace,
        [switch]$Version,
        [switch]$Help,
        [Parameter(DontShow)]
        [hashtable]$Dependencies
    )

    if ($Version) {
        Write-Output (Get-OpenSshServerStopVersion)
        return
    }

    if ($Help) {
        Write-Output (Get-OpenSshServerStopHelp)
        return
    }

    if ($Json) {
        $Quiet = $true
    }

    if ($Trace) {
        $VerbosePreference = 'Continue'
    }

    if ($DryRun) {
        $WhatIfPreference = $true
    }

    $result = Get-StopResult
    $deps = if ($Dependencies) { $Dependencies } else { $script:OpenSshStopDependencies }
    $isWindowsPlatform = [System.Environment]::OSVersion.Platform -eq 'Win32NT'

    function Write-StopLog {
        param(
            [Parameter(Mandatory)]
            [string]$Message,
            [ValidateSet('Info', 'Warning', 'Error', 'Verbose')]
            [string]$Level = 'Info'
        )

        if ($Quiet -and $Level -ne 'Error') {
            return
        }

        switch ($Level) {
            'Info' { Write-Information $Message -InformationAction Continue }
            'Warning' { Write-Warning $Message }
            'Error' { Write-Error $Message }
            'Verbose' { Write-Verbose $Message }
        }
    }

    function Register-Check {
        param(
            [string]$Id,
            [string]$Status,
            [string]$Message,
            [string]$Remediation
        )

        Add-ResultItem -Result $result -Collection 'checks' -Item ([pscustomobject]@{
            id = $Id
            status = $Status
            message = $Message
            remediation = $Remediation
        })
    }

    function Register-Action {
        param(
            [string]$Action,
            [string]$Details
        )

        Add-ResultItem -Result $result -Collection 'actions' -Item ([pscustomobject]@{
            action = $Action
            details = $Details
        })
    }

    function Register-Error {
        param(
            [string]$Id,
            [string]$Message,
            [string]$Remediation
        )

        $result.status = 'error'
        Add-ResultItem -Result $result -Collection 'errors' -Item ([pscustomobject]@{
            id = $Id
            message = $Message
            remediation = $Remediation
        })
        Write-StopLog -Level 'Error' -Message $Message
        if ($Remediation) {
            Write-StopLog -Level 'Error' -Message "Remediation: $Remediation"
        }
    }

    function Register-Warning {
        param(
            [string]$Id,
            [string]$Message
        )

        Add-ResultItem -Result $result -Collection 'warnings' -Item ([pscustomobject]@{
            id = $Id
            message = $Message
        })
        Write-StopLog -Level 'Warning' -Message $Message
    }

    function Invoke-Check {
        param(
            [string]$Id,
            [string]$Description,
            [scriptblock]$Test,
            [string]$FailureMessage,
            [string]$Remediation
        )

        try {
            $testResult = & $Test
            if ($testResult) {
                Register-Check -Id $Id -Status 'ok' -Message $Description -Remediation ''
                return
            }
        } catch {
            Write-StopLog -Level 'Verbose' -Message "Check '$Id' threw: $($_.Exception.Message)"
        }

        Register-Check -Id $Id -Status 'error' -Message $FailureMessage -Remediation $Remediation
        Register-Error -Id $Id -Message $FailureMessage -Remediation $Remediation
        throw $FailureMessage
    }

    if (-not $isWindowsPlatform) {
        Register-Error -Id 'unsupported_os' -Message "This script only supports Windows. Detected platform: $([System.Environment]::OSVersion.Platform)." -Remediation 'Run this script on Windows with OpenSSH Server installed.'
        return $result
    }

    try {
        Invoke-Check -Id 'tcp_cmdlets' -Description 'NetTCPIP cmdlets are available.' -Test {
            return $null -ne (& $deps.GetCommand 'Get-NetTCPConnection')
        } -FailureMessage 'NetTCPIP cmdlets are unavailable (Get-NetTCPConnection missing).' -Remediation 'Install the NetTCPIP module or run on a Windows build that includes it.'

        Invoke-Check -Id 'sshd_service' -Description "OpenSSH Server service 'sshd' is registered." -Test {
            & $deps.GetService 'sshd' | Out-Null
            return $true
        } -FailureMessage "OpenSSH Server service 'sshd' is not installed." -Remediation "Install OpenSSH Server and ensure the 'sshd' service exists."

        $service = & $deps.GetService 'sshd'
        if ($service.Status -ne 'Running') {
            Register-Warning -Id 'sshd_not_running' -Message "OpenSSH Server service 'sshd' is already stopped."
            $result.stopped = $true
        } else {
            if (-not (Test-IsAdmin)) {
                Register-Error -Id 'requires_admin' -Message 'Stopping sshd requires an elevated PowerShell session (Run as Administrator).' -Remediation 'Start PowerShell as Administrator and rerun.'
                return $result
            }

            if ($PSCmdlet.ShouldProcess("sshd", 'Stop OpenSSH Server service')) {
                try {
                    & $deps.StopService 'sshd' $Force
                    Register-Action -Action 'sshd_stop' -Details 'Stopped OpenSSH Server service.'
                } catch {
                    Register-Error -Id 'sshd_stop_failed' -Message "Failed to stop OpenSSH Server service: $($_.Exception.Message)" -Remediation 'Check service permissions and retry.'
                    return $result
                }
            }

            $service = & $deps.GetService 'sshd'
            if ($service.Status -ne 'Stopped') {
                Register-Error -Id 'sshd_stop_failed' -Message "OpenSSH Server service 'sshd' is still running after stop attempt." -Remediation 'Check the OpenSSH operational log for errors.'
                return $result
            }

            $result.stopped = $true
        }

        Invoke-Check -Id 'sshd_listening' -Description "sshd is not listening on TCP port $Port." -Test {
            $listeners = & $deps.GetNetTcpConnection $Port
            if (-not $listeners) {
                return $true
            }
            foreach ($listener in $listeners) {
                try {
                    $proc = & $deps.GetProcess $listener.OwningProcess
                    if ($proc.ProcessName -eq 'sshd') {
                        return $false
                    }
                } catch {
                    return $false
                }
            }
            return $true
        } -FailureMessage "sshd is still listening on TCP port $Port after stop." -Remediation 'Check for lingering sshd processes and terminate them if necessary.'

        Write-StopLog -Message 'OpenSSH Server is stopped.' -Level 'Info'
    } catch {
        if ($result.status -ne 'error') {
            $result.status = 'error'
        }
    }

    return $result
}
