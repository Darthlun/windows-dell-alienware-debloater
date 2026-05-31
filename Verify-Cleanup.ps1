<#
================================================================================
 Verify-Cleanup.ps1
 READ-ONLY check that the other 3 scripts actually did their job.
 Changes NOTHING. Just reports PASS / FAIL / WARN for each item.

 Checks:
   [A] Remove-DellAlienware.ps1 - no Dell/Alienware programs, apps, services,
                                   tasks, processes, folders or reg keys left.
   [B] Tune-Up-Edge.ps1         - startup boost + background mode disabled,
                                   login auto-launch removed.
   [C] Tune-Up-Startup.ps1      - Discord + Mobile devices set to disabled.

 HOW TO RUN  (Administrator recommended so it can see all-user apps)
   Right-click Start -> "Terminal (Admin)", then:
     cd "$env:USERPROFILE\Downloads\windows-dell-alienware-debloater"
     powershell -ExecutionPolicy Bypass -File ".\Verify-Cleanup.ps1"
================================================================================
#>

param(
    [switch]$KeepThermal   # if set, NOT removing Command Center/XTU/FX is expected (not a failure)
)

$ErrorActionPreference = 'SilentlyContinue'
$results = New-Object System.Collections.Generic.List[object]

# Items deliberately kept in Safe / -KeepThermal mode (fan, performance, RGB).
$ThermalKeep = @('Command Center','AWCC','XTU','Xtu','Performance Plugin','AWIO',
                 'CoreInstaller','FXCore','FXDevice','FXELC','FX Display','FXInstaller')
function Is-ThermalKept { param([string]$Name)
    foreach ($t in $ThermalKeep) { if ($Name -like "*$t*") { return $true } }
    return $false
}

