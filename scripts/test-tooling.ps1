[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptsDir = $PSScriptRoot
$collectionRoot = Split-Path -Parent $scriptsDir
$validateScript = Join-Path $scriptsDir "validate-skills.ps1"
$installScript = Join-Path $scriptsDir "install-skills.ps1"
$uninstallScript = Join-Path $scriptsDir "uninstall-skills.ps1"
$validateEvalsScript = Join-Path $scriptsDir "validate-evals.ps1"
$manifest = Get-Content -LiteralPath (Join-Path $collectionRoot "skillset.json") -Raw | ConvertFrom-Json
$expectedSkillCount = @($manifest.skills).Count
$powerShellExecutable = (Get-Process -Id $PID).Path

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Assert-Equal($Expected, $Actual, [string]$Message) {
    if ($Expected -ne $Actual) {
        throw "Assertion failed: $Message (Expected: '$Expected', Actual: '$Actual')"
    }
}

function New-ValidationFixture([string]$Name) {
    $fixtureRoot = Join-Path $testRoot $Name
    New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null
    foreach ($relativePath in @("skills", "scripts", "schemas", "skillset.json", ".codex-plugin", ".claude-plugin", "README.md")) {
        Copy-Item -LiteralPath (Join-Path $collectionRoot $relativePath) -Destination $fixtureRoot -Recurse -Force
    }
    return $fixtureRoot
}

function Invoke-ValidatorProcess([string]$FixtureRoot) {
    $fixtureValidator = Join-Path $FixtureRoot "scripts\validate-skills.ps1"
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        $output = (& $powerShellExecutable -NoProfile -File $fixtureValidator 2>&1 | Out-String)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $output
    }
}

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ai-skills-test-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

$testCount = 0
$passCount = 0

function Run-Test([string]$Name, [scriptblock]$Body) {
    $script:testCount++
    Write-Host -NoNewline "[TEST $script:testCount] $Name... "
    try {
        & $Body
        $script:passCount++
        Write-Host "PASS" -ForegroundColor Green
    } catch {
        Write-Host "FAIL" -ForegroundColor Red
        Write-Error $_
        throw
    }
}

