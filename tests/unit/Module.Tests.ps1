Set-StrictMode -Version Latest

Describe 'WindowsOpenSshServerStartup module' {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $modulePath = Join-Path $script:repoRoot 'WindowsOpenSshServerStartup\WindowsOpenSshServerStartup.psd1'
        Import-Module $modulePath -Force

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

    It 'runs Stop-OpenSshServer with injected dependencies' {
        $result = Stop-OpenSshServer -Quiet -Dependencies $script:StopDependencies
        $result.status | Should -Be 'success'
    }
}
