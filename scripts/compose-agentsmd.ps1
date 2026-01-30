[CmdletBinding()]
param(
    [Alias('h')]
    [switch]$Help,

    [Alias('V')]
    [switch]$Version,

    [switch]$DryRun,

    [Alias('y')]
    [switch]$Yes,

    [switch]$Force,

    [switch]$Refresh,

    [switch]$ClearCache,

    [switch]$Json,

    [switch]$Quiet,

    [string]$RulesetPath = 'agent-ruleset.json'
)

Set-StrictMode -Version Latest

$script:ComposeAgentsMdVersion = '1.0.0'

function Write-Usage {
    param(
        [string]$ScriptName
    )

    @"
Usage: $ScriptName [-Help] [-Version] [-DryRun] [-Yes] [-Force] [-Refresh] [-ClearCache] [-Json] [-Quiet] [-RulesetPath <path>]

Composes AGENTS.md with compose-agentsmd, then normalizes Source paths to stable, non-absolute references.

Options:
  -Help, -h           Show this help text and exit
  -Version, -V        Show version and exit
  -DryRun             Show planned normalization without writing files
  -Yes, -y            Skip confirmation prompt
  -Force              Skip confirmation prompt
  -Refresh            Refresh cached remote rules
  -ClearCache         Remove cached remote rules and exit
  -Json               Emit machine-readable output
  -Quiet              Suppress non-JSON output
  -RulesetPath        Path to the ruleset file (default: agent-ruleset.json)

Examples:
  .\scripts\compose-agentsmd.ps1 -Yes
  .\scripts\compose-agentsmd.ps1 -DryRun
  .\scripts\compose-agentsmd.ps1 -RulesetPath agent-ruleset.json -Yes
"@
}

