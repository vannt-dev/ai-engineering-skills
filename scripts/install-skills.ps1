[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet("Codex", "Claude", "OpenCode", "Antigravity", "Universal")]
    [string]$Target = "Universal",

    [ValidateSet("User", "Project")]
    [string]$Scope = "User",

    [string]$ProjectRoot,

    [string]$UserHome,

    [switch]$Overwrite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$collectionRoot = Split-Path -Parent $PSScriptRoot
$validatorScript = Join-Path $PSScriptRoot "validate-skills.ps1"
$manifestPath = Join-Path $collectionRoot "skillset.json"
$skillsSourceRoot = Join-Path $collectionRoot "skills"
$claudeManifestSource = Join-Path $collectionRoot ".claude-plugin\plugin.json"

# 1. Run validator first
if (-not (Test-Path -LiteralPath $validatorScript -PathType Leaf)) {
    throw "Validator script not found: $validatorScript"
}
& $validatorScript
if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Validation failed with exit code $LASTEXITCODE. Aborting installation."
}

# 2. Read manifest
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "skillset.json not found: $manifestPath"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$skillNames = @($manifest.skills | ForEach-Object { $_.name })

# 3. Resolve Scope roots
$resolvedUserHome = if ($UserHome) {
    [System.IO.Path]::GetFullPath($UserHome)
} elseif ($env:USERPROFILE) {
    [System.IO.Path]::GetFullPath($env:USERPROFILE)
} elseif ($env:HOME) {
    [System.IO.Path]::GetFullPath($env:HOME)
} else {
    throw "Could not determine User home directory. Specify -UserHome."
}

$resolvedProjectRoot = $null
if ($Scope -eq "Project") {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        throw "ProjectRoot is required when Scope is 'Project'."
    }
    if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
        throw "ProjectRoot directory does not exist: $ProjectRoot"
    }
    $resolvedProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}

# 4. Plan destinations
# Types:
# - 'CanonicalFlat': Destination contains <dest>/<skill-name>
# - 'ClaudeNestedPlugin': Destination is <dest>/ai-engineering-skills
$plannedDestinations = [System.Collections.Generic.List[hashtable]]::new()

if ($Scope -eq "User") {
    switch ($Target) {
        "Codex" {
            $plannedDestinations.Add(@{
                Type = "CanonicalFlat"
                Path = (Join-Path $resolvedUserHome ".agents\skills")
                Description = "Codex User skills"
            })
        }
        "Claude" {
            $plannedDestinations.Add(@{
                Type = "ClaudeNestedPlugin"
                Path = (Join-Path $resolvedUserHome ".claude\skills\ai-engineering-skills")
                Description = "Claude Code User plugin"
            })
        }
        "OpenCode" {
            $plannedDestinations.Add(@{
                Type = "CanonicalFlat"
                Path = (Join-Path $resolvedUserHome ".config\opencode\skills")
                Description = "OpenCode User skills"
            })
        }
        "Antigravity" {
            $plannedDestinations.Add(@{
                Type = "CanonicalFlat"
                Path = (Join-Path $resolvedUserHome ".gemini\antigravity\skills")
                Description = "Antigravity User skills"
            })
        }
        "Universal" {
            # Canonical .agents/skills (Codex, OpenCode, Antigravity project)
            $plannedDestinations.Add(@{
                Type = "CanonicalFlat"
                Path = (Join-Path $resolvedUserHome ".agents\skills")
                Description = "Universal User canonical skills (.agents/skills)"
            })
            # Nested Claude plugin
            $plannedDestinations.Add(@{
                Type = "ClaudeNestedPlugin"
                Path = (Join-Path $resolvedUserHome ".claude\skills\ai-engineering-skills")
                Description = "Universal User Claude nested plugin"
            })
            # Antigravity global
            $plannedDestinations.Add(@{
                Type = "CanonicalFlat"
                Path = (Join-Path $resolvedUserHome ".gemini\antigravity\skills")
                Description = "Universal User Antigravity skills (.gemini/antigravity/skills)"
            })
        }
    }
} else {
    # Project Scope
    switch ($Target) {
        "Codex" {
            $plannedDestinations.Add(@{
                Type = "CanonicalFlat"
                Path = (Join-Path $resolvedProjectRoot ".agents\skills")
                Description = "Codex Project skills"
            })
        }
        "Claude" {
            $plannedDestinations.Add(@{
                Type = "ClaudeNestedPlugin"
                Path = (Join-Path $resolvedProjectRoot ".claude\skills\ai-engineering-skills")
                Description = "Claude Code Project plugin"
            })
        }
        "OpenCode" {
            $plannedDestinations.Add(@{
                Type = "CanonicalFlat"
                Path = (Join-Path $resolvedProjectRoot ".opencode\skills")
                Description = "OpenCode Project skills"
            })
        }
        "Antigravity" {
            $plannedDestinations.Add(@{
                Type = "CanonicalFlat"
                Path = (Join-Path $resolvedProjectRoot ".agents\skills")
                Description = "Antigravity Project skills"
            })
        }
        "Universal" {
            $plannedDestinations.Add(@{
                Type = "CanonicalFlat"
                Path = (Join-Path $resolvedProjectRoot ".agents\skills")
                Description = "Universal Project canonical skills (.agents/skills)"
            })
            $plannedDestinations.Add(@{
                Type = "ClaudeNestedPlugin"
                Path = (Join-Path $resolvedProjectRoot ".claude\skills\ai-engineering-skills")
                Description = "Universal Project Claude nested plugin"
            })
        }
    }
}

