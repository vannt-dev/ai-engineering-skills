[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet("Codex", "Claude", "OpenCode", "Antigravity", "Universal")]
    [string]$Target = "Universal",

    [ValidateSet("User", "Project")]
    [string]$Scope = "User",

    [string]$ProjectRoot,

    [string]$UserHome,

    [switch]$Overwrite,

    [switch]$ForceOverwriteUnmanaged,

    # Deterministic fault injection used only by the repository's rollback test.
    [Parameter(DontShow)]
    [ValidateRange(0, 10000)]
    [int]$TestFailAfterOperation = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$collectionRoot = Split-Path -Parent $PSScriptRoot
$validatorScript = Join-Path $PSScriptRoot "validate-skills.ps1"
$manifestPath = Join-Path $collectionRoot "skillset.json"
$skillsSourceRoot = Join-Path $collectionRoot "skills"

if ($ForceOverwriteUnmanaged -and -not $Overwrite) {
    throw "ForceOverwriteUnmanaged requires -Overwrite."
}

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

# 3. Resolve only the root required by the selected scope
$resolvedUserHome = $null
$resolvedProjectRoot = $null
if ($Scope -eq "User") {
    $resolvedUserHome = if ($UserHome) {
        [System.IO.Path]::GetFullPath($UserHome)
    } elseif ($env:USERPROFILE) {
        [System.IO.Path]::GetFullPath($env:USERPROFILE)
    } elseif ($env:HOME) {
        [System.IO.Path]::GetFullPath($env:HOME)
    } else {
        throw "Could not determine User home directory. Specify -UserHome."
    }
} else {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
        throw "ProjectRoot is required when Scope is 'Project'."
    }
    if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
        throw "ProjectRoot directory does not exist: $ProjectRoot"
    }
    $resolvedProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
}

# 4. Plan destinations
# Every destination is flat ('CanonicalFlat'): <dest>/<skill-name>/SKILL.md and a receipt in <dest>.
# Claude Code discovers skills only at .claude/skills/<skill-name>/SKILL.md. Universal leaves that path out:
# OpenCode reads .claude/skills as well as .agents/skills and wants a skill name in one place only.
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
                Type = "CanonicalFlat"
                Path = (Join-Path $resolvedUserHome ".claude\skills")
                Description = "Claude Code User skills"
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
                Path = (Join-Path $resolvedUserHome ".gemini\config\skills")
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
            # Antigravity global
            $plannedDestinations.Add(@{
                Type = "CanonicalFlat"
                Path = (Join-Path $resolvedUserHome ".gemini\config\skills")
                Description = "Universal User Antigravity skills (.gemini/config/skills)"
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
                Type = "CanonicalFlat"
                Path = (Join-Path $resolvedProjectRoot ".claude\skills")
                Description = "Claude Code Project skills"
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
        }
    }
}

# 5. Preflight collision and ownership detection
function Get-ManagedReceipt {
    param([string]$ReceiptPath)

    if (-not (Test-Path -LiteralPath $ReceiptPath -PathType Leaf)) {
        return $null
    }

    try {
        $receipt = Get-Content -LiteralPath $ReceiptPath -Raw | ConvertFrom-Json
        if ($receipt.collection -eq "ai-engineering-skills" -and $receipt.PSObject.Properties["skills"] -and $receipt.skills -is [System.Array]) {
            return $receipt
        }
    } catch {
        return $null
    }

    return $null
}

