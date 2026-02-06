function Confirm-AutoFix {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [Parameter(Mandatory)]
        [bool]$Yes,
        [Parameter(Mandatory)]
        [scriptblock]$IsInteractive
    )

    if ($Yes) {
        return $true
    }

    if (-not (& $IsInteractive)) {
        return $false
    }

    $answer = Read-Host "$Message (Y/n)"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $true
    }
    return $answer -match '^(y|yes)$'
}
