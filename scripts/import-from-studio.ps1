<#
.SYNOPSIS
    Pulls scripts/instances from a saved Roblox place file into src/ using `rojo syncback`.

.DESCRIPTION
    Read-only for the place file: it never modifies the .rbxl you pass in, and it never
    touches Roblox Studio. It only writes files under src/ in this repository.

    GUIs, models and other non-script instances are written as .rbxmx (XML text) instead
    of binary .rbxm, so they can be diffed and scripts nested inside them stay readable.

.EXAMPLE
    .\scripts\import-from-studio.ps1 -Place "C:\RobloxBackups\MyGame.rbxl"
    .\scripts\import-from-studio.ps1 -Place "C:\RobloxBackups\MyGame.rbxl" -DryRun
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Place,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Test-Path $Place)) {
    throw "Place file not found: $Place"
}

if (-not $DryRun) {
    $dirty = git status --porcelain
    if ($dirty) {
        throw "Git working tree has uncommitted changes. Commit or stash them first so the import can be reviewed/undone with git."
    }
}

# Write non-script instances as XML (.rbxmx) rather than binary (.rbxm).
$env:ROJO_SYNCBACK_DEBUG = "1"

if ($DryRun) {
    rojo syncback default.project.json --input $Place --dry-run --list
} else {
    rojo syncback default.project.json --input $Place --non-interactive --list
    Write-Host ""
    Write-Host "Done. Review with 'git status' and 'git diff' before committing." -ForegroundColor Green
    Write-Host "To undo everything this import wrote: git restore . ; git clean -fd src" -ForegroundColor Yellow
}
