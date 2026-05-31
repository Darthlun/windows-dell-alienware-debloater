<#
================================================================================
 Tune-Up-Edge.ps1
 Stops Microsoft Edge from hogging RAM in the background.

 It does NOT uninstall Edge and changes NO browsing data. It only:
   1. Turns OFF "Startup boost"          (Edge preloading itself at boot)
   2. Turns OFF "Continue running background apps when Edge is closed"
   3. Removes Edge's auto-launch-at-login entry

 All three are reversible:  run with  -Undo  to put everything back.

 HOW TO RUN  (must be Administrator)
   Right-click Start -> "Terminal (Admin)", then:
     cd "$env:USERPROFILE\Downloads\windows-dell-alienware-debloater"

   Preview (changes nothing):
     powershell -ExecutionPolicy Bypass -File ".\Tune-Up-Edge.ps1" -DryRun
   Apply:
     powershell -ExecutionPolicy Bypass -File ".\Tune-Up-Edge.ps1"
   Undo:
     powershell -ExecutionPolicy Bypass -File ".\Tune-Up-Edge.ps1" -Undo

 NOTE: After applying, fully close Edge (or reboot) for it to take effect.
       Edge will show a small "managed by your organization" note in its
       settings - that's just because these are now enforced. -Undo removes it.
================================================================================
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Undo
)

$ErrorActionPreference = 'Continue'
$logFile = Join-Path $PSScriptRoot ("Edge-tuneup-log-{0:yyyyMMdd-HHmmss}.txt" -f (Get-Date))

function Log {
    param([string]$Message, [string]$Color = 'Gray')
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $Message)
}
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

Clear-Host
Log "==============================================================" Cyan
Log " Microsoft Edge Tune-Up" Cyan
if ($DryRun) { Log " *** DRY RUN - nothing will be changed ***" Yellow }
if ($Undo)   { Log " *** UNDO mode - restoring Edge defaults ***" Yellow }
Log " Log file: $logFile" Cyan
Log "==============================================================" Cyan

if (-not (Test-Admin)) {
    Log "ERROR: Run this as Administrator." Red
    Log "Right-click Start -> 'Terminal (Admin)' and run it again." Red
    return
}

$EdgePolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
$RunKey     = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'

# --------------------------------------------------------------------------- #
#  UNDO
# --------------------------------------------------------------------------- #
if ($Undo) {
    Log ""
    Log "Removing the Edge policy tweaks (reverts to Edge defaults)..." Cyan
    foreach ($name in 'StartupBoostEnabled','BackgroundModeEnabled') {
        if (Test-Path $EdgePolicy) {
            $exists = (Get-ItemProperty $EdgePolicy -Name $name -ErrorAction SilentlyContinue)
            if ($exists) {
                if ($DryRun) { Log "  [WOULD remove policy] $name" Yellow }
                else { Remove-ItemProperty $EdgePolicy -Name $name -Force -ErrorAction SilentlyContinue
                       Log "  [removed policy] $name" Green }
            } else { Log "  [not set] $name" DarkGray }
        }
    }
    Log ""
    Log "Done. Startup boost / background mode are back under Edge's own control." Green
    Log "(Edge will re-add its login auto-launch on next launch if it wants to.)" DarkGray
    Log " Log: $logFile" Cyan
    return
}

# --------------------------------------------------------------------------- #
#  APPLY
# --------------------------------------------------------------------------- #
function Set-Policy {
    param([string]$Name)
    if ($DryRun) { Log "  [WOULD set] $Name = 0 (disabled)" Yellow; return }
    if (-not (Test-Path $EdgePolicy)) { New-Item -Path $EdgePolicy -Force | Out-Null }
    New-ItemProperty -Path $EdgePolicy -Name $Name -Value 0 -PropertyType DWord -Force | Out-Null
    Log "  [set] $Name = 0 (disabled)" Green
}

Log ""
Log "----- 1 & 2: Disable Startup Boost + background running -----" Cyan
Write-Progress -Activity "Edge tune-up" -Status "Disabling Startup Boost + background mode" -PercentComplete 33
Set-Policy 'StartupBoostEnabled'
Set-Policy 'BackgroundModeEnabled'

Log ""
Log "----- 3: Remove Edge auto-launch-at-login entries -----" Cyan
Write-Progress -Activity "Edge tune-up" -Status "Removing login auto-launch" -PercentComplete 66
$props = (Get-ItemProperty $RunKey -ErrorAction SilentlyContinue).PSObject.Properties |
            Where-Object { $_.Name -like 'MicrosoftEdgeAutoLaunch*' -or
                           ($_.Value -is [string] -and $_.Value -like '*msedge.exe*--win-session-start*') }
if (-not $props) {
    Log "  [none found] No Edge login auto-launch entry present." DarkGray
} else {
    foreach ($p in $props) {
        Log "  Found: $($p.Name) = $($p.Value)" White   # logged so you can re-add if ever wanted
        if ($DryRun) { Log "  [WOULD remove] $($p.Name)" Yellow }
        else {
            Remove-ItemProperty -Path $RunKey -Name $p.Name -Force -ErrorAction SilentlyContinue
            Log "  [removed] $($p.Name)" Green
        }
    }
}

# --------------------------------------------------------------------------- #
#  Done
# --------------------------------------------------------------------------- #
Write-Progress -Activity "Edge tune-up" -Completed
Log ""
Log "==============================================================" Cyan
if ($DryRun) {
    Log " DRY RUN complete. Re-run without -DryRun to apply." Yellow
} else {
    Log " Done! Fully close Edge (or reboot) for it to take effect." Green
    Log " To revert: run this script again with  -Undo" Green
}
Log " Log saved to: $logFile" Cyan
Log "==============================================================" Cyan
