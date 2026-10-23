[CmdletBinding()]
param(
    [ValidateSet("Codex", "Claude", "OpenCode", "OpenCodeV2", "Antigravity")]
    [string]$RequireCommand
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$installScript = Join-Path $PSScriptRoot "install-skills.ps1"
$root = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-skills-consumer-" + [System.Guid]::NewGuid().ToString("N"))
$userHome = Join-Path $root "user"
$projectRoot = Join-Path $root "project"
New-Item -ItemType Directory -Path $userHome, $projectRoot -Force | Out-Null

function Assert-Path([string]$Path, [string]$Description) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Consumer smoke failed: $Description ('$Path')." }
}

try {
    & $installScript -Target Universal -Scope User -UserHome $userHome
    & $installScript -Target Universal -Scope Project -ProjectRoot $projectRoot

    Assert-Path (Join-Path $userHome ".agents\skills\analyze-requirement\SKILL.md") "canonical user discovery layout is missing"
    Assert-Path (Join-Path $userHome ".gemini\config\skills\analyze-requirement\SKILL.md") "Antigravity user discovery layout is missing"
    Assert-Path (Join-Path $userHome ".claude\skills\analyze-requirement\SKILL.md") "Claude Code user discovery layout is missing"
    Assert-Path (Join-Path $projectRoot ".agents\skills\analyze-requirement\SKILL.md") "canonical project discovery layout is missing"
    Assert-Path (Join-Path $projectRoot ".claude\skills\analyze-requirement\SKILL.md") "Claude Code project discovery layout is missing"

    if ($RequireCommand) {
        $executable = switch ($RequireCommand) {
            "Codex" { "codex" }
            "Claude" { "claude" }
            "OpenCode" { "opencode" }
            "OpenCodeV2" { "opencode2" }
            "Antigravity" { "agy" }
        }
        if (-not (Get-Command $executable -ErrorAction SilentlyContinue)) { throw "Required consumer command '$executable' is unavailable." }
        & $executable --version
        if ($LASTEXITCODE -ne 0) { throw "'$executable --version' failed with exit code $LASTEXITCODE." }

        if ($RequireCommand -eq "Claude") {
            # Validating a folder that holds marketplace.json checks only the marketplace, so name each file.
            $collectionRoot = Split-Path -Parent $PSScriptRoot
            foreach ($manifest in @("plugin.json", "marketplace.json")) {
                & claude plugin validate --strict (Join-Path $collectionRoot ".claude-plugin\$manifest")
                if ($LASTEXITCODE -ne 0) { throw "Claude rejected .claude-plugin/$manifest." }
            }
        }
    }

    Write-Output "Consumer smoke checks passed$(if ($RequireCommand) { " for $RequireCommand" })."
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
}
