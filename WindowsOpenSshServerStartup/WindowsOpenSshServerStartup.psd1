@{
    RootModule = 'WindowsOpenSshServerStartup.psm1'
    ModuleVersion = '0.3.7'
    GUID = 'ed6f82d7-ed27-4082-9921-dbb055ed43b6'
    Author = 'metyatech'
    CompanyName = 'metyatech'
    Copyright = '(c) 2026 metyatech. All rights reserved.'
    Description = 'Start and stop Windows OpenSSH Server with validation and optional remediation.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Start-OpenSshServer', 'Stop-OpenSshServer')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('OpenSSH', 'SSH', 'Windows', 'Server', 'Startup')
            LicenseUri = 'https://github.com/metyatech/windows-openssh-server-startup/blob/main/LICENSE'
            ProjectUri = 'https://github.com/metyatech/windows-openssh-server-startup'
            ReleaseNotes = 'Suppress summary output when no action is needed.'
        }
    }
}
