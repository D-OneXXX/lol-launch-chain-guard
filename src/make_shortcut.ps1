# make_shortcut.ps1 - create / keep / delete the native client shortcut.
#
# Kept as a separate file on purpose: a single powershell -Command line this
# long is fragile when launched from a .bat (quoting, line length, code page).
# This file is pure ASCII on purpose; the shortcut name is built from code
# points so no console code page can corrupt it.
#
# Output: exactly one token on stdout, consumed by lol-chain-lock.bat.
#   CREATED / REPLACED / EXISTS_KEPT / EXISTS_DIFFERENT / REMOVED / ABSENT
#   TARGET_MISSING / NO_ROOT / NO_DESKTOP / FAILED

param(
    [string]$Root = '',
    [string]$Action = 'create',
    [string]$Desktop = ''
)

$ErrorActionPreference = 'Stop'

function Get-SafeRoot {
    param([string]$Given)
    if ($Given -and (Test-Path -LiteralPath $Given)) { return $Given }
    # Fall back to the registry: PowerShell reads it as Unicode, so a
    # non-ASCII install path survives even if the caller is not ANSI-clean.
    $keys = @(
        'HKCU:\SOFTWARE\Tencent\LOL',
        'HKLM:\SOFTWARE\Tencent\LOL',
        'HKLM:\SOFTWARE\WOW6432Node\Tencent\LOL'
    )
    foreach ($k in $keys) {
        try {
            $v = (Get-ItemProperty -LiteralPath $k -ErrorAction Stop).InstallPath
            if ($v -and (Test-Path -LiteralPath $v)) { return $v }
        } catch { }
    }
    return ''
}

try {
    $r = Get-SafeRoot $Root
    if (-not $r) { Write-Output 'NO_ROOT'; exit 0 }

    if (-not $Desktop) { $Desktop = [Environment]::GetFolderPath('Desktop') }
    if (-not $Desktop) { Write-Output 'NO_DESKTOP'; exit 0 }

    # Canonical name, no space before the bracket. Kept byte-identical across
    # releases so an upgrade can never leave two icons on the desktop.
    $name = [string]([char]0x82F1 + [char]0x96C4 + [char]0x8054 + [char]0x76DF + '(' +
                     [char]0x539F + [char]0x751F + [char]0x5BA2 + [char]0x6237 + [char]0x7AEF + ').lnk')
    # v2.2.0 wrote the same name with an extra space; migrate it away on sight.
    $legacy = [string]([char]0x82F1 + [char]0x96C4 + [char]0x8054 + [char]0x76DF + ' (' +
                       [char]0x539F + [char]0x751F + [char]0x5BA2 + [char]0x6237 + [char]0x7AEF + ').lnk')
    $lnk  = Join-Path $Desktop $name
    $lnkLegacy = Join-Path $Desktop $legacy
    $exe  = Join-Path $r 'TCLS\Client.exe'

    if (-not (Test-Path -LiteralPath $exe)) { Write-Output 'TARGET_MISSING'; exit 0 }

    $existed       = Test-Path -LiteralPath $lnk
    $legacyExisted = Test-Path -LiteralPath $lnkLegacy

    if ($Action -eq 'delete') {
        if ($existed)       { Remove-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue }
        if ($legacyExisted) { Remove-Item -LiteralPath $lnkLegacy -Force -ErrorAction SilentlyContinue }
        if ((Test-Path -LiteralPath $lnk) -or (Test-Path -LiteralPath $lnkLegacy)) { Write-Output 'FAILED' }
        elseif ($existed -or $legacyExisted) { Write-Output 'REMOVED' }
        else { Write-Output 'ABSENT' }
        exit 0
    }

    # One icon rule: the space-named leftover is our own v2.2.0 artefact, so it
    # is removed whenever it is seen, never left next to the canonical icon.
    if ($legacyExisted) {
        Remove-Item -LiteralPath $lnkLegacy -Force -ErrorAction SilentlyContinue
    }

    $shell = New-Object -ComObject WScript.Shell

    if ($existed -and $Action -eq 'create') {
        $old = ''
        try { $old = $shell.CreateShortcut($lnk).TargetPath } catch { $old = '' }
        if ($old -and ($old -ieq $exe)) { Write-Output 'EXISTS_KEPT' }
        else { Write-Output 'EXISTS_DIFFERENT' }
        exit 0
    }

    try {
        $s = $shell.CreateShortcut($lnk)
        $s.TargetPath        = $exe
        $s.WorkingDirectory  = Split-Path -Parent $exe
        $s.IconLocation      = $exe + ',0'
        $s.Description       = 'League of Legends native client'
        $s.Save()
    } catch {
        Write-Output 'FAILED'
        exit 0
    }

    if (-not (Test-Path -LiteralPath $lnk)) { Write-Output 'FAILED'; exit 0 }
    if ($existed) { Write-Output 'REPLACED' } else { Write-Output 'CREATED' }
} catch {
    Write-Output 'FAILED'
}
