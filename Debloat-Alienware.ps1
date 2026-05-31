<#
================================================================================
 Debloat-Alienware.ps1
 Safe, categorized debloat for a new Alienware / Dell Windows 11 laptop.

 WHAT IT DOES
   - Creates a System Restore point first (your undo button).
   - Removes well-known bloat (Bing junk, promo apps, Alienware game-promo apps).
   - ASKS you about borderline apps (Xbox, Copilot, CCleaner, SupportAssist...).
   - NEVER touches drivers, runtimes, Office, OneDrive, dev tools, or the
     Alienware thermal/fan software.

 HOW TO RUN
   1. Right-click Start  ->  "Terminal (Admin)"  (must be admin)
   2. First, preview with no changes:
          powershell -ExecutionPolicy Bypass -File ".\Debloat-Alienware.ps1" -DryRun
   3. When happy, run for real:
          powershell -ExecutionPolicy Bypass -File ".\Debloat-Alienware.ps1"

 PARAMETERS
   -DryRun        Show what would be removed, change nothing.
   -SkipRestore   Don't create a restore point (not recommended).
   -All           Remove everything recommended AND all optional items without
                  asking (still respects the protected list).
================================================================================
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$SkipRestore,
    [switch]$All
)

# --------------------------------------------------------------------------- #
#  0. Setup / safety checks
# --------------------------------------------------------------------------- #
$ErrorActionPreference = 'Continue'
$logFile = Join-Path $PSScriptRoot ("Debloat-log-{0:yyyyMMdd-HHmmss}.txt" -f (Get-Date))

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
Log " Alienware / Windows 11 Debloater" Cyan
Log " Log file: $logFile" Cyan
if ($DryRun) { Log " *** DRY RUN - nothing will actually be removed ***" Yellow }
Log "==============================================================" Cyan

if (-not (Test-Admin)) {
    Log "ERROR: This must be run as Administrator." Red
    Log "Right-click Start -> 'Terminal (Admin)' and run it again." Red
    return
}

# --------------------------------------------------------------------------- #
#  1. PROTECTED - never remove these (substring match, case-insensitive).
#     Drivers, runtimes, thermal control, dev tools, things you use.
# --------------------------------------------------------------------------- #
$Protected = @(
    'NVIDIA','Intel','Realtek','Dolby','Conexant','Killer','Waves',     # drivers/audio
    'Visual C++','.NET','WinAppRuntime','WindowsAppRuntime',            # runtimes
    'Microsoft Edge','WebView2',                                        # web runtime
    'OneDrive','Microsoft 365','OneNote','Office','Outlook (classic)',  # productivity you have
    'Git','Node.js','Visual Studio Code','VisualStudioCode',            # dev tools
    'Command Center','XTU','Xtu','Performance Plugin','AWCC','AWIO',    # Alienware THERMAL/RGB core
    'CoreInstaller','FXCore','FXDevice','FXELC','FX Display','NvCpl',
    'DesktopAppInstaller','WindowsStore','StorePurchaseApp',            # app store / winget
    'Terminal','Notepad','Calculator','ScreenSketch','SnippingTool',
    'Paint','Photos','SecHealthUI','Defender','VCLibs','UI.Xaml',
    'PokeMMO'                                                           # a game YOU installed
)

function Is-Protected {
    param([string]$Name)
    foreach ($p in $Protected) {
        if ($Name -like "*$p*") { return $true }
    }
    return $false
}

# --------------------------------------------------------------------------- #
#  2. The removal lists.
#     AppX  = Microsoft Store / built-in apps (matched by package Name)
#     Win32 = traditional desktop programs   (matched by DisplayName)
# --------------------------------------------------------------------------- #

