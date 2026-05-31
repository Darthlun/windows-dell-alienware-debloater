<#
================================================================================
 Tune-Up-Startup.ps1
 Disables startup apps that don't need to launch at boot.

 It does NOT uninstall anything - it just stops these from auto-starting
 (exactly like the "Disable" button on Task Manager's Startup tab).

 DISABLES (safe, gains boot speed + RAM):
   - Discord            (open it yourself when you want it)
   - Mobile devices     (CrossDevice / phone-link background task)

 DELIBERATELY LEFT ALONE:
   - OneDrive           (your Desktop lives in OneDrive - needs to sync)
   - Realtek HD Audio   (audio driver helper)
   - Windows Security   (security tray icon)

 Everything is reversible:  run with  -Undo  to re-enable.

 HOW TO RUN  (must be Administrator)
   Right-click Start -> "Terminal (Admin)", then:
     cd "$env:USERPROFILE\Downloads\windows-dell-alienware-debloater"
     powershell -ExecutionPolicy Bypass -File ".\Tune-Up-Startup.ps1" -DryRun   # preview
     powershell -ExecutionPolicy Bypass -File ".\Tune-Up-Startup.ps1"           # apply
     powershell -ExecutionPolicy Bypass -File ".\Tune-Up-Startup.ps1" -Undo     # revert
================================================================================
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Undo
)

$ErrorActionPreference = 'Continue'
$logFile = Join-Path $PSScriptRoot ("Startup-tuneup-log-{0:yyyyMMdd-HHmmss}.txt" -f (Get-Date))
function Log { param([string]$m,[string]$c='Gray'); Write-Host $m -ForegroundColor $c
    Add-Content -Path $logFile -Value ("[{0:HH:mm:ss}] {1}" -f (Get-Date), $m) }
function Test-Admin {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator) }

# --- WHAT TO DISABLE -------------------------------------------------------- #
# Classic "Run" entries, matched by their registry value name:
$DisableClassic = @('Discord')
# UWP/Store startup tasks, matched by package-family-name prefix:
$DisableUwp     = @('MicrosoftWindows.CrossDevice')   # "Mobile devices"

Clear-Host
Log "==============================================================" Cyan
Log " Startup Tune-Up" Cyan
if ($DryRun) { Log " *** DRY RUN - nothing will be changed ***" Yellow }
if ($Undo)   { Log " *** UNDO mode - re-enabling startup items ***" Yellow }
Log " Log file: $logFile" Cyan
Log "==============================================================" Cyan

if (-not (Test-Admin)) {
    Log "ERROR: Run this as Administrator (right-click Start -> Terminal (Admin))." Red
    return
}

$wantState = if ($Undo) { 'enabled' } else { 'disabled' }

# --------------------------------------------------------------------------- #
# Classic Run items  (StartupApproved flag: 0x02 = enabled, 0x03 = disabled)
# --------------------------------------------------------------------------- #
$approvedKeys = @(
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'
)

function Set-ClassicState {
    param([string]$Name, [bool]$Enable)
    $firstByte = if ($Enable) { 0x02 } else { 0x03 }
    $hit = $false
    foreach ($k in $approvedKeys) {
        if (-not (Test-Path $k)) {
            if ($Enable) { continue }      # only create when disabling
            New-Item -Path $k -Force | Out-Null
        }
        $existing = Get-ItemProperty $k -Name $Name -ErrorAction SilentlyContinue
        $bytes = if ($existing) { ,@($existing.$Name) | ForEach-Object { $_ } } else { ,([byte[]](,0x00*12)) }
        $bytes = [byte[]]$bytes
        if ($bytes.Length -lt 12) { $bytes = [byte[]](,0x00*12) }
        $bytes[0] = $firstByte
        if ($DryRun) { Log "    [WOULD set $Name -> $wantState] ($k)" Yellow; $hit=$true; continue }
        New-ItemProperty -Path $k -Name $Name -PropertyType Binary -Value $bytes -Force | Out-Null
        Log "    [$wantState] $Name  ($k)" Green
        $hit = $true
    }
    if (-not $hit) { Log "    [not found] $Name" DarkGray }
}

Log ""
Log "----- Classic startup apps -----" Cyan
$i = 0; $total = @($DisableClassic).Count
foreach ($n in $DisableClassic) {
    $i++
    Write-Progress -Id 1 -Activity "Updating classic startup apps" `
        -Status "$i of $total : $n" -PercentComplete (($i / [math]::Max($total,1)) * 100)
    Log "  $n :" White
    Set-ClassicState -Name $n -Enable:$Undo
}
Write-Progress -Id 1 -Activity "Updating classic startup apps" -Completed

# --------------------------------------------------------------------------- #
# UWP / Store startup tasks  (State: 2 = enabled, 1 = disabled-by-user)
# --------------------------------------------------------------------------- #
$uwpBase = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData'
$targetState = if ($Undo) { 2 } else { 1 }

Log ""
Log "----- UWP / Store startup tasks -----" Cyan
$i = 0; $total = @($DisableUwp).Count
foreach ($pkgPrefix in $DisableUwp) {
    $i++
    Write-Progress -Id 1 -Activity "Updating Store app startup tasks" `
        -Status "$i of $total : $pkgPrefix" -PercentComplete (($i / [math]::Max($total,1)) * 100)
    $pkgKeys = Get-ChildItem $uwpBase -ErrorAction SilentlyContinue |
                 Where-Object { $_.PSChildName -like "$pkgPrefix*" }
    if (-not $pkgKeys) { Log "  [not found] $pkgPrefix" DarkGray; continue }
    foreach ($pk in $pkgKeys) {
        Log "  $($pk.PSChildName) :" White
        # Startup task subkeys are the ones that carry a 'State' value.
        Get-ChildItem $pk.PSPath -ErrorAction SilentlyContinue | ForEach-Object {
            $st = Get-ItemProperty $_.PSPath -Name State -ErrorAction SilentlyContinue
            if ($st -ne $null) {
                if ($DryRun) { Log "    [WOULD set $($_.PSChildName) State=$targetState ($wantState)]" Yellow }
                else {
                    Set-ItemProperty $_.PSPath -Name State -Value $targetState -Type DWord -Force
                    Log "    [$wantState] $($_.PSChildName)" Green
                }
            }
        }
    }
}
Write-Progress -Id 1 -Activity "Updating Store app startup tasks" -Completed

# --------------------------------------------------------------------------- #
Log ""
Log "==============================================================" Cyan
if ($DryRun) {
    Log " DRY RUN complete. Re-run without -DryRun to apply." Yellow
} else {
    Log " Done! Changes show on the Startup tab and take full effect" Green
    Log " after your next sign-out / reboot." Green
    Log " To revert: run this script again with  -Undo" Green
}
Log " Log saved to: $logFile" Cyan
Log "==============================================================" Cyan