function Convert-AgentsMdSourcePath {
    param(
        [Parameter(Mandatory)]
        [string]$SourcePath,

        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $normalized = $SourcePath -replace '\\', '/'

    $cachePattern = '/\.agentsmd/cache/(?<owner>[^/]+)/(?<repo>[^/]+)/(?<ref>[^/]+)/(?<rules>rules/.+)$'
    if ($normalized -match $cachePattern) {
        return "github:$($Matches.owner)/$($Matches.repo)@$($Matches.ref)/$($Matches.rules)"
    }

    if ([System.IO.Path]::IsPathRooted($SourcePath)) {
        $repoRootFull = [System.IO.Path]::GetFullPath($RepoRoot)
        $sourceFull = [System.IO.Path]::GetFullPath($SourcePath)

        $repoRootNormalized = $repoRootFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        if ($sourceFull.StartsWith($repoRootNormalized, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relative = $sourceFull.Substring($repoRootNormalized.Length)
            return ($relative -replace '\\', '/')
        }

        throw "Unsupported absolute path outside repo root: $SourcePath"
    }

    return $normalized
}

function Split-TextLine {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $reader = [System.IO.StringReader]::new($Content)
    while ($true) {
        $line = $reader.ReadLine()
        if ($null -eq $line) {
            break
        }
        $lines.Add($line)
    }

    if ($Content.EndsWith("`r`n") -or $Content.EndsWith("`n")) {
        $lines.Add('')
    }

    return ,$lines.ToArray()
}

function Convert-AgentsMdSourceContent {
    param(
        [Parameter(Mandatory)]
        [string]$Content,

        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $lineEnding = if ($Content -match "`r`n") { "`r`n" } else { "`n" }
    $lines = Split-TextLine -Content $Content
    $changes = @()

    for ($index = 0; $index -lt $lines.Length; $index += 1) {
        $line = $lines[$index]
        if ($line -match '^Source:\s+(.+)$') {
            $sourcePath = $Matches[1]
            $normalizedPath = Convert-AgentsMdSourcePath -SourcePath $sourcePath -RepoRoot $RepoRoot
            if ($normalizedPath -ne $sourcePath) {
                $changes += [pscustomobject]@{
                    From = $sourcePath
                    To = $normalizedPath
                }
                $lines[$index] = "Source: $normalizedPath"
            }
        }
    }

    $normalized = $lines -join $lineEnding
    return [pscustomobject]@{
        Content = $normalized
        Changes = $changes
    }
}

function Get-RulesetOutputPath {
    param(
        [Parameter(Mandatory)]
        [string]$RulesetPath,

        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $rulesetFullPath = if ([System.IO.Path]::IsPathRooted($RulesetPath)) {
        $RulesetPath
    }
    else {
        Join-Path $RepoRoot $RulesetPath
    }

    if (-not (Test-Path -LiteralPath $rulesetFullPath)) {
        throw "Ruleset not found: $rulesetFullPath"
    }

    $raw = Get-Content -LiteralPath $rulesetFullPath -Raw
    $withoutComments = (Split-TextLine -Content $raw) | Where-Object { $_ -notmatch '^\s*//' }
    $json = ($withoutComments -join "`n").Trim()
    if (-not $json) {
        throw "Ruleset is empty after removing comments: $rulesetFullPath"
    }

    $parsed = $json | ConvertFrom-Json
    $output = $parsed.output
    if (-not $output) {
        $output = 'AGENTS.md'
    }

    if ([System.IO.Path]::IsPathRooted($output)) {
        return $output
    }

    return (Join-Path $RepoRoot $output)
}

function Test-NoAbsoluteSource {
    param(
        [Parameter(Mandatory)]
        [string]$Content
    )

    $lines = Split-TextLine -Content $Content
    foreach ($line in $lines) {
        if ($line -match '^Source:\s+[A-Za-z]:[\\/]' -or $line -match '^Source:\s+/') {
            throw "Absolute Source path remains after normalization: $line"
        }
    }
}

function Invoke-ComposeAgentsMdNormalization {
    param(
        [switch]$Help,
        [switch]$Version,
        [switch]$DryRun,
        [switch]$Yes,
        [switch]$Force,
        [switch]$Refresh,
        [switch]$ClearCache,
        [switch]$Json,
        [switch]$Quiet,
        [string]$RulesetPath = 'agent-ruleset.json'
    )

    if ($Help) {
        Write-Output (Write-Usage -ScriptName $MyInvocation.MyCommand.Name)
        exit 0
    }

    if ($Version) {
        Write-Output $script:ComposeAgentsMdVersion
        exit 0
    }

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

    $composeArgs = @()
    if ($Refresh) {
        $composeArgs += '--refresh'
    }
    if ($ClearCache) {
        $composeArgs += '--clear-cache'
    }

    Push-Location $repoRoot
    try {
        & compose-agentsmd @composeArgs
        if ($LASTEXITCODE -ne 0) {
            throw "compose-agentsmd failed with exit code $LASTEXITCODE."
        }
    }
    finally {
        Pop-Location
    }

    if ($ClearCache) {
        if (-not $Quiet -and -not $Json) {
            Write-Output 'Cache cleared.'
        }
        return
    }

    $outputPath = Get-RulesetOutputPath -RulesetPath $RulesetPath -RepoRoot $repoRoot
    if (-not (Test-Path -LiteralPath $outputPath)) {
        throw "AGENTS.md not found after compose: $outputPath"
    }

    $content = Get-Content -LiteralPath $outputPath -Raw
    $normalized = Convert-AgentsMdSourceContent -Content $content -RepoRoot $repoRoot
    $changes = $normalized.Changes

    if ($DryRun) {
        $payload = [pscustomobject]@{
            outputPath = $outputPath
            normalizedCount = $changes.Count
            changed = $changes.Count -gt 0
        }
        if ($Json) {
            $payload | ConvertTo-Json -Depth 4
        }
        elseif (-not $Quiet) {
            Write-Output "Dry run: would normalize $($changes.Count) Source path(s) in $outputPath."
        }
        return
    }

    if ($changes.Count -eq 0) {
        if ($Json) {
            [pscustomobject]@{
                outputPath = $outputPath
                normalizedCount = 0
                changed = $false
            } | ConvertTo-Json -Depth 4
        }
        elseif (-not $Quiet) {
            Write-Output "No normalization needed for $outputPath."
        }
        return
    }

    if (-not $Yes -and -not $Force) {
        $response = Read-Host "Normalize $($changes.Count) Source path(s) in $outputPath? [Y/n]"
        if ($response -match '^(n|no)$') {
            if (-not $Quiet -and -not $Json) {
                Write-Output 'Skipped.'
            }
            return
        }
    }

    Test-NoAbsoluteSource -Content $normalized.Content
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($outputPath, $normalized.Content, $utf8NoBom)

    if ($Json) {
        [pscustomobject]@{
            outputPath = $outputPath
            normalizedCount = $changes.Count
            changed = $true
        } | ConvertTo-Json -Depth 4
    }
    elseif (-not $Quiet) {
        Write-Output "Normalized $($changes.Count) Source path(s) in $outputPath."
    }
}

if ($MyInvocation.InvocationName -eq '.') {
    return
}

Invoke-ComposeAgentsMdNormalization @PSBoundParameters
