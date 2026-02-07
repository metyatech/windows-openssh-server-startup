Set-StrictMode -Version Latest

function Get-OpenSshServerModuleVersion {
    '0.4.0'
}

function Test-IsAdmin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Confirm-AutoFix {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter(Mandatory)]
        [bool]$Yes,
        [Parameter(DontShow)]
        [bool]$UserInteractive = [Environment]::UserInteractive
    )

    if ($Yes) {
        return $true
    }

    if (-not $UserInteractive) {
        return $false
    }

    $answer = Read-Host "$Message (Y/n)"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $true
    }
    return $answer -match '^(y|yes)$'
}

function Get-InvocationArgumentList {
    param(
        [Parameter(Mandatory)]
        [hashtable]$BoundParameters,
        [Parameter(Mandatory)]
        [string[]]$ExcludeKeys
    )

    $argumentList = @()
    foreach ($key in $BoundParameters.Keys) {
        if ($ExcludeKeys -contains $key) {
            continue
        }
        $value = $BoundParameters[$key]
        if ($value -is [switch]) {
            if ($value.IsPresent) {
                $argumentList += "-$key"
            }
        } elseif ($value -is [bool]) {
            if ($value) {
                $argumentList += "-$key"
            }
        } else {
            $argumentList += "-$key"
            $argumentList += "$value"
        }
    }
    return $argumentList
}

function Add-ResultItem {
    param(
        [Parameter(Mandatory)]
        [object]$Result,
        [Parameter(Mandatory)]
        [string]$Collection,
        [Parameter(Mandatory)]
        [object]$Item
    )

    $Result.$Collection += $Item
}
