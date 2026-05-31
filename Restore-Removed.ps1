<#
================================================================================
 Restore-Removed.ps1
 Put back something the Dell/Alienware purge removed - especially fan/thermal
 (Alienware Command Center) if performance changed after removal.

 Shows what the last purge removed (from last-removal.json), then offers:
   1) System Restore  - the reliable way; restores EXACTLY what was removed.
   2) Best-effort reinstall of Alienware Command Center (fan/RGB control).
   3) Open Dell Drivers & Downloads page for a manual reinstall.
================================================================================
#>

$ErrorActionPreference = 'SilentlyContinue'
$manifestPath = Join-Path $PSScriptRoot 'last-removal.json'

Clear-Host
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " Restore / Add-Back" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan

# --- Show what the last purge removed -------------------------------------- #
if (Test-Path $manifestPath) {
    try {
        $m = Get-Content $manifestPath -Raw | ConvertFrom-Json
        Write-Host ""
        Write-Host "Last purge: $($m.When)   (Safe/KeepThermal mode: $($m.KeepThermal))" -ForegroundColor White
        Write-Host "Items removed:" -ForegroundColor White
        if ($m.RemovedItems) { $m.RemovedItems | ForEach-Object { Write-Host "   - $_" -ForegroundColor Gray } }
        else { Write-Host "   (none recorded)" -ForegroundColor DarkGray }
        if ($m.PerformanceItemsRemoved -and @($m.PerformanceItemsRemoved).Count -gt 0) {
            Write-Host ""
            Write-Host "Performance/thermal items that were removed:" -ForegroundColor Yellow
            $m.PerformanceItemsRemoved | ForEach-Object { Write-Host "   - $_" -ForegroundColor Yellow }
        } else {
            Write-Host ""
            Write-Host "No performance/thermal software was removed - nothing critical to add back." -ForegroundColor Green
        }
    } catch { Write-Host "Could not read last-removal.json." -ForegroundColor Yellow }
} else {
    Write-Host ""
    Write-Host "No purge record found (last-removal.json missing)." -ForegroundColor Yellow
    Write-Host "You can still use System Restore below if you removed things earlier." -ForegroundColor Yellow
}

# --- Options --------------------------------------------------------------- #
Write-Host ""
Write-Host "How do you want to add software back?" -ForegroundColor Cyan
Write-Host "  1) System Restore  (RECOMMENDED - restores exactly what was removed)" -ForegroundColor White
Write-Host "  2) Reinstall Alienware Command Center (fan/RGB control) - best effort" -ForegroundColor White
Write-Host "  3) Open Dell Drivers & Downloads page (manual)" -ForegroundColor White
Write-Host "  Q) Back" -ForegroundColor Gray
$c = (Read-Host "Choose").Trim().ToUpper()

switch ($c) {
    '1' {
        Write-Host ""
        Write-Host "Opening System Restore..." -ForegroundColor Cyan
        Write-Host "In the window: Next -> tick 'Show more restore points' ->" -ForegroundColor Yellow
        Write-Host "choose 'Before Dell/Alienware purge' -> Next -> Finish." -ForegroundColor Yellow
        Start-Process rstrui.exe
    }
    '2' {
        Write-Host ""
        Write-Host "Trying to reinstall Alienware Command Center via winget..." -ForegroundColor Cyan
        $wg = Get-Command winget -ErrorAction SilentlyContinue
        $ok = $false
        if ($wg) {
            winget install --name "Alienware Command Center" --accept-package-agreements --accept-source-agreements --disable-interactivity
            if ($LASTEXITCODE -eq 0) { $ok = $true }
        }
        if (-not $ok) {
            Write-Host "winget couldn't install it automatically." -ForegroundColor Yellow
            Write-Host "Opening the Microsoft Store page instead..." -ForegroundColor Cyan
            Start-Process "ms-windows-store://search/?query=Alienware Command Center"
        } else {
            Write-Host "Alienware Command Center reinstall started/completed." -ForegroundColor Green
        }
    }
    '3' {
        Write-Host "Opening Dell Drivers & Downloads (it auto-detects your model)..." -ForegroundColor Cyan
        Start-Process "https://www.dell.com/support/home/en-us?app=drivers"
    }
    default { Write-Host "OK, nothing changed." -ForegroundColor DarkGray }
}

Write-Host ""
Write-Host "Tip: after any reinstall or restore, REBOOT so it loads cleanly." -ForegroundColor Cyan
