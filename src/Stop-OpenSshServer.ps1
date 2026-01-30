Set-StrictMode -Version Latest

function Get-OpenSshServerStopVersion {
    '0.2.0'
}

function Get-OpenSshServerStopHelp {
    @"
Stop-OpenSshServer.ps1

Usage:
  .\Stop-OpenSshServer.ps1 [options]

Options:
  -Force             Force stop the sshd service.
  -Yes               Skip confirmation prompts when elevation is required.
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

function Confirm-AutoFix {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter(Mandatory)]
        [bool]$Yes
    )

    if ($Yes) {
        return $true
    }

    if (-not [Environment]::UserInteractive) {
        return $false
    }

    $answer = Read-Host "$Message (Y/n)"
    return $answer -match '^(y|yes)$'
}

function Get-InvocationArgumentList {
    param(
        [Parameter(Mandatory)]
        [hashtable]$BoundParameters,
        [Parameter(Mandatory)]
        [string[]]$ExcludeKeys
    )

    $argumentList = @()
    foreach ($key in $BoundParameters.Keys) {
        if ($ExcludeKeys -contains $key) {
            continue
        }
        $value = $BoundParameters[$key]
        if ($value -is [switch]) {
            if ($value.IsPresent) {
                $argumentList += "-$key"
            }
        } elseif ($value -is [bool]) {
            if ($value) {
                $argumentList += "-$key"
            }
        } else {
            $argumentList += "-$key"
            $argumentList += "$value"
        }
    }
    return $argumentList
}

$script:OpenSshStopDependencies = @{
    GetCommand = { param($Name) Get-Command -Name $Name -ErrorAction SilentlyContinue }
    GetService = { param($Name) Get-Service -Name $Name -ErrorAction Stop }
    StopService = { param($Name, $Force) Stop-Service -Name $Name -Force:$Force -ErrorAction Stop }
    GetNetTcpConnection = { param($Port) Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue }
    GetProcess = { param($Id) Get-Process -Id $Id -ErrorAction Stop }
    IsAdmin = { Test-IsAdmin }
    Elevate = {
        param($ExePath, $ArgumentList)
        Start-Process -FilePath $ExePath -ArgumentList $ArgumentList -Verb RunAs | Out-Null
    }
    RunSudo = {
        param($ExePath, $ArgumentList)
        & sudo -- $ExePath @ArgumentList
    }
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
        [switch]$Yes,
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

    $null = $Yes
    $invocationBoundParameters = $PSBoundParameters

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

    function Request-Elevation {
        param(
            [Parameter(Mandatory)]
            [string]$Reason
        )

        if ($WhatIfPreference) {
            Register-Error -Id 'requires_admin' -Message "Administrator privileges required to $Reason." -Remediation 'Run in an elevated PowerShell session and retry.'
            return $false
        }

        $confirmMessage = "Administrator privileges required to $Reason. Relaunch as Administrator now?"
        if (-not (Confirm-AutoFix -Message $confirmMessage -Yes:$Yes)) {
            Register-Error -Id 'requires_admin' -Message "Administrator privileges required to $Reason." -Remediation 'Start PowerShell as Administrator and rerun.'
            return $false
        }

        $scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'Stop-OpenSshServer.ps1'
        $exePath = if (& $deps.GetCommand 'pwsh') { 'pwsh' } else { 'powershell' }
        $baseArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath) + (Get-InvocationArgumentList -BoundParameters $invocationBoundParameters -ExcludeKeys @('Dependencies'))

        $usedSudo = $false
        if (& $deps.GetCommand 'sudo') {
            & $deps.RunSudo $exePath $baseArgs
            if ($LASTEXITCODE -eq 0) {
                $usedSudo = $true
                Register-Action -Action 'elevate' -Details 'Relaunched with sudo.'
                Register-Warning -Id 'relaunching_elevated' -Message 'Elevated command launched via sudo.'
            } else {
                Register-Warning -Id 'sudo_failed' -Message 'sudo is unavailable or failed; falling back to a new elevated window.'
            }
        }

        if (-not $usedSudo) {
            $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', $scriptPath) + (Get-InvocationArgumentList -BoundParameters $invocationBoundParameters -ExcludeKeys @('Dependencies'))
            & $deps.Elevate $exePath $argList
            Register-Action -Action 'elevate' -Details 'Relaunched with elevation.'
            Register-Warning -Id 'relaunching_elevated' -Message 'Opened a new elevated PowerShell window to continue operation.'
        }

        $script:ElevationRequested = $true
        throw 'ElevationRestarted'
        return $true
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

    $script:ElevationRequested = $false
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
            if (-not (& $deps.IsAdmin)) {
                $null = Request-Elevation -Reason 'stop the OpenSSH Server service'
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
        if ($script:ElevationRequested) {
            return $result
        }
        if ($result.status -ne 'error') {
            $result.status = 'error'
        }
    }

    return $result
}
