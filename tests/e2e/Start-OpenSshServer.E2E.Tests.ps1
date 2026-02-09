Set-StrictMode -Version Latest

Describe 'Start-OpenSshServer CLI' {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $script:scriptPath = Join-Path $script:repoRoot 'Start-OpenSshServer.ps1'
    }

    It 'prints version' {
        $version = & $script:scriptPath -Version
        $version | Should -Match '\d+\.\d+\.\d+'
    }

    It 'prints help text' {
        $helpText = & $script:scriptPath -Help
        $helpText | Should -Match 'Usage:'
        $helpText | Should -Match 'Start-OpenSshServer.ps1'
    }
}

Describe 'Stop-OpenSshServer CLI' {
    BeforeAll {
        $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $script:stopScriptPath = Join-Path $script:repoRoot 'Stop-OpenSshServer.ps1'
    }

    It 'prints version' {
        $version = & $script:stopScriptPath -Version
        $version | Should -Match '\d+\.\d+\.\d+'
    }

    It 'prints help text' {
        $helpText = & $script:stopScriptPath -Help
        $helpText | Should -Match 'Usage:'
        $helpText | Should -Match 'Stop-OpenSshServer.ps1'
    }
}
