[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet("Codex", "Claude", "Both")]
    [string]$Target = "Both",

    [string]$CodexRoot = (Join-Path $env:USERPROFILE ".codex\skills"),

    [string]$ClaudeRoot = (Join-Path $env:USERPROFILE ".claude\skills"),

    [switch]$Overwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$sourceRoot = Join-Path (Split-Path -Parent $PSScriptRoot) "skills"
if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
    throw "Skill source directory does not exist: $sourceRoot"
}

$destinations = @()
if ($Target -in @("Codex", "Both")) {
    $destinations += [pscustomobject]@{ Product = "Codex"; Root = $CodexRoot }
}
if ($Target -in @("Claude", "Both")) {
    $destinations += [pscustomobject]@{ Product = "Claude"; Root = $ClaudeRoot }
}

$skillDirectories = Get-ChildItem -LiteralPath $sourceRoot -Directory | Sort-Object Name
foreach ($destination in $destinations) {
    if ($PSCmdlet.ShouldProcess($destination.Root, "Create skill root for $($destination.Product)")) {
        New-Item -ItemType Directory -Path $destination.Root -Force | Out-Null
    }

    foreach ($skillDirectory in $skillDirectories) {
        $targetDirectory = Join-Path $destination.Root $skillDirectory.Name
        if ((Test-Path -LiteralPath $targetDirectory) -and -not $Overwrite) {
            Write-Warning "Skipping existing skill '$($skillDirectory.Name)' in $($destination.Product). Use -Overwrite to merge updates."
            continue
        }

        if ($PSCmdlet.ShouldProcess($targetDirectory, "Install $($skillDirectory.Name) for $($destination.Product)")) {
            Copy-Item -LiteralPath $skillDirectory.FullName -Destination $destination.Root -Recurse -Force
            Write-Output "Installed $($skillDirectory.Name) for $($destination.Product): $targetDirectory"
        }
    }
}
