# Contributing

Thanks for your interest! This project aims to be a **safe, transparent** debloat toolkit for Dell/Alienware Windows machines.

## Ways to help

- **New OEM app names / patterns.** If your Dell/Alienware model ships software this doesn't catch, open an issue with the program's **DisplayName** and **Publisher** (from `Get-ItemProperty` on the uninstall keys) and we'll add it.
- **Windows build quirks.** Different Windows 10/11 builds store startup tasks differently — reports welcome.
- **Bug reports.** Include your Windows version (`winver`), the script you ran, and the relevant log file (scrub anything personal).

## Ground rules for PRs

1. **Safety first.** Never add drivers, runtimes (.NET, VC++), or core Windows components to a removal list. Add them to the *protected* list if there's any doubt.
2. **Keep it reversible.** Prefer disabling over deleting; keep `-DryRun` and `-Undo` working.
3. **ASCII only.** Windows PowerShell 5.1 is picky about encoding — no smart quotes or em-dashes in `.ps1` files. Save as UTF-8 (BOM is fine).
4. **Test with `-DryRun` first** and paste the output in your PR.
5. **Match the existing style:** the `Log` helper, section banners, and progress bars.

## Testing checklist

- [ ] Script parses: `[System.Management.Automation.Language.Parser]::ParseFile(...)`
- [ ] `-DryRun` changes nothing
- [ ] Protected drivers/runtimes are not matched
- [ ] `Verify-Cleanup.ps1` reflects the change
