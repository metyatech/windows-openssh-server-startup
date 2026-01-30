Set-StrictMode -Version Latest

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$testsPath = Join-Path $repoRoot 'tests'
$testResultsPath = Join-Path $repoRoot 'TestResults'
$testResultsFile = Join-Path $testResultsPath 'testResults.xml'

if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Error 'Pester is not installed. Run: Install-Module Pester -Scope CurrentUser'
    exit 1
}

Import-Module Pester -MinimumVersion 5.0 -Force
$null = New-Item -Path $testResultsPath -ItemType Directory -Force

$config = New-PesterConfiguration
$config.Run.Path = $testsPath
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = $testResultsFile
$config.TestResult.OutputFormat = 'NUnitXml'

Invoke-Pester -Configuration $config
