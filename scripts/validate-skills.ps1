[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$collectionRoot = Split-Path -Parent $PSScriptRoot
$skillsRoot = Join-Path $collectionRoot "skills"
$manifestPath = Join-Path $collectionRoot "skillset.json"
$codexManifestPath = Join-Path $collectionRoot ".codex-plugin\plugin.json"
$claudeManifestPath = Join-Path $collectionRoot ".claude-plugin\plugin.json"

$errors = [System.Collections.Generic.List[string]]::new()

# 1. Check directory & manifest existence
if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
    throw "Skills directory does not exist: $skillsRoot"
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "skillset.json does not exist: $manifestPath"
}

# 2. Parse and validate skillset.json
$manifest = $null
try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
} catch {
    $errors.Add("Failed to parse skillset.json: $($_.Exception.Message)")
}

if ($manifest) {
    if ($manifest.schemaVersion -ne 2) {
        $errors.Add("skillset.json schemaVersion must be 2, found: $($manifest.schemaVersion)")
    }
    if ([string]::IsNullOrWhiteSpace($manifest.version) -or $manifest.version -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9.]+)?$') {
        $errors.Add("skillset.json version must be valid semver, found: '$($manifest.version)'")
    }

    $seenSkillNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $declaredNames = [System.Collections.Generic.List[string]]::new()
    $validCategories = @("workflow", "stack")

    if ($manifest.skills -isnot [System.Array] -and $manifest.skills -isnot [System.Collections.IList]) {
        $errors.Add("skillset.json 'skills' property must be a list")
    } else {
        foreach ($skillItem in $manifest.skills) {
            $sName = $skillItem.name
            $sCat = $skillItem.category
            if ([string]::IsNullOrWhiteSpace($sName)) {
                $errors.Add("skillset.json contains a skill entry without a name")
                continue
            }
            if ($seenSkillNames.Contains($sName)) {
                $errors.Add("Duplicate skill name in skillset.json: $sName")
            } else {
                [void]$seenSkillNames.Add($sName)
                $declaredNames.Add($sName)
            }

            if ([string]::IsNullOrWhiteSpace($sCat) -or $sCat -notin $validCategories) {
                $errors.Add("Skill '$sName' has invalid category '$sCat'. Expected one of: $($validCategories -join ', ')")
            }
        }
    }

    # Compare with actual directories
    $actualSkillDirs = @(Get-ChildItem -LiteralPath $skillsRoot -Directory)
    $actualNames = @($actualSkillDirs | ForEach-Object { $_.Name })

    foreach ($missing in @($declaredNames | Where-Object { $_ -notin $actualNames })) {
        $errors.Add("Manifest declares missing skill directory: $missing")
    }
    foreach ($undeclared in @($actualNames | Where-Object { $_ -notin $declaredNames })) {
        $errors.Add("Skill directory is not declared in skillset.json: $undeclared")
    }
}

# 3. Validate plugin manifests
if (Test-Path -LiteralPath $codexManifestPath -PathType Leaf) {
    try {
        $codex = Get-Content -LiteralPath $codexManifestPath -Raw | ConvertFrom-Json
        if ($codex.name -ne "ai-engineering-skills") {
            $errors.Add(".codex-plugin/plugin.json name must be 'ai-engineering-skills', found: '$($codex.name)'")
        }
        if ($manifest -and $codex.version -ne $manifest.version) {
            $errors.Add(".codex-plugin/plugin.json version '$($codex.version)' does not match skillset.json version '$($manifest.version)'")
        }
        if (-not $codex.skills) {
            $errors.Add(".codex-plugin/plugin.json is missing 'skills' property")
        } else {
            $codexSkillsResolved = Join-Path $collectionRoot $codex.skills
            if (-not (Test-Path -LiteralPath $codexSkillsResolved -PathType Container)) {
                $errors.Add(".codex-plugin/plugin.json skills path does not exist: $codexSkillsResolved")
            }
        }
        if (-not $codex.interface -or -not $codex.interface.displayName -or -not $codex.interface.shortDescription) {
            $errors.Add(".codex-plugin/plugin.json interface metadata is missing or incomplete")
        }
    } catch {
        $errors.Add("Failed to parse .codex-plugin/plugin.json: $($_.Exception.Message)")
    }
} else {
    $errors.Add("Missing .codex-plugin/plugin.json")
}

if (Test-Path -LiteralPath $claudeManifestPath -PathType Leaf) {
    try {
        $claude = Get-Content -LiteralPath $claudeManifestPath -Raw | ConvertFrom-Json
        if ($claude.name -ne "ai-engineering-skills") {
            $errors.Add(".claude-plugin/plugin.json name must be 'ai-engineering-skills', found: '$($claude.name)'")
        }
        if ($manifest -and $claude.version -ne $manifest.version) {
            $errors.Add(".claude-plugin/plugin.json version '$($claude.version)' does not match skillset.json version '$($manifest.version)'")
        }
    } catch {
        $errors.Add("Failed to parse .claude-plugin/plugin.json: $($_.Exception.Message)")
    }
} else {
    $errors.Add("Missing .claude-plugin/plugin.json")
}

