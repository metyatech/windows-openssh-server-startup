Set-StrictMode -Version Latest

Describe 'Invoke-OpenSshServerStartup' {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        . (Join-Path $script:repoRoot 'src\Start-OpenSshServer.ps1')

        $script:BuildDefaultDependencies = {
            @{
                TestPath = { param($Path) $null = $Path; $true }
                GetChildItem = { param($Path) $null = $Path; @([pscustomobject]@{ Name = 'ssh_host_rsa_key' }) }
                GetCommand = { param($Name) @{ Name = $Name } }
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
            }
        }
    }

    Context 'success path' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
        }

        It 'returns success status when all checks pass' {
            $result = Invoke-OpenSshServerStartup -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'success'
            $result.started | Should -BeTrue
        }
    }

    Context 'missing binaries' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
            $script:CurrentDependencies.TestPath = {
                param($Path)
                if ($Path -like '*sshd.exe') { return $false }
                return $true
            }
        }

        It 'returns an error for missing OpenSSH binaries' {
            $result = Invoke-OpenSshServerStartup -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'error'
            ($result.errors | Select-Object -First 1).id | Should -Be 'openssh_binary'
        }
    }

    Context 'autofix requires admin' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
            $script:CurrentDependencies.TestPath = {
                param($Path)
                if ($Path -like '*sshd.exe') { return $false }
                return $true
            }
            Mock Test-IsAdmin { $false }
        }

        It 'returns requires_admin when AutoFix is enabled without elevation' {
            $result = Invoke-OpenSshServerStartup -AutoFix -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'error'
            ($result.errors | Select-Object -First 1).id | Should -Be 'requires_admin'
        }
    }

    Context 'autofix declined by user' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
            $script:CurrentDependencies.TestPath = {
                param($Path)
                if ($Path -like '*sshd.exe') { return $false }
                return $true
            }
            Mock Test-IsAdmin { $true }
            Mock Confirm-AutoFix {
                param($Message, $Yes)
                $script:CapturedConfirmMessage = $Message
                $null = $Yes
                $false
            }
        }

        It 'returns an error when AutoFix is declined' {
            $result = Invoke-OpenSshServerStartup -AutoFix -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'error'
            ($result.errors | Select-Object -First 1).id | Should -Be 'openssh_binary'
        }

        It 'uses a clear confirmation message' {
            $null = Invoke-OpenSshServerStartup -AutoFix -Quiet -Dependencies $script:CurrentDependencies
            $script:CapturedConfirmMessage | Should -Match 'Issue detected'
            $script:CapturedConfirmMessage | Should -Match 'Apply automatic remediation'
            $script:CapturedConfirmMessage | Should -Match 'openssh_binary'
        }
    }

    Context 'autofix resolves the issue' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
            $script:callCount = 0
            $script:CurrentDependencies.TestPath = {
                param($Path)
                if ($Path -like '*sshd.exe') {
                    $script:callCount++
                    return $script:callCount -gt 1
                }
                return $true
            }
            Mock Test-IsAdmin { $true }
            Mock Confirm-AutoFix { $true }
        }

        It 'retries the failing check after AutoFix' {
            $result = Invoke-OpenSshServerStartup -AutoFix -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'success'
            $script:callCount | Should -BeGreaterThan 1
        }
    }

    Context 'port conflict' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
            $script:CurrentDependencies.GetProcess = { param($Id) $null = $Id; [pscustomobject]@{ ProcessName = 'other' } }
        }

        It 'returns an error when the SSH port is in use' {
            $result = Invoke-OpenSshServerStartup -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'error'
            ($result.errors | Select-Object -First 1).id | Should -Be 'port_available'
        }
    }

    Context 'does not enforce automatic startup' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
            $script:CurrentDependencies.GetCimInstance = { [pscustomobject]@{ StartMode = 'Manual' } }
            $script:CurrentDependencies.SetService = { throw 'SetService should not be called.' }
        }

        It 'does not attempt to change sshd startup type' {
            $result = Invoke-OpenSshServerStartup -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'success'
        }
    }
}
