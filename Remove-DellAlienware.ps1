<#
================================================================================
 Remove-DellAlienware.ps1
 Purge ALL Dell + Alienware software from a Windows 10/11 PC.

 Works on ANY Dell/Alienware machine: it detects programs by PUBLISHER
 (Dell / Alienware) plus known name patterns, so it finds them no matter
 what the exact product name is on your model.

 ORDER OF OPERATIONS (this matters - Dell software re-installs itself):
   1. Detect Windows version + list everything that will be removed.
   2. Create a System Restore point (your undo button).
   3. Stop + DISABLE Dell/Alienware services and scheduled tasks
      (these are the re-installers; kill them first or the apps come back).
   4. Uninstall the Store (AppX) apps.
   5. Uninstall the desktop (Win32) programs, silently.
   6. Delete leftover Dell/Alienware folders and registry keys.

 HOW TO RUN  (must be Administrator)
   Right-click Start -> "Terminal (Admin)", then:

     cd "$env:USERPROFILE\Downloads\windows-dell-alienware-debloater"

   Preview only, change nothing (ALWAYS do this first):
     powershell -ExecutionPolicy Bypass -File ".\Remove-DellAlienware.ps1" -DryRun

   Do it for real:
     powershell -ExecutionPolicy Bypass -File ".\Remove-DellAlienware.ps1"

 SWITCHES
   -DryRun        Show what would happen, change nothing.
   -KeepThermal   Keep Alienware Command Center / XTU / Performance plugin
                  (fan & performance control) and remove everything else.
   -SkipRestore   Skip the restore point (not recommended).
   -NoPurge       Uninstall apps but DON'T delete leftover folders/registry.
================================================================================
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$KeepThermal,
    [switch]$SkipRestore,
    [switch]$NoPurge
)

$ErrorActionPreference = 'Continue'
$logFile = Join-Path $PSScriptRoot ("DellAlienware-log-{0:yyyyMMdd-HHmmss}.txt" -f (Get-Date))

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
Log " Dell + Alienware Purge" Cyan
Log " Log file: $logFile" Cyan
if ($DryRun)      { Log " *** DRY RUN - nothing will be changed ***" Yellow }
if ($KeepThermal) { Log " Mode: keeping fan/thermal control (Command Center)." Yellow }
Log "==============================================================" Cyan

if (-not (Test-Admin)) {
    Log "ERROR: Run this as Administrator." Red
    Log "Right-click Start -> 'Terminal (Admin)' and run it again." Red
    return
}

# --------------------------------------------------------------------------- #
# 1. Windows version
# --------------------------------------------------------------------------- #
$os  = Get-CimInstance Win32_OperatingSystem
$cv  = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$ver = if ($cv.DisplayVersion) { $cv.DisplayVersion } else { $cv.ReleaseId }
Log ""
Log "Detected OS : $($os.Caption)" White
Log "Version     : $ver  (build $($cv.CurrentBuild).$($cv.UBR))" White
Log "Architecture: $($os.OSArchitecture)" White
if ($os.Caption -notlike '*Windows 1*') {
    Log "WARNING: This doesn't look like Windows 10/11. Proceeding anyway." Yellow
}

# --------------------------------------------------------------------------- #
# 2. What counts as Dell/Alienware
# --------------------------------------------------------------------------- #
# Primary detection = publisher. Name patterns are a safety net for items
# whose publisher field is blank or odd.
$PublisherPatterns = @('Dell','Alienware')
$NamePatterns = @(
    'Dell','Alienware','AWCC','AlienFX','AWIO','Alienware Command Center',
    'SupportAssist','Digital Delivery','Dell Optimizer','Dell Update',
    'Dell Command','My Dell','MyDell','Dell Power Manager','Dell Display Manager',
    'Dell Peripheral Manager','Dell Mobile Connect','Dell Data Vault','DellDataVault',
    'Dell TechHub','Dell Foundation Services','Dell Customer Connect','Dell Watchdog',
    'Dell Core Services','Dell Connected Service','Power Media Player for Dell',
    'GameLibrary','Performance Plugin','XtuInstaller','XTU','CoreInstaller',
    'FXCore','FXDevice','FXELC','FX Display','FXInstaller'
)
# Things to KEEP when -KeepThermal is used (fan/perf control + RGB lighting).
$ThermalKeep = @(
    'Command Center','AWCC','XTU','Xtu','Performance Plugin','AWIO',
    'CoreInstaller','FXCore','FXDevice','FXELC','FX Display','FXInstaller','AlienFX'
)
# NEVER touch these even if a name happens to match (real drivers, not Dell apps).
$HardProtect = @('NVIDIA','Intel(R)','Realtek','Killer','Waves MaxxAudio')