# Tier 1: removed automatically (clear junk, safe).
$RecommendedAppx = @(
    'Microsoft.BingNews',
    'Microsoft.BingWeather',
    'Microsoft.MicrosoftSolitaireCollection',
    'Microsoft.MicrosoftOfficeHub',
    'Microsoft.Todos',
    'Microsoft.PowerAutomateDesktop',
    'Microsoft.Windows.DevHome',
    'Clipchamp.Clipchamp',
    'Microsoft.WindowsFeedbackHub',
    'Microsoft.GetHelp'
)
$RecommendedWin32 = @(
    'AlienwareArena',
    'Alienware Digital Delivery',
    'GameLibrarySetup'
)

# Tier 2: asked about one group at a time (you decide).
$OptionalGroups = [ordered]@{
    'Microsoft Copilot (AI assistant in taskbar)'          = @{ Appx = @('Microsoft.Copilot') }
    'Phone Link / Your Phone'                              = @{ Appx = @('Microsoft.YourPhone','MicrosoftWindows.CrossDevice') }
    'Media Player (Groove / Zune Music)'                   = @{ Appx = @('Microsoft.ZuneMusic') }
    'New Outlook for Windows (the Store app, not Office)'  = @{ Appx = @('Microsoft.OutlookForWindows') }
    'Bing web search in Start menu'                        = @{ Appx = @('Microsoft.BingSearch') }
    'Microsoft Family / parental controls'                 = @{ Appx = @('MicrosoftCorporationII.MicrosoftFamily') }
    'Quick Assist (remote help)'                           = @{ Appx = @('MicrosoftCorporationII.QuickAssist') }
    'Xbox app + Game Bar overlay (KEEP if you game)'       = @{ Appx = @('Microsoft.GamingApp','Microsoft.XboxGamingOverlay','Microsoft.XboxSpeechToTextOverlay','Microsoft.Xbox.TCUI') }
    'CCleaner (3rd-party "cleaner", often unneeded)'       = @{ Win32 = @('CCleaner') }
    'Dell SupportAssist + telemetry services'             = @{ Win32 = @('Dell SupportAssist','SupportAssist Remediation','Dell Connected Service','Dell Core Services','Alienware SupportAssist') }
    'intelliGo Neptune (OEM mic noise app)'               = @{ Appx = @('IntelligoTechnologyInc.intelliGoNeptune') }
}

# --------------------------------------------------------------------------- #
#  3. Restore point
# --------------------------------------------------------------------------- #
if (-not $SkipRestore -and -not $DryRun) {
    Log ""
    Log "Creating a System Restore point (this is your undo button)..." Cyan
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        # Windows rate-limits restore points to 1/24h; bypass that for this run.
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" `
            -Name "SystemRestorePointCreationFrequency" -Value 0 -PropertyType DWord -Force | Out-Null
        Checkpoint-Computer -Description "Before Debloat-Alienware" -RestorePointType "MODIFY_SETTINGS"
        Log "Restore point created. (Undo later via: Start -> 'Create a restore point' -> System Restore)" Green
    } catch {
        Log "WARNING: Could not create a restore point: $($_.Exception.Message)" Yellow
        $ans = Read-Host "Continue WITHOUT a restore point? (y/N)"
        if ($ans -ne 'y') { Log "Aborted by user." Yellow; return }
    }
}

# --------------------------------------------------------------------------- #
#  4. Removal helpers
# --------------------------------------------------------------------------- #
function Remove-AppxByName {
    param([string]$Name)
    if (Is-Protected $Name) { Log "  [SKIP protected] $Name" DarkGray; return }

    $pkgs = Get-AppxPackage -AllUsers -Name $Name -ErrorAction SilentlyContinue
    $prov = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq $Name }

    if (-not $pkgs -and -not $prov) { Log "  [not found]  $Name" DarkGray; return }

    if ($DryRun) { Log "  [WOULD remove] $Name" Yellow; return }

    foreach ($p in $pkgs) {
        try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
              Log "  [removed]    $Name" Green }
        catch { Log "  [failed]     $Name : $($_.Exception.Message)" Red }
    }
    foreach ($p in $prov) {
        try { Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null
              Log "  [removed-provisioned] $Name (won't reinstall for new users)" Green }
        catch { Log "  [failed-provisioned] $Name : $($_.Exception.Message)" Red }
    }
}