function Add-Result {
    param([string]$Area, [string]$Check, [ValidateSet('PASS','FAIL','WARN')]$Status,
          [string]$Detail = '', [string]$Fix = '')
    $results.Add([pscustomobject]@{ Area=$Area; Check=$Check; Status=$Status; Detail=$Detail; Fix=$Fix })
}
function Test-Admin {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

Clear-Host
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host " Cleanup Verification (read-only)" -ForegroundColor Cyan
Write-Host "==============================================================" -ForegroundColor Cyan
$isAdmin = Test-Admin
if (-not $isAdmin) {
    Write-Host "Note: not running as Admin - some all-user checks are limited." -ForegroundColor Yellow
}

# --------------------------------------------------------------------------- #
# Shared Dell/Alienware matcher (same logic as the removal script)
# --------------------------------------------------------------------------- #
$HardProtect = @('NVIDIA','Intel(R)','Realtek','Killer','Waves MaxxAudio')
function Matches-Dell {
    param([string]$Name, [string]$Publisher)
    if (-not $Name) { return $false }
    foreach ($h in $HardProtect) { if ($Name -like "*$h*") { return $false } }
    if ($Publisher -like '*Dell*' -or $Publisher -like '*Alienware*') { return $true }
    if ($Name -like '*Dell*' -or $Name -like '*Alienware*' -or $Name -like '*SupportAssist*' -or
        $Name -like '*AlienFX*' -or $Name -like '*AWCC*') { return $true }
    return $false
}

# =========================================================================== #
# [A] DELL / ALIENWARE PURGE
# =========================================================================== #

# A1 - Win32 programs
$keys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$allLeft = Get-ItemProperty $keys | Where-Object { $_.DisplayName } |
            Where-Object { Matches-Dell $_.DisplayName $_.Publisher } |
            Select-Object -ExpandProperty DisplayName -Unique
if ($KeepThermal) {
    $thermalLeft = @($allLeft | Where-Object { Is-ThermalKept $_ })
    $left        = @($allLeft | Where-Object { -not (Is-ThermalKept $_) })
} else {
    $thermalLeft = @()
    $left        = @($allLeft)
}
if ($left) { Add-Result 'Dell purge' 'Junk programs removed' 'FAIL' ("Still installed: " + ($left -join ', ')) 'Re-run Remove-DellAlienware.ps1' }
else       { Add-Result 'Dell purge' 'Junk programs removed' 'PASS' 'No removable Dell/Alienware junk found' }
if ($KeepThermal -and $thermalLeft) {
    Add-Result 'Dell purge' 'Fan/thermal/RGB control KEPT (Safe mode)' 'PASS' ($thermalLeft -join ', ')
}

# A2 - AppX packages
$appxLeft = Get-AppxPackage | Where-Object { Matches-Dell $_.Name $_.Publisher } |
                Select-Object -ExpandProperty Name -Unique
if ($appxLeft) { Add-Result 'Dell purge' 'Store apps removed' 'FAIL' ("Still present: " + ($appxLeft -join ', ')) 'Re-run Remove-DellAlienware.ps1' }
else           { Add-Result 'Dell purge' 'Store apps removed' 'PASS' 'No Dell/Alienware Store apps found' }

# A3 - Running processes
$procLeft = Get-Process | Where-Object {
    $_.ProcessName -match 'Dell|Alienware|SupportAssist|AlienFX' } |
    Select-Object -ExpandProperty ProcessName -Unique
if ($procLeft) { Add-Result 'Dell purge' 'No Dell processes running' 'FAIL' ($procLeft -join ', ') 'Reboot, then re-check; if still there re-run the purge' }
else           { Add-Result 'Dell purge' 'No Dell processes running' 'PASS' 'None running' }

# A4 - Services (should be gone, or at least not running/auto)
$svc = Get-Service | Where-Object {
    ($_.DisplayName -match 'Dell|Alienware|SupportAssist') -or ($_.Name -match 'Dell|Alienware|SupportAssist|DellData') }
$svcBad = $svc | Where-Object { $_.Status -eq 'Running' -or $_.StartType -eq 'Automatic' }
if ($svcBad) { Add-Result 'Dell purge' 'Services stopped/disabled' 'FAIL' (($svcBad | ForEach-Object { "$($_.Name)[$($_.Status)/$($_.StartType)]" }) -join ', ') 'Re-run Remove-DellAlienware.ps1' }
elseif ($svc) { Add-Result 'Dell purge' 'Services stopped/disabled' 'WARN' (($svc.Name) -join ', ') 'Present but disabled - fine; will clear on reboot' }
else { Add-Result 'Dell purge' 'Services stopped/disabled' 'PASS' 'No Dell services remain' }

# A5 - Scheduled tasks
$tasks = Get-ScheduledTask | Where-Object {
    $_.TaskName -match 'Dell|Alienware|SupportAssist' -or $_.TaskPath -like '*Dell*' }
if ($tasks) { Add-Result 'Dell purge' 'Scheduled tasks removed' 'FAIL' (($tasks.TaskName) -join ', ') 'Re-run Remove-DellAlienware.ps1' }
else        { Add-Result 'Dell purge' 'Scheduled tasks removed' 'PASS' 'None found' }

# A6 - Leftover folders
$folders = @(
    "$env:ProgramFiles\Dell","$env:ProgramFiles\Alienware",
    "${env:ProgramFiles(x86)}\Dell","${env:ProgramFiles(x86)}\Alienware",
    "$env:ProgramData\Dell","$env:ProgramData\Alienware",
    "$env:LOCALAPPDATA\Dell","$env:LOCALAPPDATA\Alienware"
) | Where-Object { Test-Path $_ }
if ($folders) { Add-Result 'Dell purge' 'Leftover folders deleted' 'WARN' ($folders -join '; ') 'Often locked until reboot - reboot then re-check' }
else          { Add-Result 'Dell purge' 'Leftover folders deleted' 'PASS' 'None remain' }

# A7 - Registry keys
$regs = @('HKLM:\SOFTWARE\Dell','HKLM:\SOFTWARE\Alienware',
          'HKLM:\SOFTWARE\WOW6432Node\Dell','HKLM:\SOFTWARE\WOW6432Node\Alienware') |
        Where-Object { Test-Path $_ }
if ($regs) { Add-Result 'Dell purge' 'Registry keys deleted' 'WARN' ($regs -join '; ') 'Re-run purge (need Admin) or ignore if empty' }
else       { Add-Result 'Dell purge' 'Registry keys deleted' 'PASS' 'None remain' }

# =========================================================================== #
# [B] EDGE TUNE-UP
# =========================================================================== #
$edgePol = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'

$sb = (Get-ItemProperty $edgePol -Name 'StartupBoostEnabled').StartupBoostEnabled
if ($sb -eq 0) { Add-Result 'Edge' 'Startup Boost disabled' 'PASS' 'StartupBoostEnabled = 0' }
else           { Add-Result 'Edge' 'Startup Boost disabled' 'FAIL' "Value = '$sb'" 'Run Tune-Up-Edge.ps1' }

$bg = (Get-ItemProperty $edgePol -Name 'BackgroundModeEnabled').BackgroundModeEnabled
if ($bg -eq 0) { Add-Result 'Edge' 'Background mode disabled' 'PASS' 'BackgroundModeEnabled = 0' }
else           { Add-Result 'Edge' 'Background mode disabled' 'FAIL' "Value = '$bg'" 'Run Tune-Up-Edge.ps1' }

$runKey = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
$edgeAuto = (Get-ItemProperty $runKey).PSObject.Properties |
                Where-Object { $_.Name -like 'MicrosoftEdgeAutoLaunch*' }
if ($edgeAuto) { Add-Result 'Edge' 'Login auto-launch removed' 'FAIL' $edgeAuto.Name 'Run Tune-Up-Edge.ps1' }
else           { Add-Result 'Edge' 'Login auto-launch removed' 'PASS' 'No auto-launch entry' }

# =========================================================================== #
# [C] STARTUP TUNE-UP
# =========================================================================== #
# C1 - Discord disabled (StartupApproved first byte 0x03) OR Run value gone
$approved = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
$discFlag = (Get-ItemProperty $approved -Name 'Discord').Discord
$discRun  = (Get-ItemProperty $runKey -Name 'Discord').Discord
if ($discFlag -and $discFlag[0] -band 1) { Add-Result 'Startup' 'Discord disabled at boot' 'PASS' 'Flagged disabled' }
elseif (-not $discRun)                   { Add-Result 'Startup' 'Discord disabled at boot' 'PASS' 'No startup entry' }
elseif ($discFlag)                       { Add-Result 'Startup' 'Discord disabled at boot' 'FAIL' 'Still enabled' 'Run Tune-Up-Startup.ps1' }
else                                     { Add-Result 'Startup' 'Discord disabled at boot' 'WARN' 'Run entry present, no flag' 'Run Tune-Up-Startup.ps1' }

# C2 - Mobile devices (CrossDevice) State = 1
$cd = Get-ChildItem 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData' |
        Where-Object { $_.PSChildName -like 'MicrosoftWindows.CrossDevice*' }
if (-not $cd) {
    Add-Result 'Startup' 'Mobile devices disabled at boot' 'PASS' 'Package not present'
} else {
    $state = $null
    Get-ChildItem $cd.PSPath | ForEach-Object {
        $s = (Get-ItemProperty $_.PSPath -Name State).State
        if ($s -ne $null) { $state = $s }
    }
    if ($state -eq 1)        { Add-Result 'Startup' 'Mobile devices disabled at boot' 'PASS' 'State = 1 (disabled)' }
    elseif ($state -eq $null){ Add-Result 'Startup' 'Mobile devices disabled at boot' 'WARN' 'No startup task found' }
    else                     { Add-Result 'Startup' 'Mobile devices disabled at boot' 'FAIL' "State = $state (enabled)" 'Run Tune-Up-Startup.ps1' }
}

# =========================================================================== #
# REPORT
# =========================================================================== #
Write-Host ""
$lastArea = ''
foreach ($r in $results) {
    if ($r.Area -ne $lastArea) {
        Write-Host ""
        Write-Host ("[{0}]" -f $r.Area) -ForegroundColor Cyan
        $lastArea = $r.Area
    }
    $mark, $col = switch ($r.Status) {
        'PASS' { '[PASS]','Green' }
        'WARN' { '[WARN]','Yellow' }
        'FAIL' { '[FAIL]','Red' }
    }
    Write-Host ("  {0} {1}" -f $mark, $r.Check) -ForegroundColor $col
    if ($r.Detail) { Write-Host ("         -> {0}" -f $r.Detail) -ForegroundColor DarkGray }
    if ($r.Status -eq 'FAIL' -and $r.Fix) { Write-Host ("         FIX: {0}" -f $r.Fix) -ForegroundColor Yellow }
}

$pass = ($results | Where-Object Status -eq 'PASS').Count
$warn = ($results | Where-Object Status -eq 'WARN').Count
$fail = ($results | Where-Object Status -eq 'FAIL').Count

Write-Host ""
Write-Host "==============================================================" -ForegroundColor Cyan
Write-Host (" SUMMARY:  {0} passed   {1} warnings   {2} failed" -f $pass, $warn, $fail) -ForegroundColor White
if ($fail -eq 0 -and $warn -eq 0) {
    Write-Host " ALL CLEAR - everything completed successfully!" -ForegroundColor Green
} elseif ($fail -eq 0) {
    Write-Host " GOOD - all critical checks passed. Warnings usually clear after a reboot." -ForegroundColor Yellow
} else {
    Write-Host " SOME ITEMS INCOMPLETE - see the FIX lines above (re-run the named script)." -ForegroundColor Red
}
Write-Host "==============================================================" -ForegroundColor Cyan