# 5. Preflight collision detection
$collisions = [System.Collections.Generic.List[string]]::new()
foreach ($dest in $plannedDestinations) {
    if ($dest.Type -eq "CanonicalFlat") {
        foreach ($sName in $skillNames) {
            $skillTargetDir = Join-Path $dest.Path $sName
            if (Test-Path -LiteralPath $skillTargetDir) {
                $collisions.Add($skillTargetDir)
            }
        }
    } elseif ($dest.Type -eq "ClaudeNestedPlugin") {
        if (Test-Path -LiteralPath $dest.Path) {
            $collisions.Add($dest.Path)
        }
    }
}

if ($collisions.Count -gt 0 -and -not $Overwrite) {
    $msg = "Collision detected. The following destination path(s) already exist:`n" + ($collisions -join "`n") + "`nUse -Overwrite to replace managed skill directories."
    throw $msg
}

# 6. Execute installation
$installedReceiptObj = [ordered]@{
    collection  = "ai-engineering-skills"
    version     = $manifest.version
    target      = $Target
    scope       = $Scope
    installedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    skills      = @($skillNames)
}
$receiptJson = $installedReceiptObj | ConvertTo-Json -Depth 5

foreach ($dest in $plannedDestinations) {
    if ($dest.Type -eq "CanonicalFlat") {
        $destRoot = $dest.Path
        if (-not (Test-Path -LiteralPath $destRoot)) {
            if ($PSCmdlet.ShouldProcess($destRoot, "Create directory")) {
                New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
            }
        }

        foreach ($sName in $skillNames) {
            $sourceDir = Join-Path $skillsSourceRoot $sName
            $targetDir = Join-Path $destRoot $sName

            if (Test-Path -LiteralPath $targetDir) {
                if ($PSCmdlet.ShouldProcess($targetDir, "Remove existing skill directory for clean overwrite")) {
                    Remove-Item -LiteralPath $targetDir -Recurse -Force
                }
            }

            if ($PSCmdlet.ShouldProcess($targetDir, "Install skill '$sName'")) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                Copy-Item -Path (Join-Path $sourceDir "*") -Destination $targetDir -Recurse -Force
            }
        }

        # Write receipt in destination root
        $receiptPath = Join-Path $destRoot ".ai-engineering-skills.receipt.json"
        if ($PSCmdlet.ShouldProcess($receiptPath, "Write installation receipt")) {
            [System.IO.File]::WriteAllText($receiptPath, $receiptJson, [System.Text.Encoding]::UTF8)
        }
        if (-not $WhatIfPreference) {
            Write-Output "Installed $($skillNames.Count) canonical skills into $($dest.Path)"
        }
    }
    elseif ($dest.Type -eq "ClaudeNestedPlugin") {
        $pluginRoot = $dest.Path
        if (Test-Path -LiteralPath $pluginRoot) {
            if ($PSCmdlet.ShouldProcess($pluginRoot, "Remove existing Claude plugin directory for clean overwrite")) {
                Remove-Item -LiteralPath $pluginRoot -Recurse -Force
            }
        }

        if ($PSCmdlet.ShouldProcess($pluginRoot, "Create Claude plugin directory")) {
            New-Item -ItemType Directory -Path $pluginRoot -Force | Out-Null
        }

        # Copy .claude-plugin/plugin.json
        $targetClaudePluginDir = Join-Path $pluginRoot ".claude-plugin"
        if ($PSCmdlet.ShouldProcess($targetClaudePluginDir, "Install Claude plugin manifest")) {
            New-Item -ItemType Directory -Path $targetClaudePluginDir -Force | Out-Null
            Copy-Item -LiteralPath $claudeManifestSource -Destination (Join-Path $targetClaudePluginDir "plugin.json") -Force
        }

        # Copy skills
        $pluginSkillsRoot = Join-Path $pluginRoot "skills"
        if ($PSCmdlet.ShouldProcess($pluginSkillsRoot, "Create plugin skills directory")) {
            New-Item -ItemType Directory -Path $pluginSkillsRoot -Force | Out-Null
        }

        foreach ($sName in $skillNames) {
            $sourceDir = Join-Path $skillsSourceRoot $sName
            $targetDir = Join-Path $pluginSkillsRoot $sName

            if ($PSCmdlet.ShouldProcess($targetDir, "Install skill '$sName' into Claude plugin")) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
                Copy-Item -Path (Join-Path $sourceDir "*") -Destination $targetDir -Recurse -Force
            }
        }

        # Write receipt in plugin root
        $receiptPath = Join-Path $pluginRoot ".ai-engineering-skills.receipt.json"
        if ($PSCmdlet.ShouldProcess($receiptPath, "Write installation receipt")) {
            [System.IO.File]::WriteAllText($receiptPath, $receiptJson, [System.Text.Encoding]::UTF8)
        }
        if (-not $WhatIfPreference) {
            Write-Output "Installed Claude nested plugin into $($dest.Path)"
        }
    }
}
