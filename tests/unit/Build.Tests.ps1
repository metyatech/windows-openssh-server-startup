Set-StrictMode -Version Latest

Describe 'Build script' {
    It 'copies the LICENSE file to the module directory' {
        $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
        $buildScript = Join-Path $repoRoot 'scripts\build.ps1'
        $licenseInModule = Join-Path $repoRoot 'WindowsOpenSshServerStartup\LICENSE'

        # Ensure clean state
        if (Test-Path $licenseInModule) {
            Remove-Item $licenseInModule -Force
        }

        # Run build script
        & $buildScript 6>$null 4>$null 3>$null 2>$null

        # Assert
        Test-Path $licenseInModule | Should -Be $true
    }
}