function Matches-Dell {
    param([string]$Name, [string]$Publisher)
    if (-not $Name) { return $false }
    foreach ($h in $HardProtect) { if ($Name -like "*$h*") { return $false } }
    foreach ($p in $PublisherPatterns) { if ($Publisher -like "*$p*") { return $true } }
    foreach ($n in $NamePatterns)      { if ($Name      -like "*$n*") { return $true } }
    return $false
}
function Is-ThermalKept {
    param([string]$Name)
    if (-not $KeepThermal) { return $false }
    foreach ($t in $ThermalKeep) { if ($Name -like "*$t*") { return $true } }
    return $false
}

# --------------------------------------------------------------------------- #
# 3. Gather targets (Win32 + AppX)
# --------------------------------------------------------------------------- #
$uninstallKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
$win32 = Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName } |
            Where-Object { Matches-Dell $_.DisplayName $_.Publisher } |
            Sort-Object DisplayName -Unique

$appx = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
            Where-Object { Matches-Dell $_.Name $_.Publisher }

Log ""
Log "----- FOUND: desktop programs (Win32) -----" Cyan
if ($win32) { $win32 | ForEach-Object {
        $tag = if (Is-ThermalKept $_.DisplayName) { " [KEEP - thermal]" } else { "" }
        Log ("  - {0}  ({1}){2}" -f $_.DisplayName, $_.Publisher, $tag) White }
} else { Log "  (none found)" DarkGray }

Log ""
Log "----- FOUND: Store apps (AppX) -----" Cyan
if ($appx) { $appx | ForEach-Object {
        $tag = if (Is-ThermalKept $_.Name) { " [KEEP - thermal]" } else { "" }
        Log ("  - {0}{1}" -f $_.Name, $tag) White } | Out-Null
    $appx | Select-Object -ExpandProperty Name -Unique | Sort-Object | ForEach-Object { } | Out-Null
} else { Log "  (none found)" DarkGray }

if (-not $win32 -and -not $appx) {
    Log ""
    Log "Nothing Dell/Alienware found. You're already clean!" Green
    return
}

# --------------------------------------------------------------------------- #
# 3b. SCAN: estimate how much RAM removing these will free
# --------------------------------------------------------------------------- #
Log ""
Log "----- Scanning live RAM use of Dell/Alienware processes -----" Cyan
$dap = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -match 'Dell|Alienware|SupportAssist|AlienFX|TechHub|DellData' }
$freeBytes = 0; $keepBytes = 0
foreach ($pr in ($dap | Sort-Object WorkingSet64 -Descending)) {
    $mb  = [math]::Round($pr.WorkingSet64 / 1MB, 0)
    if (Is-ThermalKept $pr.ProcessName) {
        $keepBytes += $pr.WorkingSet64
        Log ("  - {0,-32} {1,6} MB  [KEEP - thermal/RGB]" -f $pr.ProcessName, $mb) DarkGray
    } else {
        $freeBytes += $pr.WorkingSet64
        Log ("  - {0,-32} {1,6} MB" -f $pr.ProcessName, $mb) White
    }
}
$freeMB = [math]::Round($freeBytes / 1MB, 0)
$keepMB = [math]::Round($keepBytes / 1MB, 0)
Log ""
Log (">>> ESTIMATED RAM TO BE FREED: ~{0} MB (~{1} GB)" -f $freeMB, [math]::Round($freeMB/1024,2)) Green
if ($keepMB -gt 0) {
    Log ("    Keeping ~{0} MB of fan/thermal/RGB processes (Safe mode)." -f $keepMB) Yellow
}
if ($freeMB -eq 0) { Log "    (No matching processes running right now - savings come after removal.)" DarkGray }

