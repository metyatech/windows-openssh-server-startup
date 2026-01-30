Set-StrictMode -Version Latest

Describe 'WindowsOpenSshServerStartup module' {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $modulePath = Join-Path $script:repoRoot 'WindowsOpenSshServerStartup\WindowsOpenSshServerStartup.psd1'
        Import-Module $modulePath -Force

        $script:BuildDefaultDependencies = {
            @{}
        }

        $script:StartDependencies = @{
            TestPath = { param($Path) $null = $Path; $true }
            GetChildItem = { param($Path) $null = $Path; @([pscustomobject]@{ Name = 'ssh_host_rsa_key' }) }
            GetCommand = {
                param($Name)
                if ($Name -eq 'sudo') { return $null }
                @{ Name = $Name }
            }
            GetService = {
                param($Name)
                if ($Name -eq 'MpsSvc' -or $Name -eq 'sshd') {
                    return [pscustomobject]@{ Status = 'Running' }
                }
                throw "Unexpected service name: $Name"
            }
            StartService = { param($Name) $null = $Name }
            GetFirewallRule = { param($DisplayName) $null = $DisplayName; [pscustomobject]@{ Enabled = 'True' } }
            GetFirewallPortFilter = { param($Rule) $null = $Rule; @([pscustomobject]@{ Protocol = 'TCP'; LocalPort = 22 }) }
            EnableFirewallRule = { param($DisplayName) $null = $DisplayName }
            SetFirewallRule = { param($DisplayName, $Port) $null = $DisplayName; $null = $Port }
            NewFirewallRule = { param($DisplayName, $Port) $null = $DisplayName; $null = $Port }
            GetNetTcpConnection = { param($Port) $null = $Port; @([pscustomobject]@{ OwningProcess = 123 }) }
            GetProcess = { param($Id) $null = $Id; [pscustomobject]@{ ProcessName = 'sshd' } }
            AddWindowsCapability = { }
            AddWindowsFeature = { }
            RepairWindowsCapability = { }
            RunSshKeygen = { param($Path) $null = $Path }
            IsAdmin = { $true }
            Elevate = { param($ExePath, $ArgumentList) $null = $ExePath; $null = $ArgumentList }
            RunSudo = { param($ExePath, $ArgumentList) $null = $ExePath; $null = $ArgumentList }
        }

        $script:BuildDefaultDependencies = {
            $script:StartDependencies.Clone()
        }

        $script:StopDependencies = @{
            GetCommand = {
                param($Name)
                if ($Name -eq 'sudo') { return $null }
                @{ Name = $Name }
            }
            GetService = { param($Name) $null = $Name; [pscustomobject]@{ Status = 'Stopped' } }
            StopService = { param($Name, $Force) $null = $Name; $null = $Force }
            GetNetTcpConnection = { param($Port) $null = $Port; @() }
            GetProcess = { param($Id) $null = $Id; [pscustomobject]@{ ProcessName = 'sshd' } }
            IsAdmin = { $true }
            Elevate = { param($ExePath, $ArgumentList) $null = $ExePath; $null = $ArgumentList }
            RunSudo = { param($ExePath, $ArgumentList) $null = $ExePath; $null = $ArgumentList }
        }
    }

    It 'exposes Start-OpenSshServer' {
        Get-Command Start-OpenSshServer -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'exposes Stop-OpenSshServer' {
        Get-Command Stop-OpenSshServer -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'runs Start-OpenSshServer with injected dependencies' {
        $result = Start-OpenSshServer -Quiet -Dependencies $script:StartDependencies
        $result.status | Should -Be 'success'
    }

    It 'suppresses summary output when no action is needed for Start-OpenSshServer' {
        $result = Start-OpenSshServer -Dependencies $script:StartDependencies
        $result | Should -Be $null
    }

    It 'returns a summary when automatic remediation applies for Start-OpenSshServer' {
        $deps = & $script:BuildDefaultDependencies
        $script:ruleCheckCount = 0
        $deps.GetFirewallRule = {
            param($DisplayName)
            $null = $DisplayName
            if ($script:ruleCheckCount -eq 0) {
                $script:ruleCheckCount++
                return $null
            }
            return [pscustomobject]@{ Enabled = 'True' }
        }
        $deps.NewFirewallRule = { param($DisplayName, $Port) $null = $DisplayName; $null = $Port }

        $result = Start-OpenSshServer -Yes -Dependencies $deps
        ($result.PSObject.Properties.Name) | Should -Contain 'status'
        ($result.PSObject.Properties.Name) | Should -Contain 'message'
        ($result.PSObject.Properties.Name) | Should -Not -Contain 'checks'
    }

    It 'returns full details when verbose is requested for Start-OpenSshServer' {
        $result = Start-OpenSshServer -Verbose -Dependencies $script:StartDependencies
        ($result.PSObject.Properties.Name) | Should -Contain 'checks'
        $result.status | Should -Be 'success'
    }

    It 'suppresses summary output when sudo runs in the same terminal for Start-OpenSshServer' {
        $deps = & $script:BuildDefaultDependencies
        $deps.TestPath = {
            param($Path)
            if ($Path -like '*sshd.exe') { return $false }
            return $true
        }
        $deps.IsAdmin = { $false }
        $deps.GetCommand = {
            param($Name)
            if ($Name -eq 'sudo') {
                return @{ Name = 'sudo'; Source = 'C:\\Windows\\system32\\sudo.exe' }
            }
            @{ Name = $Name }
        }
        $deps.RunSudo = {
            param($ExePath, $ArgumentList)
            $null = $ExePath
            $null = $ArgumentList
            $global:LASTEXITCODE = 0
        }

        $result = Start-OpenSshServer -Yes -Dependencies $deps
        $result | Should -Be $null
    }

    It 'runs Stop-OpenSshServer with injected dependencies' {
        $result = Stop-OpenSshServer -Quiet -Dependencies $script:StopDependencies
        $result.status | Should -Be 'success'
    }

    It 'suppresses summary output when no action is needed for Stop-OpenSshServer' {
        $result = Stop-OpenSshServer -Dependencies $script:StopDependencies
        $result | Should -Be $null
    }

    It 'returns a summary when stopping requires action for Stop-OpenSshServer' {
        $script:stopState = 'Running'
        $deps = @{
            GetCommand = { param($Name) @{ Name = $Name } }
            GetService = { param($Name) $null = $Name; [pscustomobject]@{ Status = $script:stopState } }
            StopService = { param($Name, $Force) $null = $Name; $null = $Force; $script:stopState = 'Stopped' }
            GetNetTcpConnection = { param($Port) $null = $Port; @() }
            GetProcess = { param($Id) $null = $Id; [pscustomobject]@{ ProcessName = 'sshd' } }
            IsAdmin = { $true }
            Elevate = { param($ExePath, $ArgumentList) $null = $ExePath; $null = $ArgumentList }
            RunSudo = { param($ExePath, $ArgumentList) $null = $ExePath; $null = $ArgumentList }
        }

        $result = Stop-OpenSshServer -Dependencies $deps
        ($result.PSObject.Properties.Name) | Should -Contain 'status'
        ($result.PSObject.Properties.Name) | Should -Contain 'message'
        ($result.PSObject.Properties.Name) | Should -Not -Contain 'checks'
    }

    It 'returns full details when verbose is requested for Stop-OpenSshServer' {
        $result = Stop-OpenSshServer -Verbose -Dependencies $script:StopDependencies
        ($result.PSObject.Properties.Name) | Should -Contain 'checks'
        $result.status | Should -Be 'success'
    }

    It 'suppresses summary output when sudo runs in the same terminal for Stop-OpenSshServer' {
        $deps = @{
            GetCommand = { param($Name) if ($Name -eq 'sudo') { return @{ Name = 'sudo'; Source = 'C:\\Windows\\system32\\sudo.exe' } } @{ Name = $Name } }
            GetService = { param($Name) $null = $Name; [pscustomobject]@{ Status = 'Running' } }
            StopService = { param($Name, $Force) $null = $Name; $null = $Force }
            GetNetTcpConnection = { param($Port) $null = $Port; @() }
            GetProcess = { param($Id) $null = $Id; [pscustomobject]@{ ProcessName = 'sshd' } }
            IsAdmin = { $false }
            Elevate = { param($ExePath, $ArgumentList) $null = $ExePath; $null = $ArgumentList }
            RunSudo = {
                param($ExePath, $ArgumentList)
                $null = $ExePath
                $null = $ArgumentList
                $global:LASTEXITCODE = 0
            }
        }

        $result = Stop-OpenSshServer -Yes -Dependencies $deps
        $result | Should -Be $null
    }
}