try {
    # Test 1: Validator executes and passes
    Run-Test "Validator passes on collection" {
        & $validateScript
        Assert-True ($null -eq $LASTEXITCODE -or $LASTEXITCODE -eq 0) "Validator exited with 0"
    }

    # Test 2: Collision detection without -Overwrite
    Run-Test "Installer aborts on collision before making changes" {
        $userHome = Join-Path $testRoot "user-collision"
        $preExisting = Join-Path $userHome ".agents\skills\analyze-requirement"
        New-Item -ItemType Directory -Path $preExisting -Force | Out-Null

        $failed = $false
        try {
            & $installScript -Target Universal -Scope User -UserHome $userHome
        } catch {
            $failed = $true
            Assert-True ($_.Exception.Message -match "Collision detected") "Error message mentions collision"
        }
        Assert-True $failed "Installer threw collision exception"
        Assert-True (-not (Test-Path (Join-Path $userHome ".claude"))) "Did not create Claude directory before aborting"
        Assert-True (-not (Test-Path (Join-Path $userHome ".gemini"))) "Did not create Gemini directory before aborting"
    }

    # Test 3: Universal User installation
    Run-Test "Universal User installs canonical, Antigravity, and Claude plugin" {
        $userHome = Join-Path $testRoot "user-universal"
        & $installScript -Target Universal -Scope User -UserHome $userHome

        # 1. Canonical .agents/skills
        $agentsSkills = Join-Path $userHome ".agents\skills"
        $agentDirs = @(Get-ChildItem -LiteralPath $agentsSkills -Directory | Select-Object -ExpandProperty Name)
        Assert-Equal $expectedSkillCount $agentDirs.Count "$expectedSkillCount canonical skills in .agents/skills"
        $agentReceiptPath = Join-Path $agentsSkills ".ai-engineering-skills.receipt.json"
        Assert-True (Test-Path -LiteralPath $agentReceiptPath) ".agents/skills receipt exists"
        $agentReceipt = Get-Content -LiteralPath $agentReceiptPath -Raw | ConvertFrom-Json
        Assert-Equal $manifest.version $agentReceipt.version "Receipt version matches $($manifest.version)"
        Assert-Equal "ai-engineering-skills" $agentReceipt.collection "Receipt collection matches"
        Assert-Equal $expectedSkillCount $agentReceipt.skills.Count "Receipt has $expectedSkillCount skills"

        # 2. Antigravity user global
        $geminiSkills = Join-Path $userHome ".gemini\config\skills"
        $geminiDirs = @(Get-ChildItem -LiteralPath $geminiSkills -Directory | Select-Object -ExpandProperty Name)
        Assert-Equal $expectedSkillCount $geminiDirs.Count "$expectedSkillCount canonical skills in .gemini/config/skills"
        $geminiReceiptPath = Join-Path $geminiSkills ".ai-engineering-skills.receipt.json"
        Assert-True (Test-Path -LiteralPath $geminiReceiptPath) ".gemini receipt exists"
        $geminiReceipt = Get-Content -LiteralPath $geminiReceiptPath -Raw | ConvertFrom-Json
        Assert-Equal $manifest.version $geminiReceipt.version "Gemini receipt version matches $($manifest.version)"

        # 3. Claude nested plugin
        $claudePlugin = Join-Path $userHome ".claude\skills\ai-engineering-skills"
        Assert-True (Test-Path -LiteralPath $claudePlugin) "Claude nested plugin directory exists"
        Assert-True (Test-Path -LiteralPath (Join-Path $claudePlugin ".claude-plugin\plugin.json")) "Claude plugin.json exists"
        $claudeSkills = Join-Path $claudePlugin "skills"
        $claudeDirs = @(Get-ChildItem -LiteralPath $claudeSkills -Directory | Select-Object -ExpandProperty Name)
        Assert-Equal $expectedSkillCount $claudeDirs.Count "$expectedSkillCount skills inside Claude plugin"

        # The plugin root contains metadata; individual skills stay under pluginRoot/skills.
        Assert-True (-not (Test-Path (Join-Path $claudePlugin "SKILL.md"))) "No SKILL.md in plugin root"
        Assert-True (-not (Test-Path (Join-Path $userHome ".claude\skills\SKILL.md"))) "No SKILL.md in .claude/skills root"

        $claudeReceiptPath = Join-Path $claudePlugin ".ai-engineering-skills.receipt.json"
        Assert-True (Test-Path -LiteralPath $claudeReceiptPath) "Claude plugin receipt exists"
        $claudeReceipt = Get-Content -LiteralPath $claudeReceiptPath -Raw | ConvertFrom-Json
        Assert-Equal $manifest.version $claudeReceipt.version "Claude receipt version matches $($manifest.version)"

        if (Get-Command claude -ErrorAction SilentlyContinue) {
            & claude plugin validate $claudePlugin
            Assert-Equal 0 $LASTEXITCODE "Installed Claude plugin passes consumer validation"
        }
    }

    # Test 4: Antigravity User Single Target
    Run-Test "Antigravity User installs only to .gemini/config/skills" {
        $userHome = Join-Path $testRoot "user-antigravity"
        & $installScript -Target Antigravity -Scope User -UserHome $userHome

        $geminiSkills = Join-Path $userHome ".gemini\config\skills"
        Assert-True (Test-Path -LiteralPath $geminiSkills) ".gemini skills exists"
        Assert-Equal $expectedSkillCount (Get-ChildItem -LiteralPath $geminiSkills -Directory).Count "$expectedSkillCount skills in Antigravity"
        Assert-True (-not (Test-Path (Join-Path $userHome ".agents"))) ".agents was not created"
        Assert-True (-not (Test-Path (Join-Path $userHome ".claude"))) ".claude was not created"
    }

    # Test 5: Universal Project Installation
    Run-Test "Universal Project installs canonical .agents/skills and Claude plugin" {
        $projRoot = Join-Path $testRoot "project-universal"
        New-Item -ItemType Directory -Path $projRoot -Force | Out-Null
        & $installScript -Target Universal -Scope Project -ProjectRoot $projRoot

        $projAgents = Join-Path $projRoot ".agents\skills"
        Assert-Equal $expectedSkillCount (Get-ChildItem -LiteralPath $projAgents -Directory).Count "$expectedSkillCount skills in project .agents/skills"
        Assert-True (Test-Path (Join-Path $projAgents ".ai-engineering-skills.receipt.json")) "Project .agents receipt exists"

        $projClaude = Join-Path $projRoot ".claude\skills\ai-engineering-skills"
        Assert-True (Test-Path (Join-Path $projClaude ".claude-plugin\plugin.json")) "Project Claude manifest exists"
        Assert-Equal $expectedSkillCount (Get-ChildItem -LiteralPath (Join-Path $projClaude "skills") -Directory).Count "$expectedSkillCount skills in project Claude plugin"
        Assert-True (Test-Path (Join-Path $projClaude ".ai-engineering-skills.receipt.json")) "Project Claude receipt exists"

        Assert-True (-not (Test-Path (Join-Path $projRoot ".gemini"))) "No .gemini created in project scope"
    }

    # Test 6: -Overwrite removes stale files in managed skill directory
    Run-Test "Installer with -Overwrite cleanly removes stale files in managed skills" {
        $projRoot = Join-Path $testRoot "project-stale"
        New-Item -ItemType Directory -Path $projRoot -Force | Out-Null
        & $installScript -Target Universal -Scope Project -ProjectRoot $projRoot

        # Add stale files inside managed directories
        $staleFile1 = Join-Path $projRoot ".agents\skills\analyze-requirement\stale-file.txt"
        Set-Content -LiteralPath $staleFile1 -Value "stale content"
        Assert-True (Test-Path -LiteralPath $staleFile1) "Stale file created"

        $staleFile2 = Join-Path $projRoot ".claude\skills\ai-engineering-skills\skills\analyze-requirement\stale-plugin.txt"
        Set-Content -LiteralPath $staleFile2 -Value "stale plugin content"
        Assert-True (Test-Path -LiteralPath $staleFile2) "Stale plugin file created"

        # Re-run with -Overwrite
        & $installScript -Target Universal -Scope Project -ProjectRoot $projRoot -Overwrite

        Assert-True (-not (Test-Path -LiteralPath $staleFile1)) "Stale file in .agents/skills removed"
        Assert-True (-not (Test-Path -LiteralPath $staleFile2)) "Stale file in Claude plugin removed"
    }

    # Test 7: Preserves non-collection skills with -Overwrite
    Run-Test "Installer with -Overwrite does not delete non-collection skills" {
        $projRoot = Join-Path $testRoot "project-custom"
        New-Item -ItemType Directory -Path $projRoot -Force | Out-Null
        & $installScript -Target Universal -Scope Project -ProjectRoot $projRoot

        # Add a custom non-collection skill
        $customSkillDir = Join-Path $projRoot ".agents\skills\custom-unrelated-skill"
        New-Item -ItemType Directory -Path $customSkillDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $customSkillDir "SKILL.md") -Value "custom"

        # Re-run with -Overwrite
        & $installScript -Target Universal -Scope Project -ProjectRoot $projRoot -Overwrite

        Assert-True (Test-Path -LiteralPath (Join-Path $customSkillDir "SKILL.md")) "Custom skill preserved"
    }

    # Test 8: unmanaged collisions require a separate explicit force switch
    Run-Test "Installer refuses to overwrite an unmanaged colliding skill" {
        $projRoot = Join-Path $testRoot "project-unmanaged"
        $unmanagedSkillDir = Join-Path $projRoot ".agents\skills\analyze-requirement"
        New-Item -ItemType Directory -Path $unmanagedSkillDir -Force | Out-Null
        $sentinel = Join-Path $unmanagedSkillDir "user-content.txt"
        Set-Content -LiteralPath $sentinel -Value "preserve until explicitly forced"

        $failed = $false
        try {
            & $installScript -Target Codex -Scope Project -ProjectRoot $projRoot -Overwrite
        } catch {
            $failed = $true
            Assert-True ($_.Exception.Message -match "not identified by an ai-engineering-skills receipt") "Error identifies unmanaged destination"
        }
        Assert-True $failed "Installer refused unmanaged overwrite"
        Assert-True (Test-Path -LiteralPath $sentinel) "Unmanaged content was preserved"

        & $installScript -Target Codex -Scope Project -ProjectRoot $projRoot -Overwrite -ForceOverwriteUnmanaged
        Assert-True (-not (Test-Path -LiteralPath $sentinel)) "Explicit force replaced unmanaged content"
        Assert-True (Test-Path -LiteralPath (Join-Path $projRoot ".agents\skills\.ai-engineering-skills.receipt.json")) "Forced install wrote receipt"
    }

    # Test 9: -WhatIf makes no filesystem modifications
    Run-Test "-WhatIf preview makes no filesystem changes" {
        $userHome = Join-Path $testRoot "user-whatif"
        & $installScript -Target Universal -Scope User -UserHome $userHome -WhatIf
        Assert-True (-not (Test-Path -LiteralPath $userHome)) "Target directory not created during WhatIf"
    }

    # Test 10: Direct Codex target installs only to .agents/skills
    Run-Test "Codex User target installs only to .agents/skills" {
        $userHome = Join-Path $testRoot "user-codex"
        & $installScript -Target Codex -Scope User -UserHome $userHome

        $agentsSkills = Join-Path $userHome ".agents\skills"
        Assert-Equal $expectedSkillCount (Get-ChildItem -LiteralPath $agentsSkills -Directory).Count "$expectedSkillCount skills in Codex .agents/skills"
        Assert-True (-not (Test-Path (Join-Path $userHome ".claude"))) ".claude not created for Codex target"
        Assert-True (-not (Test-Path (Join-Path $userHome ".gemini"))) ".gemini not created for Codex target"
    }

    # Test 11: Direct OpenCode target installs only to .opencode/skills
    Run-Test "OpenCode Project target installs to .opencode/skills" {
        $projRoot = Join-Path $testRoot "project-opencode"
        New-Item -ItemType Directory -Path $projRoot -Force | Out-Null
        & $installScript -Target OpenCode -Scope Project -ProjectRoot $projRoot

        $opencodeSkills = Join-Path $projRoot ".opencode\skills"
        Assert-Equal $expectedSkillCount (Get-ChildItem -LiteralPath $opencodeSkills -Directory).Count "$expectedSkillCount skills in .opencode/skills"
        Assert-True (-not (Test-Path (Join-Path $projRoot ".agents"))) ".agents not created for OpenCode target"
    }

    # Test 12: -Overwrite at User scope removes stale files
    Run-Test "Installer with -Overwrite at User scope removes stale files" {
        $userHome = Join-Path $testRoot "user-stale"
        & $installScript -Target Universal -Scope User -UserHome $userHome

        $staleFile = Join-Path $userHome ".agents\skills\analyze-requirement\stale.txt"
        Set-Content -LiteralPath $staleFile -Value "stale"
        Assert-True (Test-Path -LiteralPath $staleFile) "Stale file created at User scope"

        & $installScript -Target Universal -Scope User -UserHome $userHome -Overwrite
        Assert-True (-not (Test-Path -LiteralPath $staleFile)) "Stale file removed at User scope"
    }

    # Test 13: Missing ProjectRoot throws before making changes
    Run-Test "Installer throws when Scope=Project without ProjectRoot" {
        $failed = $false
        try {
            & $installScript -Target Codex -Scope Project
        } catch {
            $failed = $true
            Assert-True ($_.Exception.Message -match "ProjectRoot is required") "Error mentions ProjectRoot requirement"
        }
        Assert-True $failed "Installer threw for missing ProjectRoot"
    }

    # Test 14: Nonexistent ProjectRoot throws before making changes
    Run-Test "Installer throws when ProjectRoot does not exist" {
        $nonExistentRoot = Join-Path $testRoot "does-not-exist-root"
        $failed = $false
        try {
            & $installScript -Target Codex -Scope Project -ProjectRoot $nonExistentRoot
        } catch {
            $failed = $true
            Assert-True ($_.Exception.Message -match "does not exist") "Error mentions missing ProjectRoot directory"
        }
        Assert-True $failed "Installer threw for nonexistent ProjectRoot"
    }

    # Test 15: Project scope must not depend on user-home environment variables
    Run-Test "Project install works without user-home environment variables" {
        $projRoot = Join-Path $testRoot "project-no-home"
        New-Item -ItemType Directory -Path $projRoot -Force | Out-Null
        $savedUserProfileEnv = $env:USERPROFILE
        $savedHomeEnv = $env:HOME
        try {
            [Environment]::SetEnvironmentVariable("USERPROFILE", $null, "Process")
            [Environment]::SetEnvironmentVariable("HOME", $null, "Process")
            & $installScript -Target Codex -Scope Project -ProjectRoot $projRoot
        } finally {
            [Environment]::SetEnvironmentVariable("USERPROFILE", $savedUserProfileEnv, "Process")
            [Environment]::SetEnvironmentVariable("HOME", $savedHomeEnv, "Process")
        }
        Assert-Equal $expectedSkillCount (Get-ChildItem -LiteralPath (Join-Path $projRoot ".agents\skills") -Directory).Count "Project skills installed without home variables"
    }

    # Test 16: Validator reports all accumulated errors
    Run-Test "Validator reports multiple errors in one run" {
        $fixtureRoot = New-ValidationFixture "validator-multiple-errors"
        $fixtureManifestPath = Join-Path $fixtureRoot "skillset.json"
        $fixtureManifest = Get-Content -LiteralPath $fixtureManifestPath -Raw | ConvertFrom-Json
        $fixtureManifest.version = "01.0.0"
        $fixtureManifest.skills[0].category = "invalid"
        $fixtureManifest.PSObject.Properties.Remove("schemaVersion")
        [System.IO.File]::WriteAllText($fixtureManifestPath, ($fixtureManifest | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))

        $result = Invoke-ValidatorProcess $fixtureRoot
        Assert-Equal 1 $result.ExitCode "Invalid fixture exits non-zero"
        Assert-True ($result.Output -match "version must be valid semver") "Output contains semver error"
        Assert-True ($result.Output -match "invalid category") "Output contains category error"
        Assert-True ($result.Output -match "schemaVersion must be 2") "Output contains missing schemaVersion error"
    }

    # Test 17: Full SemVer prerelease and build metadata are accepted
    Run-Test "Validator accepts full semantic versions" {
        $fixtureRoot = New-ValidationFixture "validator-semver"
        $validVersion = "1.2.3-alpha-beta.1+build.5"
        foreach ($relativeManifest in @("skillset.json", ".codex-plugin\plugin.json", ".claude-plugin\plugin.json")) {
            $fixtureManifestPath = Join-Path $fixtureRoot $relativeManifest
            $fixtureManifest = Get-Content -LiteralPath $fixtureManifestPath -Raw | ConvertFrom-Json
            $fixtureManifest.version = $validVersion
            [System.IO.File]::WriteAllText($fixtureManifestPath, ($fixtureManifest | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
        }

        $result = Invoke-ValidatorProcess $fixtureRoot
        Assert-Equal 0 $result.ExitCode "Full SemVer fixture passes"
    }

    # Test 18: Interface fields must actually be nested under interface
    Run-Test "Validator rejects misplaced OpenAI interface fields" {
        $fixtureRoot = New-ValidationFixture "validator-openai-yaml"
        $openAiPath = Join-Path $fixtureRoot "skills\analyze-requirement\agents\openai.yaml"
        Set-Content -LiteralPath $openAiPath -Encoding UTF8 -Value @(
            "interface:",
            "other:",
            '  display_name: "Wrong parent"',
            '  short_description: "Wrong parent"',
            '  default_prompt: "Use $analyze-requirement incorrectly."'
        )

        $result = Invoke-ValidatorProcess $fixtureRoot
        Assert-Equal 1 $result.ExitCode "Misplaced interface fields fail validation"
        Assert-True ($result.Output -match "Missing 'display_name'") "Output identifies missing direct interface field"
    }

    # Test 19: Stack-routing inventory cannot silently fall behind the manifest
    Run-Test "Validator detects missing stack routing" {
        $fixtureRoot = New-ValidationFixture "validator-stack-routing"
        $implementPath = Join-Path $fixtureRoot "skills\implement-change\SKILL.md"
        $implementContent = Get-Content -LiteralPath $implementPath -Raw
        $implementContent = $implementContent.Replace('`dart-engineering`', '`removed-dart-routing`')
        [System.IO.File]::WriteAllText($implementPath, $implementContent, [System.Text.UTF8Encoding]::new($false))

        $result = Invoke-ValidatorProcess $fixtureRoot
        Assert-Equal 1 $result.ExitCode "Missing stack route fails validation"
        Assert-True ($result.Output -match "does not mention stack skill 'dart-engineering'") "Output identifies missing Dart routing"
    }

    # Test 20: Managed Antigravity installs migrate from the legacy global path
    Run-Test "Installer safely migrates the legacy Antigravity global path" {
        $userHome = Join-Path $testRoot "user-antigravity-migration"
        $legacyRoot = Join-Path $userHome ".gemini\antigravity\skills"
        $legacyManagedSkill = Join-Path $legacyRoot "analyze-requirement"
        $legacyCustomSkill = Join-Path $legacyRoot "custom-unrelated-skill"
        New-Item -ItemType Directory -Path $legacyManagedSkill -Force | Out-Null
        New-Item -ItemType Directory -Path $legacyCustomSkill -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $legacyManagedSkill "stale.txt") -Value "stale"
        Set-Content -LiteralPath (Join-Path $legacyCustomSkill "keep.txt") -Value "keep"
        $legacyReceipt = [ordered]@{
            collection = "ai-engineering-skills"
            version = "0.4.0"
            target = "Antigravity"
            scope = "User"
            skills = @("analyze-requirement")
        } | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText((Join-Path $legacyRoot ".ai-engineering-skills.receipt.json"), $legacyReceipt, [System.Text.UTF8Encoding]::new($false))

        $failed = $false
        try {
            & $installScript -Target Antigravity -Scope User -UserHome $userHome
        } catch {
            $failed = $true
            Assert-True ($_.Exception.Message -match "legacy path") "Error explains required migration"
        }
        Assert-True $failed "Migration requires explicit overwrite"

        & $installScript -Target Antigravity -Scope User -UserHome $userHome -Overwrite
        Assert-True (Test-Path -LiteralPath (Join-Path $userHome ".gemini\config\skills\analyze-requirement\SKILL.md")) "Skill installed at current Antigravity path"
        Assert-True (-not (Test-Path -LiteralPath $legacyManagedSkill)) "Receipt-declared legacy skill removed"
        Assert-True (Test-Path -LiteralPath (Join-Path $legacyCustomSkill "keep.txt")) "Unrelated legacy skill preserved"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $legacyRoot ".ai-engineering-skills.receipt.json"))) "Legacy receipt removed"
    }

    # Test 21: A collection receipt manages only the skills it explicitly lists
    Run-Test "Installer treats unlisted colliding skills as unmanaged" {
        $projRoot = Join-Path $testRoot "project-partial-receipt"
        $skillsRoot = Join-Path $projRoot ".agents\skills"
        $unlistedSkill = Join-Path $skillsRoot "analyze-requirement"
        New-Item -ItemType Directory -Path $unlistedSkill -Force | Out-Null
        $sentinel = Join-Path $unlistedSkill "user-content.txt"
        Set-Content -LiteralPath $sentinel -Value "not managed by receipt"
        $partialReceipt = [ordered]@{
            collection = "ai-engineering-skills"
            version = "0.4.0"
            target = "Codex"
            scope = "Project"
            skills = @("plan-change")
        } | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText((Join-Path $skillsRoot ".ai-engineering-skills.receipt.json"), $partialReceipt, [System.Text.UTF8Encoding]::new($false))

        $failed = $false
        try {
            & $installScript -Target Codex -Scope Project -ProjectRoot $projRoot -Overwrite
        } catch {
            $failed = $true
            Assert-True ($_.Exception.Message -match "not identified by an ai-engineering-skills receipt") "Unlisted collision is reported as unmanaged"
        }
        Assert-True $failed "Installer refused an unlisted collision"
        Assert-True (Test-Path -LiteralPath $sentinel) "Unlisted skill content was preserved"
    }

    # Test 22: A failure during commit restores every path already touched
    Run-Test "Installer rolls back an interrupted transaction" {
        $projRoot = Join-Path $testRoot "project-rollback"
        New-Item -ItemType Directory -Path $projRoot -Force | Out-Null
        & $installScript -Target Universal -Scope Project -ProjectRoot $projRoot
        $managedSkill = Join-Path $projRoot ".agents\skills\analyze-requirement"
        $sentinel = Join-Path $managedSkill "pre-transaction.txt"
        Set-Content -LiteralPath $sentinel -Value "restore me"

        $failed = $false
        try {
            & $installScript -Target Universal -Scope Project -ProjectRoot $projRoot -Overwrite -TestFailAfterOperation 1
        } catch {
            $failed = $true
            Assert-True ($_.Exception.Message -match "rolled back") "Failure reports rollback"
        }
        Assert-True $failed "Injected transaction failure was observed"
        Assert-True (Test-Path -LiteralPath $sentinel) "Original managed directory was restored"
        Assert-True (Test-Path -LiteralPath (Join-Path $projRoot ".claude\skills\ai-engineering-skills\.ai-engineering-skills.receipt.json")) "Untouched destination remains installed"
        Assert-Equal 0 @(Get-ChildItem -LiteralPath $projRoot -Recurse -Force | Where-Object Name -Like "*.ai-engineering-skills-backup-*").Count "No backup artifacts remain"
    }

    # Test 23: Skills dropped from the manifest are removed only when owned by the old receipt
    Run-Test "Installer removes retired receipt-managed skills" {
        $projRoot = Join-Path $testRoot "project-retired"
        New-Item -ItemType Directory -Path $projRoot -Force | Out-Null
        & $installScript -Target Codex -Scope Project -ProjectRoot $projRoot
        $skillsRoot = Join-Path $projRoot ".agents\skills"
        $retiredPath = Join-Path $skillsRoot "retired-skill"
        New-Item -ItemType Directory -Path $retiredPath -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $retiredPath "old.txt") -Value "old"
        $receiptPath = Join-Path $skillsRoot ".ai-engineering-skills.receipt.json"
        $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
        $receipt.skills = @($receipt.skills) + "retired-skill"
        [System.IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 5), [System.Text.UTF8Encoding]::new($false))

        & $installScript -Target Codex -Scope Project -ProjectRoot $projRoot -Overwrite
        Assert-True (-not (Test-Path -LiteralPath $retiredPath)) "Retired managed skill was removed"
    }

    # Test 24: Uninstall removes only receipt-owned content
    Run-Test "Uninstaller preserves unrelated project content" {
        $projRoot = Join-Path $testRoot "project-uninstall"
        New-Item -ItemType Directory -Path $projRoot -Force | Out-Null
        & $installScript -Target Universal -Scope Project -ProjectRoot $projRoot
        $custom = Join-Path $projRoot ".agents\skills\custom-local-skill"
        New-Item -ItemType Directory -Path $custom -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $custom "keep.txt") -Value "keep"

        & $uninstallScript -Target Universal -Scope Project -ProjectRoot $projRoot -Confirm:$false
        Assert-True (Test-Path -LiteralPath (Join-Path $custom "keep.txt")) "Unrelated skill is preserved"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $projRoot ".agents\skills\analyze-requirement"))) "Managed canonical skill is removed"
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $projRoot ".claude\skills\ai-engineering-skills"))) "Managed Claude plugin is removed"
    }

    # Test 25: WhatIf is non-mutating for uninstall
    Run-Test "Uninstaller WhatIf does not remove content" {
        $projRoot = Join-Path $testRoot "project-uninstall-whatif"
        New-Item -ItemType Directory -Path $projRoot -Force | Out-Null
        & $installScript -Target Codex -Scope Project -ProjectRoot $projRoot
        $skillPath = Join-Path $projRoot ".agents\skills\analyze-requirement"
        & $uninstallScript -Target Codex -Scope Project -ProjectRoot $projRoot -WhatIf
        Assert-True (Test-Path -LiteralPath $skillPath) "WhatIf preserved managed content"
    }

    # Test 26: Invalid receipts never authorize deletion
    Run-Test "Uninstaller refuses an invalid receipt" {
        $projRoot = Join-Path $testRoot "project-invalid-uninstall"
        $skillsRoot = Join-Path $projRoot ".agents\skills"
        $custom = Join-Path $skillsRoot "custom-local-skill"
        New-Item -ItemType Directory -Path $custom -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $skillsRoot ".ai-engineering-skills.receipt.json") -Value '{broken'
        $failed = $false
        try { & $uninstallScript -Target Codex -Scope Project -ProjectRoot $projRoot -Confirm:$false } catch { $failed = $true }
        Assert-True $failed "Malformed receipt causes a refusal"
        Assert-True (Test-Path -LiteralPath $custom) "Content remains untouched"
    }

    # Test 27: Behavioral eval fixtures are structurally valid
    Run-Test "Behavioral eval fixtures validate" {
        & $validateEvalsScript
        Assert-True ($null -eq $LASTEXITCODE -or $LASTEXITCODE -eq 0) "Eval validator exited with 0"
    }

    # Test 28: A malformed pre-existing receipt is an unmanaged collision
    Run-Test "Installer refuses to replace a malformed receipt" {
        $projRoot = Join-Path $testRoot "project-malformed-install"
        $skillsRoot = Join-Path $projRoot ".agents\skills"
        New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null
        $receiptPath = Join-Path $skillsRoot ".ai-engineering-skills.receipt.json"
        Set-Content -LiteralPath $receiptPath -Value '{broken'
        $failed = $false
        try { & $installScript -Target Codex -Scope Project -ProjectRoot $projRoot -Overwrite } catch { $failed = $true }
        Assert-True $failed "Malformed receipt requires explicit unmanaged override"
        Assert-Equal '{broken' (Get-Content -LiteralPath $receiptPath -Raw).Trim() "Malformed receipt was preserved"
    }

    # Test 29: An interrupted uninstall restores already quarantined paths
    Run-Test "Uninstaller rolls back an interrupted transaction" {
        $projRoot = Join-Path $testRoot "project-uninstall-rollback"
        New-Item -ItemType Directory -Path $projRoot -Force | Out-Null
        & $installScript -Target Codex -Scope Project -ProjectRoot $projRoot
        $skillPath = Join-Path $projRoot ".agents\skills\analyze-requirement"
        $failed = $false
        try {
            & $uninstallScript -Target Codex -Scope Project -ProjectRoot $projRoot -Confirm:$false -TestFailAfterMove 1
        } catch {
            $failed = $true
            Assert-True ($_.Exception.Message -match "rolled back") "Failure reports uninstall rollback"
        }
        Assert-True $failed "Injected uninstall failure was observed"
        Assert-True (Test-Path -LiteralPath (Join-Path $skillPath "SKILL.md")) "Quarantined skill was restored"
        Assert-True (Test-Path -LiteralPath (Join-Path $projRoot ".agents\skills\.ai-engineering-skills.receipt.json")) "Receipt remains installed"
    }

    Write-Host "`nAll $passCount/$testCount tests passed successfully!" -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