function Remove-Win32ByName {
    param([string]$DisplayMatch)
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $apps = Get-ItemProperty $keys -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -like "*$DisplayMatch*" }

    if (-not $apps) { Log "  [not found]  $DisplayMatch" DarkGray; return }

    foreach ($app in $apps) {
        if (Is-Protected $app.DisplayName) { Log "  [SKIP protected] $($app.DisplayName)" DarkGray; continue }

        if ($DryRun) { Log "  [WOULD remove] $($app.DisplayName)" Yellow; continue }

        $cmd = $app.QuietUninstallString
        if (-not $cmd) { $cmd = $app.UninstallString }
        if (-not $cmd) { Log "  [no uninstaller] $($app.DisplayName)" Yellow; continue }

        try {
            # Prefer silent MSI removal when possible.
            if ($cmd -match 'msiexec') {
                $guid = ([regex]'\{[0-9A-Fa-f\-]+\}').Match($cmd).Value
                if ($guid) {
                    Start-Process msiexec.exe -ArgumentList "/x $guid /qn /norestart" -Wait -NoNewWindow
                } else {
                    Start-Process cmd.exe -ArgumentList "/c $cmd /qn /norestart" -Wait -NoNewWindow
                }
            } else {
                # EXE uninstaller; try common silent switches.
                Start-Process cmd.exe -ArgumentList "/c `"$cmd`" /S /silent /quiet" -Wait -NoNewWindow
            }
            Log "  [removed]    $($app.DisplayName)" Green
        } catch {
            Log "  [failed]     $($app.DisplayName) : $($_.Exception.Message)" Red
        }
    }
}

# --------------------------------------------------------------------------- #
#  5. Run Tier 1 (recommended)
# --------------------------------------------------------------------------- #
Log ""
Log "----- Removing recommended bloat (Store apps) -----" Cyan
foreach ($a in $RecommendedAppx) { Remove-AppxByName $a }

Log ""
Log "----- Removing recommended bloat (desktop apps) -----" Cyan
foreach ($w in $RecommendedWin32) { Remove-Win32ByName $w }

# --------------------------------------------------------------------------- #
#  6. Run Tier 2 (optional - ask)
# --------------------------------------------------------------------------- #
Log ""
Log "----- Optional items (your call) -----" Cyan
foreach ($group in $OptionalGroups.Keys) {
    $remove = $All
    if (-not $All) {
        $ans = Read-Host "Remove: $group ? (y/N)"
        $remove = ($ans -eq 'y')
    }
    if (-not $remove) { Log "  [kept]       $group" DarkGray; continue }

    Log "  -> $group" White
    $def = $OptionalGroups[$group]
    if ($def.Appx)  { foreach ($a in $def.Appx)  { Remove-AppxByName $a } }
    if ($def.Win32) { foreach ($w in $def.Win32) { Remove-Win32ByName $w } }
}

# --------------------------------------------------------------------------- #
#  7. Light, safe tidy-up (no registry hacks, all reversible)
# --------------------------------------------------------------------------- #
if (-not $DryRun) {
    Log ""
    Log "----- Quick tidy-up -----" Cyan
    try {
        # Clear the temp folder (safe; Windows recreates anything needed).
        Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Log "  [done] Cleared temp files." Green
    } catch { }
}

# --------------------------------------------------------------------------- #
#  8. Done
# --------------------------------------------------------------------------- #
Log ""
Log "==============================================================" Cyan
if ($DryRun) {
    Log " DRY RUN complete. Nothing was changed." Yellow
    Log " Re-run without -DryRun to actually remove the items above." Yellow
} else {
    Log " Done! A restart is recommended." Green
    Log " To undo everything: Start -> 'Create a restore point'" Green
    Log "        -> System Restore -> pick 'Before Debloat-Alienware'." Green
}
Log " Full log saved to: $logFile" Cyan
Log "==============================================================" Cyan
