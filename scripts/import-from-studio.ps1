<#
.SYNOPSIS
    Pulls the safely mapped scripts from a saved Roblox place file into src/.

.DESCRIPTION
    Read-only for the place file and Studio. It writes repository files covered by
    default.project.json. GUI, Workspace, and ServerStorage snapshots are separate.

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

if ($DryRun) {
    rojo syncback default.project.json --input $Place --dry-run --list
} else {
    rojo syncback default.project.json --input $Place --non-interactive --list
    Write-Host ""
    Write-Host "Done. Review with 'git status' and 'git diff' before committing." -ForegroundColor Green
    Write-Host "Review every changed file before committing or connecting Studio." -ForegroundColor Yellow
}