if ($DryRun) {
    Log ""
    Log "DRY RUN complete. Re-run without -DryRun to remove the above." Yellow
    Log "Plus: it would stop/disable Dell services + scheduled tasks and" Yellow
    Log "delete leftover Dell/Alienware folders and registry keys." Yellow
    return
}

# --------------------------------------------------------------------------- #
# 4. Restore point
# --------------------------------------------------------------------------- #
if (-not $SkipRestore) {
    Log ""
    Log "Creating a System Restore point..." Cyan
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" `
            -Name "SystemRestorePointCreationFrequency" -Value 0 -PropertyType DWord -Force | Out-Null
        Checkpoint-Computer -Description "Before Dell/Alienware purge" -RestorePointType "MODIFY_SETTINGS"
        Log "Restore point created." Green
    } catch {
        Log "WARNING: couldn't create restore point: $($_.Exception.Message)" Yellow
        $a = Read-Host "Continue without one? (y/N)"
        if ($a -ne 'y') { Log "Aborted." Yellow; return }
    }
}

# --------------------------------------------------------------------------- #
# 5. Stop + disable Dell/Alienware services and scheduled tasks (re-installers)
# --------------------------------------------------------------------------- #
Log ""
Log "----- Stopping + disabling Dell/Alienware services -----" Cyan
$svcs = Get-Service -ErrorAction SilentlyContinue | Where-Object {
    (Matches-Dell $_.DisplayName $null) -or (Matches-Dell $_.Name $null) -or
    $_.Name -like '*SupportAssist*' -or $_.Name -like '*DellData*' -or
    $_.DisplayName -like '*SupportAssist*'
}
$i = 0; $total = @($svcs).Count
foreach ($s in $svcs) {
    $i++
    Write-Progress -Id 1 -Activity "Disabling Dell/Alienware services" `
        -Status "$i of $total : $($s.DisplayName)" -PercentComplete (($i / [math]::Max($total,1)) * 100)
    if ((Is-ThermalKept $s.DisplayName) -or (Is-ThermalKept $s.Name)) {
        Log "  [keep] $($s.DisplayName)" DarkGray; continue }
    try {
        Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
        Set-Service  -Name $s.Name -StartupType Disabled -ErrorAction SilentlyContinue
        Log "  [disabled] $($s.DisplayName)" Green
    } catch { Log "  [svc failed] $($s.DisplayName): $($_.Exception.Message)" Red }
}
Write-Progress -Id 1 -Activity "Disabling Dell/Alienware services" -Completed

Log ""
Log "----- Removing Dell/Alienware scheduled tasks -----" Cyan
try {
    Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $_.TaskName -like '*Dell*' -or $_.TaskName -like '*Alienware*' -or
        $_.TaskName -like '*SupportAssist*' -or $_.TaskPath -like '*Dell*'
    } | ForEach-Object {
        if (Is-ThermalKept $_.TaskName) { return }
        try {
            Unregister-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -Confirm:$false -ErrorAction Stop
            Log "  [removed task] $($_.TaskPath)$($_.TaskName)" Green
        } catch { Log "  [task failed] $($_.TaskName): $($_.Exception.Message)" Red }
    }
} catch { Log "  (could not enumerate scheduled tasks)" Yellow }

# --------------------------------------------------------------------------- #
# 6. Uninstall AppX
# --------------------------------------------------------------------------- #
Log ""
Log "----- Removing Store (AppX) apps -----" Cyan
$i = 0; $total = @($appx).Count
foreach ($p in $appx) {
    $i++
    Write-Progress -Id 1 -Activity "Removing Dell/Alienware Store apps" `
        -Status "$i of $total : $($p.Name)" -PercentComplete (($i / [math]::Max($total,1)) * 100)
    if (Is-ThermalKept $p.Name) { Log "  [keep] $($p.Name)" DarkGray; continue }
    try {
        Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
        Log "  [removed] $($p.Name)" Green
    } catch { Log "  [failed]  $($p.Name): $($_.Exception.Message)" Red }
}
Write-Progress -Id 1 -Activity "Removing Dell/Alienware Store apps" -Completed
# Provisioned (stops them returning for new users)
Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object {
    Matches-Dell $_.DisplayName $_.PublisherId
} | ForEach-Object {
    if (Is-ThermalKept $_.DisplayName) { return }
    try {
        Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -ErrorAction Stop | Out-Null
        Log "  [removed-provisioned] $($_.DisplayName)" Green
    } catch { Log "  [failed-provisioned] $($_.DisplayName)" Red }
}

