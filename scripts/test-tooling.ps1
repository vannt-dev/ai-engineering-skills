[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptsDir = $PSScriptRoot
$validateScript = Join-Path $scriptsDir "validate-skills.ps1"
$installScript = Join-Path $scriptsDir "install-skills.ps1"

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
        Assert-Equal 13 $agentDirs.Count "13 canonical skills in .agents/skills"
        $agentReceiptPath = Join-Path $agentsSkills ".ai-engineering-skills.receipt.json"
        Assert-True (Test-Path -LiteralPath $agentReceiptPath) ".agents/skills receipt exists"
        $agentReceipt = Get-Content -LiteralPath $agentReceiptPath -Raw | ConvertFrom-Json
        Assert-Equal "0.2.0" $agentReceipt.version "Receipt version matches 0.2.0"
        Assert-Equal "ai-engineering-skills" $agentReceipt.collection "Receipt collection matches"
        Assert-Equal 13 $agentReceipt.skills.Count "Receipt has 13 skills"

        # 2. Antigravity user global
        $geminiSkills = Join-Path $userHome ".gemini\antigravity\skills"
        $geminiDirs = @(Get-ChildItem -LiteralPath $geminiSkills -Directory | Select-Object -ExpandProperty Name)
        Assert-Equal 13 $geminiDirs.Count "13 canonical skills in .gemini/antigravity/skills"
        $geminiReceiptPath = Join-Path $geminiSkills ".ai-engineering-skills.receipt.json"
        Assert-True (Test-Path -LiteralPath $geminiReceiptPath) ".gemini receipt exists"
        $geminiReceipt = Get-Content -LiteralPath $geminiReceiptPath -Raw | ConvertFrom-Json
        Assert-Equal "0.2.0" $geminiReceipt.version "Gemini receipt version matches 0.2.0"

        # 3. Claude nested plugin
        $claudePlugin = Join-Path $userHome ".claude\skills\ai-engineering-skills"
        Assert-True (Test-Path -LiteralPath $claudePlugin) "Claude nested plugin directory exists"
        Assert-True (Test-Path -LiteralPath (Join-Path $claudePlugin ".claude-plugin\plugin.json")) "Claude plugin.json exists"
        $claudeSkills = Join-Path $claudePlugin "skills"
        $claudeDirs = @(Get-ChildItem -LiteralPath $claudeSkills -Directory | Select-Object -ExpandProperty Name)
        Assert-Equal 13 $claudeDirs.Count "13 skills inside Claude plugin"

        # Check no SKILL.md directly under plugin root (avoids OpenCode duplicate discovery)
        Assert-True (-not (Test-Path (Join-Path $claudePlugin "SKILL.md"))) "No SKILL.md in plugin root"
        Assert-True (-not (Test-Path (Join-Path $userHome ".claude\skills\SKILL.md"))) "No SKILL.md in .claude/skills root"

        $claudeReceiptPath = Join-Path $claudePlugin ".ai-engineering-skills.receipt.json"
        Assert-True (Test-Path -LiteralPath $claudeReceiptPath) "Claude plugin receipt exists"
        $claudeReceipt = Get-Content -LiteralPath $claudeReceiptPath -Raw | ConvertFrom-Json
        Assert-Equal "0.2.0" $claudeReceipt.version "Claude receipt version matches 0.2.0"
    }

    # Test 4: Antigravity User Single Target
    Run-Test "Antigravity User installs only to .gemini/antigravity/skills" {
        $userHome = Join-Path $testRoot "user-antigravity"
        & $installScript -Target Antigravity -Scope User -UserHome $userHome

        $geminiSkills = Join-Path $userHome ".gemini\antigravity\skills"
        Assert-True (Test-Path -LiteralPath $geminiSkills) ".gemini skills exists"
        Assert-Equal 13 (Get-ChildItem -LiteralPath $geminiSkills -Directory).Count "13 skills in Antigravity"
        Assert-True (-not (Test-Path (Join-Path $userHome ".agents"))) ".agents was not created"
        Assert-True (-not (Test-Path (Join-Path $userHome ".claude"))) ".claude was not created"
    }

    # Test 5: Universal Project Installation
    Run-Test "Universal Project installs canonical .agents/skills and Claude plugin" {
        $projRoot = Join-Path $testRoot "project-universal"
        New-Item -ItemType Directory -Path $projRoot -Force | Out-Null
        & $installScript -Target Universal -Scope Project -ProjectRoot $projRoot

        $projAgents = Join-Path $projRoot ".agents\skills"
        Assert-Equal 13 (Get-ChildItem -LiteralPath $projAgents -Directory).Count "13 skills in project .agents/skills"
        Assert-True (Test-Path (Join-Path $projAgents ".ai-engineering-skills.receipt.json")) "Project .agents receipt exists"

        $projClaude = Join-Path $projRoot ".claude\skills\ai-engineering-skills"
        Assert-True (Test-Path (Join-Path $projClaude ".claude-plugin\plugin.json")) "Project Claude manifest exists"
        Assert-Equal 13 (Get-ChildItem -LiteralPath (Join-Path $projClaude "skills") -Directory).Count "13 skills in project Claude plugin"
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

    # Test 8: -WhatIf makes no filesystem modifications
    Run-Test "-WhatIf preview makes no filesystem changes" {
        $userHome = Join-Path $testRoot "user-whatif"
        & $installScript -Target Universal -Scope User -UserHome $userHome -WhatIf
        Assert-True (-not (Test-Path -LiteralPath $userHome)) "Target directory not created during WhatIf"
    }

    Write-Host "`nAll $passCount/$testCount tests passed successfully!" -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
