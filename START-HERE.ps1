<#
================================================================================
 START-HERE.ps1
 One menu to run all the cleanup scripts. Just right-click this file ->
 "Run with PowerShell" (it will ask for Admin and re-launch itself elevated).

 Menu options:
   1) Remove ALL Dell/Alienware bloat
   2) Edge tune-up (stop background RAM hogging)
   3) Startup tune-up (Discord + Mobile devices)
   4) Debloat Windows Store junk (optional - Bing News, Solitaire, etc.)
   5) Verify everything (read-only PASS/FAIL report)
   6) Run the recommended sequence (1 -> 2 -> 3)
   D) Toggle DRY-RUN (preview only, changes nothing)
   Q) Quit

 The individual scripts must be in the SAME folder as this file.
================================================================================
#>

# --------------------------------------------------------------------------- #
#  Self-elevate to Administrator
# --------------------------------------------------------------------------- #
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}
if (-not (Test-Admin)) {
    Write-Host "Re-launching as Administrator..." -ForegroundColor Yellow
    try {
        Start-Process powershell.exe -Verb RunAs `
            -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$PSCommandPath`""
    } catch {
        Write-Host "You declined the Admin prompt. The scripts need Admin to work." -ForegroundColor Red
        Read-Host "Press Enter to exit"
    }
    exit
}

$root = $PSScriptRoot
$DryRun = $false       # default; toggle with 'D'
$KeepThermal = $true   # SAFE MODE default: keep fan/thermal/RGB control; toggle with 'T'

# Map menu choices to script files.
$scripts = @{
    '1' = @{ File = 'Remove-DellAlienware.ps1'; Name = 'Remove ALL Dell/Alienware bloat'; Reboot = $true }
    '2' = @{ File = 'Tune-Up-Edge.ps1';         Name = 'Edge tune-up';                    Reboot = $false }
    '3' = @{ File = 'Tune-Up-Startup.ps1';      Name = 'Startup tune-up';                 Reboot = $true }
    '4' = @{ File = 'Debloat-Alienware.ps1';    Name = 'Debloat Windows Store junk';      Reboot = $false }
    '5' = @{ File = 'Verify-Cleanup.ps1';       Name = 'Verify everything';               Reboot = $false }
    'R' = @{ File = 'Restore-Removed.ps1';      Name = 'Restore / add something back';    Reboot = $false }
}

function Invoke-Script {
    param([string]$Key)
    $entry = $scripts[$Key]
    $path  = Join-Path $root $entry.File
    if (-not (Test-Path $path)) {
        Write-Host "ERROR: Can't find $($entry.File) in this folder." -ForegroundColor Red
        return
    }
    Write-Host ""
    Write-Host ">>> Running: $($entry.Name)" -ForegroundColor Cyan
    if ($DryRun -and $Key -ne '5') { Write-Host "    (DRY-RUN: nothing will be changed)" -ForegroundColor Yellow }
    Write-Host ("-" * 62) -ForegroundColor DarkGray

    # Verify (5) has no -DryRun switch; the others do.
    $opts = @{}
    if ($DryRun -and $Key -ne '5') { $opts['DryRun'] = $true }
    # Safe mode: pass -KeepThermal to the Dell purge (1) and the verifier (5).
    if ($KeepThermal -and ($Key -eq '1' -or $Key -eq '5')) { $opts['KeepThermal'] = $true }
    & $path @opts

    Write-Host ("-" * 62) -ForegroundColor DarkGray
    if ($entry.Reboot -and -not $DryRun) {
        Write-Host "TIP: a reboot is recommended after this one." -ForegroundColor Yellow
    }
}