$legacyAntigravityRoot = $null
$legacyAntigravityReceipt = $null
$legacyAntigravitySkillPaths = [System.Collections.Generic.List[string]]::new()
if ($Scope -eq "User" -and $Target -in @("Antigravity", "Universal")) {
    $legacyAntigravityRoot = Join-Path $resolvedUserHome ".gemini\antigravity\skills"
    $legacyReceiptPath = Join-Path $legacyAntigravityRoot ".ai-engineering-skills.receipt.json"
    $legacyAntigravityReceipt = Get-ManagedReceipt -ReceiptPath $legacyReceiptPath
    if ($legacyAntigravityReceipt) {
        if (-not $legacyAntigravityReceipt.PSObject.Properties["skills"]) {
            throw "Legacy Antigravity receipt is missing its skills list: '$legacyReceiptPath'"
        }
        $legacyRootFull = [System.IO.Path]::GetFullPath($legacyAntigravityRoot)
        $legacyRootPrefix = $legacyRootFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        foreach ($legacySkillName in @($legacyAntigravityReceipt.skills)) {
            if ($legacySkillName -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
                throw "Legacy receipt contains an unsafe skill name: '$legacySkillName'"
            }
            $legacySkillPath = [System.IO.Path]::GetFullPath((Join-Path $legacyRootFull $legacySkillName))
            if (-not $legacySkillPath.StartsWith($legacyRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "Legacy receipt resolves outside its installation root: '$legacySkillName'"
            }
            $legacyAntigravitySkillPaths.Add($legacySkillPath)
        }
    }
    if ($legacyAntigravityReceipt -and -not $Overwrite) {
        throw "A managed Antigravity installation exists at the legacy path '$legacyAntigravityRoot'. Re-run with -Overwrite to migrate it to .gemini/config/skills."
    }
}

# Up to 1.3.0 the installer put Claude Code skills in a nested plugin, .claude/skills/ai-engineering-skills,
# a layout Claude Code does not load. -Overwrite removes it; with -Target Claude the flat layout replaces it.
$legacyClaudePluginPath = $null
if ($Target -in @("Claude", "Universal")) {
    $claudeRoot = if ($Scope -eq "User") { $resolvedUserHome } else { $resolvedProjectRoot }
    $legacyCandidate = Join-Path $claudeRoot ".claude\skills\ai-engineering-skills"
    if (Get-ManagedReceipt -ReceiptPath (Join-Path $legacyCandidate ".ai-engineering-skills.receipt.json")) {
        if (-not $Overwrite) {
            throw "A managed Claude Code installation in the old nested layout exists at '$legacyCandidate', and Claude Code does not load skills from it. Re-run with -Overwrite to remove it."
        }
        $legacyClaudePluginPath = $legacyCandidate
    }
}

$collisions = [System.Collections.Generic.List[string]]::new()
$unmanagedCollisions = [System.Collections.Generic.List[string]]::new()
foreach ($dest in $plannedDestinations) {
    if ($dest.Type -eq "CanonicalFlat") {
        $receiptPath = Join-Path $dest.Path ".ai-engineering-skills.receipt.json"
        $managedReceipt = Get-ManagedReceipt -ReceiptPath $receiptPath
        if ((Test-Path -LiteralPath $receiptPath) -and -not $managedReceipt) {
            $collisions.Add($receiptPath)
            $unmanagedCollisions.Add($receiptPath)
        }
        $managedSkillNames = if ($managedReceipt -and $managedReceipt.PSObject.Properties["skills"]) { @($managedReceipt.skills) } else { @() }
        foreach ($sName in $skillNames) {
            $skillTargetDir = Join-Path $dest.Path $sName
            if (Test-Path -LiteralPath $skillTargetDir) {
                $collisions.Add($skillTargetDir)
                if ($sName -notin $managedSkillNames) {
                    $unmanagedCollisions.Add($skillTargetDir)
                }
            }
        }
    }
}

if ($collisions.Count -gt 0 -and -not $Overwrite) {
    $msg = "Collision detected. The following destination path(s) already exist:`n" + ($collisions -join "`n") + "`nUse -Overwrite to replace managed skill directories."
    throw $msg
}

if ($unmanagedCollisions.Count -gt 0 -and $Overwrite -and -not $ForceOverwriteUnmanaged) {
    $msg = "Refusing to overwrite destination path(s) that are not identified by an ai-engineering-skills receipt:`n" + ($unmanagedCollisions -join "`n") + "`nUse -ForceOverwriteUnmanaged together with -Overwrite only after verifying these paths."
    throw $msg
}

# 6. Stage the complete payload before changing any destination
$installedReceiptObj = [ordered]@{
    schemaVersion = 1
    collection  = "ai-engineering-skills"
    version     = $manifest.version
    target      = $Target
    scope       = $Scope
    installedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    skills      = @($skillNames)
}
$receiptJson = $installedReceiptObj | ConvertTo-Json -Depth 5
$operations = [System.Collections.Generic.List[hashtable]]::new()
$stageRoot = $null

function Add-InstallOperation {
    param([string]$TargetPath, [AllowNull()][string]$StagedPath, [string]$Description)
    $operations.Add(@{ Target = $TargetPath; Staged = $StagedPath; Description = $Description })
}

# Windows PowerShell 5.1 cannot delete paths longer than 260 characters; the \\?\ form of the path can.
function Remove-Tree {
    param([string]$Path)
    try {
        Remove-Item -LiteralPath $Path -Recurse -Force
    } catch {
        $full = [System.IO.Path]::GetFullPath($Path)
        if ([System.IO.Path]::DirectorySeparatorChar -ne '\' -or $full.StartsWith('\\')) { throw }
        $long = '\\?\' + $full
        if ([System.IO.Directory]::Exists($long)) {
            [System.IO.Directory]::Delete($long, $true)
        } elseif ([System.IO.File]::Exists($long)) {
            [System.IO.File]::Delete($long)
        }
    }
}

function Assert-SafeReceiptSkillName {
    param([string]$SkillName, [string]$ReceiptPath)
    if ($SkillName -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
        throw "Receipt '$ReceiptPath' contains an unsafe skill name: '$SkillName'"
    }
}

if (-not $WhatIfPreference) {
    $stageRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-engineering-skills-stage-" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
}

try {
    $destinationIndex = 0
    foreach ($dest in $plannedDestinations) {
        $destinationIndex++
        if ($dest.Type -eq "CanonicalFlat") {
            $receiptPath = Join-Path $dest.Path ".ai-engineering-skills.receipt.json"
            $oldReceipt = Get-ManagedReceipt -ReceiptPath $receiptPath
            if ($oldReceipt -and $oldReceipt.PSObject.Properties["skills"]) {
                foreach ($oldName in @($oldReceipt.skills)) {
                    Assert-SafeReceiptSkillName -SkillName $oldName -ReceiptPath $receiptPath
                    if ($oldName -notin $skillNames) {
                        Add-InstallOperation -TargetPath (Join-Path $dest.Path $oldName) -StagedPath $null -Description "Remove retired managed skill '$oldName'"
                    }
                }
            }

            foreach ($sName in $skillNames) {
                $stagedSkill = $null
                if (-not $WhatIfPreference) {
                    $stagedSkill = Join-Path $stageRoot ("destination-$destinationIndex\skills\$sName")
                    New-Item -ItemType Directory -Path $stagedSkill -Force | Out-Null
                    Get-ChildItem -LiteralPath (Join-Path $skillsSourceRoot $sName) -Force | Copy-Item -Destination $stagedSkill -Recurse -Force
                    if (-not (Test-Path -LiteralPath (Join-Path $stagedSkill "SKILL.md") -PathType Leaf)) {
                        throw "Staging verification failed for skill '$sName'."
                    }
                }
                Add-InstallOperation -TargetPath (Join-Path $dest.Path $sName) -StagedPath $stagedSkill -Description "Install skill '$sName'"
            }

            $stagedReceipt = $null
            if (-not $WhatIfPreference) {
                $stagedReceipt = Join-Path $stageRoot ("destination-$destinationIndex\receipt.json")
                New-Item -ItemType Directory -Path (Split-Path -Parent $stagedReceipt) -Force | Out-Null
                [System.IO.File]::WriteAllText($stagedReceipt, $receiptJson, [System.Text.UTF8Encoding]::new($false))
                $null = Get-Content -LiteralPath $stagedReceipt -Raw | ConvertFrom-Json
            }
            Add-InstallOperation -TargetPath $receiptPath -StagedPath $stagedReceipt -Description "Write installation receipt"
        }
    }

    if ($legacyClaudePluginPath) {
        Add-InstallOperation -TargetPath $legacyClaudePluginPath -StagedPath $null -Description "Remove the old nested Claude Code installation"
    }

    if ($legacyAntigravityReceipt -and $Overwrite) {
        foreach ($legacySkillPath in $legacyAntigravitySkillPaths) {
            Add-InstallOperation -TargetPath $legacySkillPath -StagedPath $null -Description "Remove managed skill from legacy Antigravity location"
        }
        Add-InstallOperation -TargetPath (Join-Path $legacyAntigravityRoot ".ai-engineering-skills.receipt.json") -StagedPath $null -Description "Remove legacy Antigravity receipt"
    }

    $approved = $true
    foreach ($operation in $operations) {
        if (-not $PSCmdlet.ShouldProcess($operation.Target, $operation.Description)) { $approved = $false }
    }
    if ($WhatIfPreference) { return }
    if (-not $approved) {
        throw "Installation cancelled before the transaction started."
    }

    # Backups live beside their targets so rename/restore remains on the same volume.
    $transactionId = [System.Guid]::NewGuid().ToString("N")
    $applied = [System.Collections.Generic.List[hashtable]]::new()
    $operationCount = 0
    try {
        # Phase one: move every old target aside before installing any new payload.
        foreach ($operation in $operations) {
            $targetPath = $operation.Target
            $targetParent = Split-Path -Parent $targetPath
            if (-not (Test-Path -LiteralPath $targetParent -PathType Container)) {
                New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
            }
            $backupPath = "$targetPath.ai-engineering-skills-backup-$transactionId"
            $record = @{ Target = $targetPath; Backup = $null }
            if (Test-Path -LiteralPath $targetPath) {
                Move-Item -LiteralPath $targetPath -Destination $backupPath
                $record.Backup = $backupPath
            }
            $applied.Add($record)
        }

        # Phase two: materialize staged payloads. Delete-only operations have no source.
        foreach ($operation in $operations) {
            if ($operation.Staged) {
                Copy-Item -LiteralPath $operation.Staged -Destination $operation.Target -Recurse -Force
            }

            $operationCount++
            if ($TestFailAfterOperation -gt 0 -and $operationCount -eq $TestFailAfterOperation) {
                throw "Injected installer failure after operation $operationCount."
            }
        }
    } catch {
        for ($i = $applied.Count - 1; $i -ge 0; $i--) {
            $record = $applied[$i]
            if (Test-Path -LiteralPath $record.Target) {
                Remove-Tree -Path $record.Target
            }
            if ($record.Backup -and (Test-Path -LiteralPath $record.Backup)) {
                Move-Item -LiteralPath $record.Backup -Destination $record.Target
            }
        }
        throw "Installation transaction failed and was rolled back: $($_.Exception.Message)"
    }

    foreach ($record in $applied) {
        if ($record.Backup -and (Test-Path -LiteralPath $record.Backup)) {
            try { Remove-Tree -Path $record.Backup } catch { Write-Warning "Installed successfully, but could not remove backup '$($record.Backup)': $($_.Exception.Message)" }
        }
    }

    foreach ($dest in $plannedDestinations) {
        Write-Output "Installed $($skillNames.Count) canonical skills into $($dest.Path)"
    }
    if ($legacyAntigravityReceipt -and $Overwrite) {
        Write-Output "Migrated managed Antigravity skills from $legacyAntigravityRoot"
    }
    if ($legacyClaudePluginPath) {
        Write-Output "Removed the old nested Claude Code installation at $legacyClaudePluginPath"
    }
    if ($Target -eq "Universal") {
        Write-Output "Claude Code does not read these locations: install the plugin (see README) or run again with -Target Claude."
    }
} finally {
    if ($stageRoot -and (Test-Path -LiteralPath $stageRoot)) {
        Remove-Item -LiteralPath $stageRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
