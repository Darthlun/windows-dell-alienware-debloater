# windows-dell-alienware-debloater

A safe, reversible PowerShell toolkit to **debloat a Dell / Alienware Windows 10/11 PC** — remove the OEM nagware and telemetry that ships preinstalled, stop background RAM hogs, and trim startup apps, **without touching your drivers, runtimes, or fan/thermal control**.

Built for new Alienware laptops that feel sluggish out of the box because of preinstalled junk — but it works on any Dell machine, and most of it works on any Windows 10/11 PC.

![Platform](https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-0078D6)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE)
![License](https://img.shields.io/badge/license-MIT-green)

---

## ⚠️ Read this first

- These scripts **uninstall software and change system settings**. They are designed to be safe and reversible, but **you run them at your own risk**.
- The main removal script **creates a System Restore point first** so you can roll back.
- **Always run with `-DryRun` (or the menu's Dry-Run mode) the first time** to preview exactly what will happen.
- Removing **Alienware Command Center** also removes your **fan-curve / performance-mode control** — so the toolkit runs in **Safe Mode by default**, which *keeps* all fan/thermal/RGB software and removes only the junk.

---

## ✨ What it does

| Area | What happens | Reversible? |
|---|---|---|
| **Dell/Alienware bloat** | Uninstalls SupportAssist, Dell Update/Optimizer, Digital Delivery, AlienwareArena, GameLibrary, telemetry services, etc. Detects them by **publisher**, so it works on any Dell model. | System Restore |
| **Edge background hogging** | Disables Startup Boost + "run in background when closed" + login auto-launch. **Doesn't uninstall Edge.** | `-Undo` |
| **Startup apps** | Disables unneeded auto-start apps (e.g. Discord, "Mobile devices"). | `-Undo` |
| **Windows Store junk** *(optional)* | Removes Bing News/Weather, Solitaire, Office Hub, Clipchamp, etc. Asks about borderline apps. | System Restore |

It **never** removes: GPU/audio/chipset **drivers** (NVIDIA, Intel, Realtek), **runtimes** (.NET, VC++), Office/OneDrive, your dev tools, or — in Safe Mode — **fan/thermal/RGB control**.

---

## 🧱 Safety by design

- 🔵 **Safe Mode (default):** fan/thermal/performance/RGB software (Command Center, XTU, Performance Plugin, FX/AlienFX) is **never removed**.
- 🟢 **System Restore point** created automatically before any uninstall.
- 👀 **Dry-Run mode** previews every change without applying it.
- 🛡️ **Protected list:** drivers and runtimes are hard-excluded even if a name pattern matches.
- ✅ **Verifier** reports PASS/FAIL for everything that was supposed to change.
- ↩️ **Restore helper** to add software back (System Restore, or best-effort reinstall) if you ever need it.
- 🧾 **Logging:** every run writes a timestamped log file.

---

## 📦 Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 (built in) or PowerShell 7+
- Administrator rights (the launcher self-elevates)

---

## 🚀 Quick start

1. **Download** this repo (green **Code** button → **Download ZIP**) and extract it, **or** clone it:
   ```powershell
   git clone https://github.com/<your-username>/windows-dell-alienware-debloater.git
   ```
2. Open the folder, **right-click `START-HERE.ps1` → "Run with PowerShell."**
3. Approve the **Administrator** prompt (it re-launches itself elevated).
4. In the menu, press **`D`** to turn on **Dry-Run**, then **`6`** to preview the recommended sequence safely. Happy with it? Press **`D`** again, then **`6`** to apply.
5. **Reboot**, then run the menu again and press **`5`** to verify.

> If Windows blocks the script, you can always run any file with:
> ```powershell
> powershell -ExecutionPolicy Bypass -File ".\START-HERE.ps1"
> ```

---

## 🗂️ The scripts

| Script | Purpose |
|---|---|
| **`START-HERE.ps1`** | Menu launcher. Auto-elevates, runs any script, has Dry-Run + Safe-Mode toggles. **Start here.** |
| **`Remove-DellAlienware.ps1`** | Removes all Dell/Alienware software (publisher-based detection). Scans live RAM use and estimates savings first; disables the re-installer services so it doesn't come back. |
| **`Tune-Up-Edge.ps1`** | Stops Microsoft Edge running in the background. Reversible with `-Undo`. |
| **`Tune-Up-Startup.ps1`** | Disables unneeded startup apps. Reversible with `-Undo`. |
| **`Debloat-Alienware.ps1`** | Optional: removes generic Windows Store bloat (Bing apps, Solitaire, etc.) and asks about borderline ones. |
| **`Verify-Cleanup.ps1`** | Read-only PASS/FAIL report that the other scripts did their job. |
| **`Restore-Removed.ps1`** | Add software back via System Restore or best-effort reinstall. |

---

## 🔧 Usage & switches

Every script can be run directly. Examples:

```powershell
# Preview the Dell/Alienware removal without changing anything
powershell -ExecutionPolicy Bypass -File ".\Remove-DellAlienware.ps1" -DryRun

# Remove Dell junk but KEEP fan/thermal/RGB control (this is the default behavior in the menu)
powershell -ExecutionPolicy Bypass -File ".\Remove-DellAlienware.ps1" -KeepThermal

# Undo the Edge tweaks
powershell -ExecutionPolicy Bypass -File ".\Tune-Up-Edge.ps1" -Undo

# Verify, treating kept thermal software as expected (not a failure)
powershell -ExecutionPolicy Bypass -File ".\Verify-Cleanup.ps1" -KeepThermal
```

**Common switches:**

| Switch | Scripts | Effect |
|---|---|---|
| `-DryRun` | removal/tune-up scripts | Preview only; change nothing. |
| `-KeepThermal` | `Remove-DellAlienware.ps1`, `Verify-Cleanup.ps1` | Keep (and don't flag) fan/thermal/performance/RGB software. |
| `-Undo` | `Tune-Up-Edge.ps1`, `Tune-Up-Startup.ps1` | Revert the change. |
| `-SkipRestore` | `Remove-DellAlienware.ps1` | Skip the restore point (not recommended). |
| `-NoPurge` | `Remove-DellAlienware.ps1` | Uninstall apps but leave leftover folders/registry keys. |

---

## 🧠 How it works

- **Publisher-based detection.** Instead of a brittle hardcoded list, it matches installed programs by publisher (`Dell`, `Alienware`) plus known name patterns, so it finds OEM software on *any* Dell model — then a hard-coded **protected list** excludes real drivers/runtimes.
- **Kills the re-installers first.** Dell software (Digital Delivery, SupportAssist, Update) re-installs itself. The removal script **stops and disables those services and scheduled tasks before uninstalling**, so the apps don't come back after a reboot.
- **Honest RAM estimate.** Before removing, it sums the live memory of the matching processes (excluding anything kept in Safe Mode) and shows how much you'll get back.
- **Safe registry method for startup apps.** Startup changes use the same `StartupApproved` flags Task Manager uses, and UWP `State` values — nothing destructive.

---

## ✅ Verifying & undoing

- **Verify:** run `Verify-Cleanup.ps1` (menu option `5`). Green `[PASS]` = done; yellow `[WARN]` usually clears after a reboot; red `[FAIL]` prints the script to re-run.
- **Undo a removal:** menu option `R` (`Restore-Removed.ps1`) → System Restore to the *"Before Dell/Alienware purge"* point, or best-effort reinstall.
- **Undo a tune-up:** re-run the tune-up script with `-Undo`.

---

## ❓ FAQ

**Will this hurt my gaming performance / cooling?**
No — in the default **Safe Mode** it keeps Alienware Command Center and all fan/thermal/performance control. Only turn Safe Mode off if you truly want *zero* Dell software, and even then it warns you and offers a one-click add-back.

**Does it remove my graphics drivers?**
No. NVIDIA, Intel, and Realtek drivers are on the protected list and are never touched.

**The apps came back after a reboot — why?**
That's exactly what the re-installer services do. This toolkit disables them first, so make sure you ran `Remove-DellAlienware.ps1` (not just the Windows "Add or remove programs" screen).

**Is Edge uninstalled?**
No. The Edge tune-up only stops it running in the background; it's fully reversible.

---

## 🤝 Contributing

Issues and PRs welcome — especially additional Dell/Alienware app names, other OEM patterns, or Windows 11 build quirks. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 📄 License

[MIT](LICENSE) — free to use, modify, and share. No warranty.

## 🙏 Acknowledgements

Inspired by the broader Windows debloat community.
