Set-StrictMode -Version Latest

Describe 'Invoke-OpenSshServerStop' {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        . (Join-Path $script:repoRoot 'src\Stop-OpenSshServer.ps1')

        $script:BuildDefaultDependencies = {
            $script:serviceStatus = 'Running'
            @{
                GetCommand = {
                    param($Name)
                    if ($Name -eq 'sudo') { return $null }
                    @{ Name = $Name }
                }
                GetService = {
                    param($Name)
                    if ($Name -ne 'sshd') { throw "Unexpected service name: $Name" }
                    [pscustomobject]@{ Status = $script:serviceStatus }
                }
                StopService = {
                    param($Name, $Force)
                    $null = $Name
                    $null = $Force
                    $script:serviceStatus = 'Stopped'
                }
                GetNetTcpConnection = { param($Port) $null = $Port; @() }
                GetProcess = { param($Id) $null = $Id; [pscustomobject]@{ ProcessName = 'sshd' } }
                IsAdmin = { $true }
                Elevate = {
                    param($ExePath, $ArgumentList)
                    $script:ElevateArgs = @($ExePath) + $ArgumentList
                }
                RunSudo = {
                    param($ExePath, $ArgumentList)
                    $script:SudoArgs = @($ExePath) + $ArgumentList
                }
            }
        }
    }

    Context 'success path' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
        }

        It 'stops sshd when running' {
            $result = Invoke-OpenSshServerStop -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'success'
            $result.stopped | Should -BeTrue
        }
    }

    Context 'service missing' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
            $script:CurrentDependencies.GetService = { throw 'Service not found' }
        }

        It 'returns an error when sshd service is missing' {
            $result = Invoke-OpenSshServerStop -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'error'
            ($result.errors | Select-Object -First 1).id | Should -Be 'sshd_service'
        }
    }

    Context 'already stopped' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
            $script:CurrentDependencies.GetService = { [pscustomobject]@{ Status = 'Stopped' } }
        }

        It 'reports success when sshd is already stopped' {
            $result = Invoke-OpenSshServerStop -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'success'
            $result.stopped | Should -BeTrue
        }
    }

    Context 'stop failure' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
            $script:CurrentDependencies.StopService = { throw 'Stop failed' }
        }

        It 'returns an error when stop fails' {
            $result = Invoke-OpenSshServerStop -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'error'
            ($result.errors | Select-Object -First 1).id | Should -Be 'sshd_stop_failed'
        }
    }

    Context 'still listening' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
            $script:CurrentDependencies.GetNetTcpConnection = { @([pscustomobject]@{ OwningProcess = 42 }) }
            $script:CurrentDependencies.GetProcess = { [pscustomobject]@{ ProcessName = 'sshd' } }
        }

        It 'returns an error when sshd is still listening' {
            $result = Invoke-OpenSshServerStop -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'error'
            ($result.errors | Select-Object -First 1).id | Should -Be 'sshd_listening'
        }
    }

    Context 'requires admin' {
        BeforeEach {
            $script:CurrentDependencies = & $script:BuildDefaultDependencies
            $script:ElevateArgs = $null
            $script:CurrentDependencies.IsAdmin = { $false }
        }

        It 'returns requires_admin when elevation is declined' {
            Mock Confirm-AutoFix { $false }
            $result = Invoke-OpenSshServerStop -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'error'
            ($result.errors | Select-Object -First 1).id | Should -Be 'requires_admin'
        }

        It 'requests elevation when not elevated' {
            Mock Confirm-AutoFix { $true }
            $result = Invoke-OpenSshServerStop -Quiet -Dependencies $script:CurrentDependencies
            $result.status | Should -Be 'success'
            ($result.warnings | Select-Object -First 1).id | Should -Be 'relaunching_elevated'
            $script:ElevateArgs | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Confirm-AutoFix (Stop)' {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        . (Join-Path $script:repoRoot 'src\Stop-OpenSshServer.ps1')
    }

    It 'treats empty input as yes' {
        Mock Read-Host { '' }
        Confirm-AutoFix -Message 'Test' -Yes:$false | Should -BeTrue
    }

    It 'treats n input as no' {
        Mock Read-Host { 'n' }
        Confirm-AutoFix -Message 'Test' -Yes:$false | Should -BeFalse
    }
}