function Show-Menu {
    Clear-Host
    Write-Host "==============================================================" -ForegroundColor Cyan
    Write-Host "        ALIENWARE / WINDOWS 11 CLEANUP  -  MAIN MENU" -ForegroundColor Cyan
    Write-Host "==============================================================" -ForegroundColor Cyan
    $mode = if ($DryRun) { 'ON  (preview only - nothing changes)' } else { 'OFF (changes will be applied)' }
    $modeColor = if ($DryRun) { 'Yellow' } else { 'Green' }
    Write-Host (" DRY-RUN mode: ") -NoNewline; Write-Host $mode -ForegroundColor $modeColor
    $safe = if ($KeepThermal) { 'ON  (keeps fan/thermal/RGB control - RECOMMENDED)' } else { 'OFF (will ALSO remove fan/thermal control!)' }
    $safeColor = if ($KeepThermal) { 'Green' } else { 'Red' }
    Write-Host (" SAFE mode   : ") -NoNewline; Write-Host $safe -ForegroundColor $safeColor
    Write-Host ""
    Write-Host "  1) Remove Dell/Alienware bloat (safe junk only)  (~2.1 GB)" -ForegroundColor White
    Write-Host "  2) Edge tune-up - stop background hogging  (~1 GB idle)" -ForegroundColor White
    Write-Host "  3) Startup tune-up - Discord + Mobile devices" -ForegroundColor White
    Write-Host "  4) Debloat Windows Store junk (optional)" -ForegroundColor White
    Write-Host "  5) Verify everything (read-only report)" -ForegroundColor White
    Write-Host "  6) Run recommended sequence  (1 -> 2 -> 3)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  R) Restore / add something back (undo a removal)" -ForegroundColor White
    Write-Host ""
    Write-Host "  D) Toggle DRY-RUN (preview vs apply)" -ForegroundColor Gray
    Write-Host "  T) Toggle SAFE mode (keep vs remove fan/thermal control)" -ForegroundColor Gray
    Write-Host "  Q) Quit" -ForegroundColor Gray
    Write-Host "==============================================================" -ForegroundColor Cyan
}

# --------------------------------------------------------------------------- #
#  Menu loop
# --------------------------------------------------------------------------- #
do {
    Show-Menu
    $choice = (Read-Host "Choose an option").Trim().ToUpper()

    switch ($choice) {
        '1' { Invoke-Script '1' }
        '2' { Invoke-Script '2' }
        '3' { Invoke-Script '3' }
        '4' { Invoke-Script '4' }
        '5' { Invoke-Script '5' }
        'R' { Invoke-Script 'R' }
        '6' {
            Write-Host ""
            Write-Host ">>> Running recommended sequence: Dell purge -> Edge -> Startup" -ForegroundColor Cyan
            Invoke-Script '1'
            Invoke-Script '2'
            Invoke-Script '3'
            Write-Host ""
            Write-Host "Sequence complete. Please REBOOT, then choose 5 to verify." -ForegroundColor Green
        }
        'D' {
            $DryRun = -not $DryRun
            Write-Host ("Dry-run is now {0}." -f ($(if($DryRun){'ON'}else{'OFF'}))) -ForegroundColor Yellow
            Start-Sleep -Milliseconds 700
        }
        'T' {
            $KeepThermal = -not $KeepThermal
            if ($KeepThermal) {
                Write-Host "SAFE mode ON - fan/thermal/RGB control will be KEPT." -ForegroundColor Green
            } else {
                Write-Host "WARNING: SAFE mode OFF - the Dell purge will ALSO remove" -ForegroundColor Red
                Write-Host "Command Center / fan & performance control. Only do this if" -ForegroundColor Red
                Write-Host "you really want zero Dell software left." -ForegroundColor Red
            }
            Start-Sleep -Milliseconds 1500
        }
        'Q' { Write-Host "Bye!" -ForegroundColor Cyan }
        default { Write-Host "Not a valid choice." -ForegroundColor Red; Start-Sleep -Milliseconds 700 }
    }

    if ($choice -ne 'Q' -and $choice -ne 'D' -and $choice -ne 'T') {
        Write-Host ""
        Read-Host "Press Enter to return to the menu"
    }
} while ($choice -ne 'Q')
