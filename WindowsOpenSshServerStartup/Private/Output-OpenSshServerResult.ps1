Set-StrictMode -Version Latest

function Get-OpenSshServerResultSummary {
    param(
        [Parameter(Mandatory)]
        [object]$Result,
        [Parameter(Mandatory)]
        [ValidateSet('start', 'stop')]
        [string]$Operation
    )

    $summary = [ordered]@{
        version = $Result.version
        status = $Result.status
    }

    if ($Result.PSObject.Properties.Match('started').Count -gt 0) {
        $summary.started = $Result.started
    }

    if ($Result.PSObject.Properties.Match('stopped').Count -gt 0) {
        $summary.stopped = $Result.stopped
    }

    $summaryMessage = $null
    switch ($Result.status) {
        'success' {
            if ($summary.Contains('started') -and $summary.started) {
                $summaryMessage = 'OpenSSH Server is running.'
            } elseif ($summary.Contains('stopped') -and $summary.stopped) {
                $summaryMessage = 'OpenSSH Server is stopped.'
            } elseif ($Operation -eq 'start') {
                $summaryMessage = 'OpenSSH Server start completed.'
            } else {
                $summaryMessage = 'OpenSSH Server stop completed.'
            }
        }
        'pending' {
            $pending = $Result.warnings | Where-Object id -eq 'pending_elevation' | Select-Object -First 1
            if ($null -ne $pending -and $pending.PSObject.Properties.Match('message').Count -gt 0) {
                $summaryMessage = $pending.message
            } else {
                $summaryMessage = 'Operation is pending. Rerun the command to confirm.'
            }
        }
        'error' {
            $firstError = $Result.errors | Select-Object -First 1
            if ($null -ne $firstError -and $firstError.PSObject.Properties.Match('message').Count -gt 0) {
                $summaryMessage = $firstError.message
            } else {
                $summaryMessage = 'Operation failed. Use -Verbose or -Trace for details.'
            }
        }
        default {
            $summaryMessage = 'Operation completed.'
        }
    }

    $summary.message = $summaryMessage
    return [pscustomobject]$summary
}

function Test-OpenSshServerResultSuppressSummary {
    param(
        [Parameter(Mandatory)]
        [object]$Result
    )

    if ($Result.PSObject.Properties.Match('suppressSummary').Count -gt 0) {
        return [bool]$Result.suppressSummary
    }

    if ($Result.status -eq 'pending') {
        $sudoAction = $Result.actions | Where-Object { $_.action -eq 'elevate' -and $_.details -match 'sudo' } | Select-Object -First 1
        return ($null -ne $sudoAction)
    }

    if ($Result.status -ne 'success') {
        return $false
    }

    $actionsCount = @($Result.actions).Count
    $warningsCount = @($Result.warnings).Count
    $errorsCount = @($Result.errors).Count
    $started = ($Result.PSObject.Properties.Match('started').Count -gt 0) -and $Result.started
    $stopped = ($Result.PSObject.Properties.Match('stopped').Count -gt 0) -and $Result.stopped

    if (($started -or $stopped) -and $actionsCount -eq 0 -and $warningsCount -eq 0 -and $errorsCount -eq 0) {
        return $true
    }

    if ($stopped -and $actionsCount -eq 0 -and $errorsCount -eq 0) {
        $stopWarnings = @($Result.warnings | Where-Object id -eq 'sshd_not_running')
        if ($stopWarnings.Count -gt 0 -and $warningsCount -eq $stopWarnings.Count) {
            return $true
        }
    }

    return $false
}
