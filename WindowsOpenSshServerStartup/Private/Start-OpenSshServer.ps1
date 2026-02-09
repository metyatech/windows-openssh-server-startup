Set-StrictMode -Version Latest

function Get-OpenSshServerStartupVersion {
    '0.3.7'
}

function Get-OpenSshServerStartupHelp {
    @"
Start-OpenSshServer.ps1

Usage:
  .\Start-OpenSshServer.ps1 [options]

Options:
  -AutoFix            Enable automatic remediation (default).
  -NoAutoFix          Disable automatic remediation.
  -Yes                Skip confirmation prompts for AutoFix.
  -DryRun             Preview remediation actions without applying changes.
  -Port <int>         TCP port for sshd (default: 22).
  -FirewallRuleName   Firewall rule display name (default: OpenSSH-Server-In-TCP).
  -Json               Emit machine-readable JSON output only.
  -Quiet              Suppress non-error output.
  -Trace              Emit verbose diagnostic output and full result details.
  -Version            Print version and exit.
  -Help               Print this help and exit.

Notes:
  - Use -WhatIf to simulate changes (PowerShell common parameter).
  - Use -Confirm to force confirmation prompts (PowerShell common parameter).
  - Default output is a concise summary; use -Verbose or -Trace for details.
  - Summary output is suppressed when no action is needed.
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
        [bool]$Yes,
        [Parameter(DontShow)]
        $IsUserInteractive = $null
    )

    if ($Yes) {
        return $true
    }

    $interactive = if ($null -ne $IsUserInteractive) { $IsUserInteractive } else { [Environment]::UserInteractive }
    if (-not $interactive) {
        return $false
    }

    $answer = Read-Host "$Message (Y/n)"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $true
    }
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
        }
        elseif ($value -is [bool]) {
            if ($value) {
                $argumentList += "-$key"
            }
        }
        else {
            $argumentList += "-$key"
            $argumentList += "$value"
        }
    }
    return $argumentList
}

$script:OpenSshStartupDependencies = @{
    TestPath                = { param($Path) Test-Path $Path }
    GetChildItem            = { param($Path) Get-ChildItem -Path $Path -ErrorAction SilentlyContinue }
    GetCommand              = { param($Name) Get-Command -Name $Name -ErrorAction SilentlyContinue }
    GetService              = { param($Name) Get-Service -Name $Name -ErrorAction Stop }
    StartService            = { param($Name) Start-Service -Name $Name -ErrorAction Stop }
    GetFirewallRule         = { param($DisplayName) Get-NetFirewallRule -DisplayName $DisplayName -ErrorAction SilentlyContinue }
    GetFirewallPortFilter   = { param($Rule) $Rule | Get-NetFirewallPortFilter }
    EnableFirewallRule      = { param($DisplayName) Enable-NetFirewallRule -DisplayName $DisplayName | Out-Null }
    SetFirewallRule         = { param($DisplayName, $Port) Set-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Any | Out-Null }
    NewFirewallRule         = { param($DisplayName, $Port) New-NetFirewallRule -DisplayName $DisplayName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Any | Out-Null }
    GetNetTcpConnection     = { param($Port) Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue }
    GetProcess              = { param($Id) Get-Process -Id $Id -ErrorAction Stop }
    AddWindowsCapability    = { Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop | Out-Null }
    AddWindowsFeature       = { Add-WindowsFeature -Name 'OpenSSH-Server' -IncludeAllSubFeature -ErrorAction Stop | Out-Null }
    RepairWindowsCapability = { Repair-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop | Out-Null }
    RunSshKeygen            = { param($Path) & $Path -A | Out-Null }
    IsAdmin                 = { Test-IsAdmin }
    IsUserInteractive       = { [Environment]::UserInteractive }
    Elevate                 = {
        param($ExePath, $ArgumentList)
        Start-Process -FilePath $ExePath -ArgumentList $ArgumentList -Verb RunAs | Out-Null
    }
    RunSudo                 = {
        param($ExePath, $ArgumentList)
        & sudo -- $ExePath @ArgumentList
    }
}