# 4. Helper function to test markdown relative links
function Test-MarkdownLinks {
    param(
        [string]$FilePath,
        [System.Collections.Generic.List[string]]$ErrorsList
    )
    $content = Get-Content -LiteralPath $FilePath -Raw
    $contentNoCode = [regex]::Replace($content, '(?s)```.*?```', '')
    $contentNoCode = [regex]::Replace($contentNoCode, '`[^`\r\n]*`', '')
    $fileDir = Split-Path -Parent $FilePath
    $pattern = '\[([^\]]+)\]\(([^)]+)\)'
    $matches = [regex]::Matches($contentNoCode, $pattern)
    foreach ($m in $matches) {
        $target = $m.Groups[2].Value.Trim()
        if ($target -match '^(?:[a-zA-Z][a-zA-Z0-9+.-]*:|\/\/)' -or $target.StartsWith('#') -or $target.StartsWith('mailto:')) {
            continue
        }
        $cleanTarget = $target.Split('#')[0]
        if ([string]::IsNullOrWhiteSpace($cleanTarget)) { continue }
        $cleanTargetNorm = $cleanTarget.Replace('/', [System.IO.Path]::DirectorySeparatorChar).Replace('\', [System.IO.Path]::DirectorySeparatorChar)
        $targetPath = Join-Path $fileDir $cleanTargetNorm
        if (-not (Test-Path -LiteralPath $targetPath)) {
            $ErrorsList.Add("Broken relative link in '$FilePath': target '$target' does not exist")
        }
    }
}

# Check root README.md links
$readmePath = Join-Path $collectionRoot "README.md"
if (Test-Path -LiteralPath $readmePath) {
    Test-MarkdownLinks -FilePath $readmePath -ErrorsList $errors
}

# 5. Validate each skill directory
foreach ($skillDir in Get-ChildItem -LiteralPath $skillsRoot -Directory) {
    $name = $skillDir.Name
    if ($name -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $name.Length -gt 64) {
        $errors.Add("Invalid skill directory name: '$name' (must be lowercase alphanumeric with hyphens, <= 64 chars)")
    }

    $skillPath = Join-Path $skillDir.FullName "SKILL.md"
    if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
        $errors.Add("Missing SKILL.md in skill: $name")
        continue
    }

    # Validate all markdown links in skill directory
    Get-ChildItem -LiteralPath $skillDir.FullName -Filter "*.md" -Recurse | ForEach-Object {
        Test-MarkdownLinks -FilePath $_.FullName -ErrorsList $errors
    }

    # Validate SKILL.md frontmatter
    $content = Get-Content -LiteralPath $skillPath -Raw
    if ($content -notmatch '(?s)^---\r?\n(.*?)\r?\n---\r?\n') {
        $errors.Add("Missing or invalid YAML frontmatter in $skillPath")
    } else {
        $frontmatterRaw = $matches[1]
        $lines = $frontmatterRaw -split '\r?\n'
        $seenKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $parsed = @{}

        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
                continue
            }
            if ($trimmed -match '^([a-zA-Z0-9_-]+)\s*:\s*(.*)$') {
                $key = $matches[1].Trim().ToLowerInvariant()
                $val = $matches[2].Trim()
                if ($seenKeys.Contains($key)) {
                    $errors.Add("Duplicate frontmatter field '$key' in $skillPath")
                } else {
                    [void]$seenKeys.Add($key)
                }
                $parsed[$key] = $val
            } else {
                $errors.Add("Invalid frontmatter YAML syntax in $($skillPath): '$line'")
            }
        }

        # Canonical SKILL.md ONLY accepts 'name' and 'description'
        $allowedKeys = @("name", "description")
        foreach ($k in $parsed.Keys) {
            if ($k -notin $allowedKeys) {
                $errors.Add("Disallowed frontmatter field '$k' in $skillPath. Canonical SKILL.md only allows: $($allowedKeys -join ', ')")
            }
        }

        if (-not $parsed.ContainsKey("name") -or [string]::IsNullOrWhiteSpace($parsed["name"])) {
            $errors.Add("Frontmatter missing 'name' in $skillPath")
        } elseif ($parsed["name"] -ne $name) {
            $errors.Add("Frontmatter name '$($parsed['name'])' does not match directory name '$name' in $skillPath")
        }

        if (-not $parsed.ContainsKey("description") -or [string]::IsNullOrWhiteSpace($parsed["description"])) {
            $errors.Add("Frontmatter missing or empty 'description' in $skillPath")
        }
    }

    if ($content -match '(?i)TODO|REPLACE_WITH|PLACEHOLDER') {
        $errors.Add("Unfinished scaffold marker in $skillPath")
    }

    # Validate optional agents/openai.yaml
    $openAiPath = Join-Path $skillDir.FullName "agents\openai.yaml"
    if (Test-Path -LiteralPath $openAiPath -PathType Leaf) {
        $openAiContent = Get-Content -LiteralPath $openAiPath -Raw
        if ($openAiContent -notmatch '(?m)^interface:\s*$') {
            $errors.Add("Missing 'interface:' root key in $openAiPath")
        }
        if ($openAiContent -notmatch '(?m)^\s+display_name:\s*\S+') {
            $errors.Add("Missing 'display_name' in $openAiPath")
        }
        if ($openAiContent -notmatch '(?m)^\s+short_description:\s*\S+') {
            $errors.Add("Missing 'short_description' in $openAiPath")
        }
        if ($openAiContent -notmatch '(?m)^\s+default_prompt:\s*\S+') {
            $errors.Add("Missing 'default_prompt' in $openAiPath")
        }
        if ($openAiContent -notmatch [regex]::Escape("`$$name")) {
            $errors.Add("Default prompt in $openAiPath does not mention the skill invocation token: `$$name")
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

$skillCount = (Get-ChildItem -LiteralPath $skillsRoot -Directory).Count
$versionStr = if ($manifest) { $manifest.version } else { "unknown" }
Write-Output "Validated $skillCount skills from skillset.json version $versionStr."
exit 0