# --------------------------------------------------------------------------- #
# 7. Uninstall Win32 programs
# --------------------------------------------------------------------------- #
Log ""
Log "----- Removing desktop (Win32) programs -----" Cyan
$i = 0; $total = @($win32).Count
foreach ($app in $win32) {
    $i++
    Write-Progress -Id 1 -Activity "Uninstalling Dell/Alienware programs" `
        -Status "$i of $total : $($app.DisplayName)" -PercentComplete (($i / [math]::Max($total,1)) * 100)
    if (Is-ThermalKept $app.DisplayName) { Log "  [keep] $($app.DisplayName)" DarkGray; continue }

    $cmd = $app.QuietUninstallString
    if (-not $cmd) { $cmd = $app.UninstallString }
    if (-not $cmd) { Log "  [no uninstaller] $($app.DisplayName)" Yellow; continue }

    try {
        if ($cmd -match 'msiexec') {
            $guid = ([regex]'\{[0-9A-Fa-f\-]+\}').Match($cmd).Value
            if ($guid) {
                Start-Process msiexec.exe -ArgumentList "/x $guid /qn /norestart" -Wait -NoNewWindow
            } else {
                Start-Process cmd.exe -ArgumentList "/c $cmd /qn /norestart" -Wait -NoNewWindow
            }
        } else {
            # Try several silent switches Dell uninstallers understand.
            $exe = $cmd; $args = ''
            if ($cmd -match '^\s*"([^"]+)"\s*(.*)$') { $exe = $matches[1]; $args = $matches[2] }
            elseif ($cmd -match '^\s*(\S+)\s*(.*)$')  { $exe = $matches[1]; $args = $matches[2] }
            $silent = if ($args) { "$args /S /silent /quiet /arp" } else { "/S /silent /quiet /arp" }
            Start-Process -FilePath $exe -ArgumentList $silent -Wait -NoNewWindow -ErrorAction Stop
        }
        Log "  [removed] $($app.DisplayName)" Green
    } catch {
        Log "  [failed]  $($app.DisplayName): $($_.Exception.Message)" Red
    }
}
Write-Progress -Id 1 -Activity "Uninstalling Dell/Alienware programs" -Completed

# --------------------------------------------------------------------------- #
# 8. Delete leftover folders + registry keys
# --------------------------------------------------------------------------- #
if (-not $NoPurge) {
    Log ""
    Log "----- Deleting leftover folders + registry keys -----" Cyan
    $folders = @(
        "$env:ProgramFiles\Dell","$env:ProgramFiles\Alienware",
        "${env:ProgramFiles(x86)}\Dell","${env:ProgramFiles(x86)}\Alienware",
        "$env:ProgramData\Dell","$env:ProgramData\Alienware",
        "$env:LOCALAPPDATA\Dell","$env:LOCALAPPDATA\Alienware"
    )
    if ($KeepThermal) {
        # Don't nuke the whole Dell/Alienware tree if keeping Command Center.
        Log "  [skip folder wipe - KeepThermal mode]" DarkGray
    } else {
        foreach ($f in $folders) {
            if (Test-Path $f) {
                try { Remove-Item $f -Recurse -Force -ErrorAction Stop; Log "  [deleted] $f" Green }
                catch { Log "  [locked]  $f (some files in use; delete after reboot)" Yellow }
            }
        }
        $regKeys = @(
            'HKLM:\SOFTWARE\Dell','HKLM:\SOFTWARE\Alienware',
            'HKLM:\SOFTWARE\WOW6432Node\Dell','HKLM:\SOFTWARE\WOW6432Node\Alienware'
        )
        foreach ($k in $regKeys) {
            if (Test-Path $k) {
                try { Remove-Item $k -Recurse -Force -ErrorAction Stop; Log "  [deleted] $k" Green }
                catch { Log "  [reg locked] $k" Yellow }
            }
        }
    }
}

# --------------------------------------------------------------------------- #
# 9. Manifest of what was removed (so it can be added back later)
# --------------------------------------------------------------------------- #
# What we intended to remove (excludes anything kept in Safe mode):
$plannedWin32 = @($win32 | Where-Object { -not (Is-ThermalKept $_.DisplayName) } | Select-Object -ExpandProperty DisplayName)
$plannedAppx  = @($appx  | Where-Object { -not (Is-ThermalKept $_.Name) }        | Select-Object -ExpandProperty Name -Unique)

# Re-scan to confirm what is actually gone now:
$nowWin32 = Get-ItemProperty $uninstallKeys -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName } | Select-Object -ExpandProperty DisplayName
$nowAppx  = Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
$removedNow = @()
$removedNow += @($plannedWin32 | Where-Object { $_ -notin $nowWin32 })
$removedNow += @($plannedAppx  | Where-Object { $_ -notin $nowAppx })

# Did anything performance/thermal-related get removed? (only possible if -KeepThermal was OFF)
$perfPatterns = @('Command Center','AWCC','XTU','Performance Plugin','AlienFX',
                  'FXCore','FXDevice','FXELC','FX Display','CoreInstaller','AWIO')
$perfRemoved = @($removedNow | Where-Object { $n = $_; @($perfPatterns | Where-Object { $n -like "*$_*" }).Count -gt 0 })

# Save a manifest the menu's Restore option can read.
$manifest = [pscustomobject]@{
    When                    = (Get-Date).ToString('s')
    KeepThermal             = [bool]$KeepThermal
    RestorePoint            = 'Before Dell/Alienware purge'
    EstimatedRamFreedMB     = $freeMB
    RemovedItems            = $removedNow
    PerformanceItemsRemoved = $perfRemoved
}
try { $manifest | ConvertTo-Json -Depth 4 | Set-Content -Path (Join-Path $PSScriptRoot 'last-removal.json') -Encoding UTF8 } catch {}

# --------------------------------------------------------------------------- #
# 10. Done + offer to add performance software back if needed
# --------------------------------------------------------------------------- #
Log ""
Log "==============================================================" Cyan
Log " Done. RESTART recommended to finish removing in-use files." Green
Log (" Removed {0} item(s); ~{1} MB of RAM should free up after reboot." -f $removedNow.Count, $freeMB) Green
Log " Log saved to: $logFile" Cyan
Log "==============================================================" Cyan

if ($perfRemoved.Count -gt 0) {
    Log ""
    Log "NOTICE: performance/thermal-related software was removed:" Yellow
    foreach ($x in $perfRemoved) { Log "    - $x" Yellow }
    Log "If your fans or performance modes behave differently, you can put it back." Yellow
    $ans = Read-Host "Open System Restore NOW to add it back? (y/N)"
    if ($ans -eq 'y') {
        Log "Launching System Restore - pick 'Before Dell/Alienware purge'." Cyan
        Start-Process rstrui.exe
    } else {
        Log "OK. You can add it back any time (menu option R, or run System Restore)." DarkGray
    }
} else {
    Log ""
    Log "All fan/thermal/performance software was preserved (Safe mode)." Green
}