function Get-StartupResult {
    [pscustomobject]@{
        version  = Get-OpenSshServerStartupVersion
        status   = 'success'
        started  = $false
        checks   = @()
        actions  = @()
        warnings = @()
        errors   = @()
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

function Invoke-OpenSshServerStartup {
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
        [switch]$Help,
        [Parameter(DontShow)]
        [hashtable]$Dependencies
    )

    if ($Version) {
        Write-Output (Get-OpenSshServerStartupVersion)
        return
    }

    if ($Help) {
        Write-Output (Get-OpenSshServerStartupHelp)
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

    $result = Get-StartupResult
    $deps = if ($Dependencies) { $Dependencies } else { $script:OpenSshStartupDependencies }
    $isWindowsPlatform = [System.Environment]::OSVersion.Platform -eq 'Win32NT'

    if (-not $PSBoundParameters.ContainsKey('AutoFix') -and -not $PSBoundParameters.ContainsKey('NoAutoFix')) {
        $AutoFix = $true
    }

    if ($NoAutoFix) {
        $AutoFix = $false
    }

    $null = $AutoFix
    $null = $Yes
    $invocationBoundParameters = $PSBoundParameters

    function Write-StartupLog {
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

        $item = [pscustomobject]@{
            id          = $Id
            status      = $Status
            message     = $Message
            remediation = $Remediation
        }
        Add-ResultItem -Result $result -Collection 'checks' -Item $item
    }

    function Register-Action {
        param(
            [string]$Action,
            [string]$Details
        )

        Add-ResultItem -Result $result -Collection 'actions' -Item ([pscustomobject]@{
                action  = $Action
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
                id          = $Id
                message     = $Message
                remediation = $Remediation
            })
        Write-StartupLog -Level 'Error' -Message $Message
        if ($Remediation) {
            Write-StartupLog -Level 'Error' -Message "Remediation: $Remediation"
        }
    }

    function Register-Warning {
        param(
            [string]$Id,
            [string]$Message
        )

        Add-ResultItem -Result $result -Collection 'warnings' -Item ([pscustomobject]@{
                id      = $Id
                message = $Message
            })
        Write-StartupLog -Level 'Warning' -Message $Message
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
        if (-not (Confirm-AutoFix -Message $confirmMessage -Yes:$Yes -IsUserInteractive (& $deps.IsUserInteractive))) {
            Register-Error -Id 'requires_admin' -Message "Administrator privileges required to $Reason." -Remediation 'Start PowerShell as Administrator and rerun.'
            return $false
        }

        $moduleManifest = Join-Path (Split-Path $PSScriptRoot -Parent) 'WindowsOpenSshServerStartup.psd1'
        $exePath = if (& $deps.GetCommand 'pwsh') { 'pwsh' } else { 'powershell' }
        $argumentList = Get-InvocationArgumentList -BoundParameters $invocationBoundParameters -ExcludeKeys @('Dependencies')

        function Format-CommandArgument {
            param(
                [Parameter(Mandatory)]
                [string]$Value
            )

            if ($Value -match '^-') {
                return $Value
            }

            $escaped = $Value -replace "'", "''"
            return "'$escaped'"
        }

        $formattedArgs = $argumentList | ForEach-Object { Format-CommandArgument -Value $_ }
        $escapedModulePath = ($moduleManifest -replace "'", "''")
        $commandText = "Import-Module -Force -Name '$escapedModulePath'; Start-OpenSshServer $($formattedArgs -join ' ')"
        $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($commandText))
        $baseArgs = @('-NoProfile', '-EncodedCommand', $encodedCommand)

        $usedSudo = $false
        $sudoCommand = & $deps.GetCommand 'sudo'
        if ($sudoCommand) {
            $sudoOutput = & $deps.RunSudo $exePath $baseArgs 2>&1
            $sudoExitCode = $LASTEXITCODE
            if ($sudoExitCode -eq 0) {
                $usedSudo = $true
                Register-Action -Action 'elevate' -Details 'Relaunched with sudo.'
                Register-Warning -Id 'relaunching_elevated' -Message 'Elevated command launched via sudo.'
            }
            else {
                $sudoMessage = "sudo detected at '$($sudoCommand.Source)' but failed with exit code $sudoExitCode."
                if ($sudoOutput) {
                    $sudoMessage = "$sudoMessage Output: $sudoOutput"
                }
                Register-Warning -Id 'sudo_failed' -Message $sudoMessage
            }
        }
        else {
            Register-Warning -Id 'sudo_not_found' -Message 'sudo was not found in PATH; falling back to a new elevated window.'
        }

        if (-not $usedSudo) {
            $argList = @('-NoProfile', '-NoExit', '-EncodedCommand', $encodedCommand)
            & $deps.Elevate $exePath $argList
            Register-Action -Action 'elevate' -Details 'Relaunched with elevation.'
            Register-Warning -Id 'relaunching_elevated' -Message 'Opened a new elevated PowerShell window to continue operation.'
        }

        $script:ElevationRequested = $true
        $result.status = 'pending'
        $result.started = $false
        Register-Warning -Id 'pending_elevation' -Message 'Elevation launched; final status will be reported by the elevated session. Rerun Start-OpenSshServer to confirm.'
        if ($usedSudo) {
            $result | Add-Member -NotePropertyName suppressSummary -NotePropertyValue $true -Force
        }
        throw 'ElevationRestarted'
        return $true
    }

    function Invoke-Check {
        param(
            [string]$Id,
            [string]$Description,
            [scriptblock]$Test,
            [scriptblock]$Fix,
            [string]$FailureMessage,
            [string]$Remediation
        )

        $attempt = 0
        while ($true) {
            $attempt++
            try {
                $testResult = & $Test
                if ($testResult) {
                    Register-Check -Id $Id -Status 'ok' -Message $Description -Remediation ''
                    return
                }
            }
            catch {
                Write-StartupLog -Level 'Verbose' -Message "Check '$Id' threw: $($_.Exception.Message)"
            }

            if ($AutoFix -and $Fix) {
                if (-not (& $deps.IsAdmin)) {
                    $adminMessage = if ($Id -eq 'sshd_running') {
                        "Issue detected ($Id): OpenSSH Server is not running. Administrator privileges are required to start it."
                    }
                    else {
                        "Issue detected ($Id): $FailureMessage Administrator privileges are required to apply automatic remediation."
                    }
                    Register-Warning -Id 'autofix_requires_admin' -Message $adminMessage

                    $invocationBoundParameters['Yes'] = $true
                    $null = Request-Elevation -Reason "apply automatic remediation for issue '$Id'"
                    throw 'AutoFixRequiresAdmin'
                }

                $confirmMessage = "Issue detected ($Id): $FailureMessage Apply automatic remediation now?"
                if (-not (Confirm-AutoFix -Message $confirmMessage -Yes:$Yes -IsUserInteractive (& $deps.IsUserInteractive))) {
                    Register-Error -Id $Id -Message $FailureMessage -Remediation 'Rerun with -AutoFix -Yes to allow automatic remediation.'
                    throw 'AutoFixDeclined'
                }

                if ($PSCmdlet.ShouldProcess($Description, 'Apply automatic remediation')) {
                    try {
                        & $Fix
                        Register-Action -Action $Id -Details 'Applied automatic remediation.'
                    }
                    catch {
                        Register-Error -Id $Id -Message "Automatic remediation failed: $($_.Exception.Message)" -Remediation 'Resolve the issue manually and rerun the script.'
                        throw
                    }
                }

                if ($attempt -lt 2) {
                    continue
                }
            }

            Register-Check -Id $Id -Status 'error' -Message $FailureMessage -Remediation $Remediation
            Register-Error -Id $Id -Message $FailureMessage -Remediation $Remediation
            throw $FailureMessage
        }
    }

    if (-not $isWindowsPlatform) {
        Register-Error -Id 'unsupported_os' -Message "This script only supports Windows. Detected platform: $([System.Environment]::OSVersion.Platform)." -Remediation 'Run this script on Windows with OpenSSH Server installed.'
        return $result
    }

    $openSshRoot = Join-Path $env:WINDIR 'System32\OpenSSH'
    $sshdPath = Join-Path $openSshRoot 'sshd.exe'
    $sshKeygenPath = Join-Path $openSshRoot 'ssh-keygen.exe'
    $configPath = Join-Path $env:ProgramData 'ssh\sshd_config'
    $hostKeyPattern = Join-Path $env:ProgramData 'ssh\ssh_host_*_key'

    $script:ElevationRequested = $false
    try {
        Invoke-Check -Id 'openssh_binary' -Description 'OpenSSH server binaries are present.' -Test {
            & $deps.TestPath $sshdPath
        } -Fix {
            if (& $deps.GetCommand 'Add-WindowsCapability') {
                & $deps.AddWindowsCapability
            }
            elseif (& $deps.GetCommand 'Add-WindowsFeature') {
                & $deps.AddWindowsFeature
            }
            else {
                throw 'OpenSSH installation commands are unavailable.'
            }
        } -FailureMessage "OpenSSH Server is not installed. Missing binary: $sshdPath" -Remediation "Install OpenSSH Server (Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0') and rerun."

        Invoke-Check -Id 'sshd_service' -Description "OpenSSH Server service 'sshd' is registered." -Test {
            & $deps.GetService 'sshd' | Out-Null
            return $true
        } -Fix {
            if (& $deps.GetCommand 'Add-WindowsCapability') {
                & $deps.AddWindowsCapability
            }
            elseif (& $deps.GetCommand 'Add-WindowsFeature') {
                & $deps.AddWindowsFeature
            }
            else {
                throw 'OpenSSH installation commands are unavailable.'
            }
        } -FailureMessage "OpenSSH Server service 'sshd' is not installed." -Remediation "Install OpenSSH Server and ensure the 'sshd' service exists."

        Invoke-Check -Id 'sshd_config' -Description 'OpenSSH server configuration file exists.' -Test {
            & $deps.TestPath $configPath
        } -Fix {
            if (& $deps.GetCommand 'Repair-WindowsCapability') {
                & $deps.RepairWindowsCapability
            }
            else {
                throw 'OpenSSH configuration file missing and repair command unavailable.'
            }
        } -FailureMessage "OpenSSH configuration file is missing: $configPath" -Remediation 'Reinstall or repair OpenSSH Server to restore sshd_config.'

        Invoke-Check -Id 'host_keys' -Description 'OpenSSH host keys are present.' -Test {
            $keys = & $deps.GetChildItem $hostKeyPattern
            return $null -ne $keys -and @($keys).Count -gt 0
        } -Fix {
            if (-not (& $deps.TestPath $sshKeygenPath)) {
                throw "ssh-keygen is missing: $sshKeygenPath"
            }
            & $deps.RunSshKeygen $sshKeygenPath
        } -FailureMessage 'OpenSSH host keys are missing.' -Remediation 'Generate host keys with "ssh-keygen -A" and retry.'

        Invoke-Check -Id 'firewall_module' -Description 'Windows Firewall cmdlets are available.' -Test {
            return $null -ne (& $deps.GetCommand 'Get-NetFirewallRule')
        } -Fix $null -FailureMessage 'Windows Firewall cmdlets are unavailable (NetSecurity module missing).' -Remediation 'Install the NetSecurity module or run on a Windows build that includes it.'

        Invoke-Check -Id 'firewall_service' -Description 'Windows Firewall service (MpsSvc) is running.' -Test {
            $fw = & $deps.GetService 'MpsSvc'
            return $fw.Status -eq 'Running'
        } -Fix {
            & $deps.StartService 'MpsSvc'
        } -FailureMessage 'Windows Firewall service (MpsSvc) is not running.' -Remediation 'Start the Windows Firewall service and rerun.'

        Invoke-Check -Id 'firewall_rule' -Description "Firewall rule '$FirewallRuleName' should allow inbound TCP $Port." -Test {
            $rule = & $deps.GetFirewallRule $FirewallRuleName
            if (-not $rule) {
                return $false
            }
            if ($rule.Enabled -ne 'True') {
                return $false
            }
            $portFilters = & $deps.GetFirewallPortFilter $rule
            foreach ($filter in $portFilters) {
                if ($filter.Protocol -eq 'TCP' -and ($filter.LocalPort -eq $Port -or $filter.LocalPort -eq 'Any')) {
                    return $true
                }
            }
            return $false
        } -Fix {
            $rule = & $deps.GetFirewallRule $FirewallRuleName
            if (-not $rule) {
                & $deps.NewFirewallRule $FirewallRuleName $Port
            }
            else {
                & $deps.EnableFirewallRule $FirewallRuleName
                & $deps.SetFirewallRule $FirewallRuleName $Port
            }
        } -FailureMessage "Firewall rule '$FirewallRuleName' is missing or does not allow TCP $Port." -Remediation 'Create or enable an inbound firewall rule for the OpenSSH Server port.'

        Invoke-Check -Id 'tcp_cmdlets' -Description 'NetTCPIP cmdlets are available.' -Test {
            return $null -ne (& $deps.GetCommand 'Get-NetTCPConnection')
        } -Fix $null -FailureMessage 'NetTCPIP cmdlets are unavailable (Get-NetTCPConnection missing).' -Remediation 'Install the NetTCPIP module or run on a Windows build that includes it.'

        Invoke-Check -Id 'port_available' -Description "TCP port $Port is available for sshd." -Test {
            $listeners = & $deps.GetNetTcpConnection $Port
            if (-not $listeners) {
                return $true
            }
            foreach ($listener in $listeners) {
                try {
                    $proc = & $deps.GetProcess $listener.OwningProcess
                    if ($proc.ProcessName -ne 'sshd') {
                        return $false
                    }
                }
                catch {
                    return $false
                }
            }
            return $true
        } -Fix $null -FailureMessage "TCP port $Port is already in use by another process." -Remediation 'Stop the conflicting service or change the SSH port and update firewall rules.'

        Invoke-Check -Id 'sshd_running' -Description "OpenSSH Server service 'sshd' is running." -Test {
            $service = & $deps.GetService 'sshd'
            return $service.Status -eq 'Running'
        } -Fix {
            & $deps.StartService 'sshd'
        } -FailureMessage "OpenSSH Server service 'sshd' is not running." -Remediation 'Start the OpenSSH Server service or check the OpenSSH operational log (OpenSSH/Operational) if it fails to start.'

        Invoke-Check -Id 'sshd_listening' -Description "sshd is listening on TCP port $Port." -Test {
            $listeners = & $deps.GetNetTcpConnection $Port
            if (-not $listeners) {
                return $false
            }
            foreach ($listener in $listeners) {
                try {
                    $proc = & $deps.GetProcess $listener.OwningProcess
                    if ($proc.ProcessName -eq 'sshd') {
                        return $true
                    }
                }
                catch {
                    return $false
                }
            }
            return $false
        } -Fix $null -FailureMessage "sshd is not listening on TCP port $Port after startup." -Remediation 'Check OpenSSH logs and sshd_config for binding errors.'

        $result.started = $true
        Write-StartupLog -Message 'OpenSSH Server is running and ready.' -Level 'Info'
    }
    catch {
        if ($script:ElevationRequested) {
            return $result
        }
        if ($result.status -ne 'error') {
            $result.status = 'error'
        }
    }

    return $result
}
