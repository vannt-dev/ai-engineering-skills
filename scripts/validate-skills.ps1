[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$collectionRoot = Split-Path -Parent $PSScriptRoot
$skillsRoot = Join-Path $collectionRoot "skills"
$manifestPath = Join-Path $collectionRoot "skillset.json"
$codexManifestPath = Join-Path $collectionRoot ".codex-plugin\plugin.json"
$claudeManifestPath = Join-Path $collectionRoot ".claude-plugin\plugin.json"
$schemasRoot = Join-Path $collectionRoot "schemas"

$errors = [System.Collections.Generic.List[string]]::new()
$semverPattern = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)(?:\.(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*))*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$'
$declaredNames = [System.Collections.Generic.List[string]]::new()
$stackNames = [System.Collections.Generic.List[string]]::new()

function Get-PropertyValue {
    param($Object, [string]$Name)

    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) {
        return $Object.PSObject.Properties[$Name].Value
    }
    return $null
}

# Parse the published contracts up front. Runtime validation below intentionally
# remains dependency-free and enforces the same collection-specific constraints.
$requiredSchemas = @("skillset.schema.json", "receipt.schema.json", "codex-plugin.schema.json", "claude-plugin.schema.json")
$parsedSchemas = @{}
foreach ($schemaName in $requiredSchemas) {
    $schemaPath = Join-Path $schemasRoot $schemaName
    if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) {
        $errors.Add("Missing JSON Schema: schemas/$schemaName")
        continue
    }
    try {
        $schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
        if ((Get-PropertyValue $schema '$schema') -ne 'https://json-schema.org/draft/2020-12/schema') {
            $errors.Add("Schema '$schemaName' must declare JSON Schema draft 2020-12.")
        }
        if ([string]::IsNullOrWhiteSpace((Get-PropertyValue $schema '$id'))) {
            $errors.Add("Schema '$schemaName' is missing a stable `$id.")
        }
        $parsedSchemas[$schemaName] = $schema
    } catch {
        $errors.Add("Failed to parse schemas/$($schemaName): $($_.Exception.Message)")
    }
}

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
    $schemaVersion = Get-PropertyValue $manifest "schemaVersion"
    $manifestVersion = Get-PropertyValue $manifest "version"
    $manifestSkills = Get-PropertyValue $manifest "skills"

    if ($schemaVersion -ne 2) {
        $errors.Add("skillset.json schemaVersion must be 2, found: $schemaVersion")
    }
    if ($parsedSchemas.ContainsKey("skillset.schema.json")) {
        $schemaProperties = Get-PropertyValue $parsedSchemas["skillset.schema.json"] "properties"
        $schemaVersionContract = Get-PropertyValue $schemaProperties "schemaVersion"
        $schemaConst = Get-PropertyValue $schemaVersionContract "const"
        if ($schemaConst -ne $schemaVersion) {
            $errors.Add("skillset.schema.json schemaVersion const '$schemaConst' does not match skillset.json '$schemaVersion'.")
        }
    }
    if ([string]::IsNullOrWhiteSpace($manifestVersion) -or $manifestVersion -notmatch $semverPattern) {
        $errors.Add("skillset.json version must be valid semver, found: '$manifestVersion'")
    }

    $seenSkillNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $validCategories = @("workflow", "stack")

    if ($manifestSkills -isnot [System.Array] -and $manifestSkills -isnot [System.Collections.IList]) {
        $errors.Add("skillset.json 'skills' property must be a list")
    } else {
        foreach ($skillItem in $manifestSkills) {
            $sName = Get-PropertyValue $skillItem "name"
            $sCat = Get-PropertyValue $skillItem "category"
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
            } elseif ($sCat -eq "stack") {
                $stackNames.Add($sName)
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
        $codexName = Get-PropertyValue $codex "name"
        $codexVersion = Get-PropertyValue $codex "version"
        $codexSkills = Get-PropertyValue $codex "skills"
        $codexInterface = Get-PropertyValue $codex "interface"
        if ($codexName -ne "ai-engineering-skills") {
            $errors.Add(".codex-plugin/plugin.json name must be 'ai-engineering-skills', found: '$codexName'")
        }
        if ($manifest -and $codexVersion -ne $manifestVersion) {
            $errors.Add(".codex-plugin/plugin.json version '$codexVersion' does not match skillset.json version '$manifestVersion'")
        }
        if (-not $codexSkills) {
            $errors.Add(".codex-plugin/plugin.json is missing 'skills' property")
        } else {
            $codexSkillsResolved = Join-Path $collectionRoot $codexSkills
            if (-not (Test-Path -LiteralPath $codexSkillsResolved -PathType Container)) {
                $errors.Add(".codex-plugin/plugin.json skills path does not exist: $codexSkillsResolved")
            }
        }
        $displayName = Get-PropertyValue $codexInterface "displayName"
        $shortDescription = Get-PropertyValue $codexInterface "shortDescription"
        if (-not $codexInterface -or -not $displayName -or -not $shortDescription) {
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
        $claudeName = Get-PropertyValue $claude "name"
        $claudeVersion = Get-PropertyValue $claude "version"
        if ($claudeName -ne "ai-engineering-skills") {
            $errors.Add(".claude-plugin/plugin.json name must be 'ai-engineering-skills', found: '$claudeName'")
        }
        if ($manifest -and $claudeVersion -ne $manifestVersion) {
            $errors.Add(".claude-plugin/plugin.json version '$claudeVersion' does not match skillset.json version '$manifestVersion'")
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
        } elseif ($parsed["description"].Length -gt 1024) {
            $errors.Add("Frontmatter description exceeds 1024 characters in $skillPath")
        }
    }

    if ($content -match '(?i)TODO|REPLACE_WITH|PLACEHOLDER') {
        $errors.Add("Unfinished scaffold marker in $skillPath")
    }

    # Validate optional agents/openai.yaml. Parse the direct interface mapping so
    # fields elsewhere in the document cannot satisfy these checks accidentally.
    $openAiPath = Join-Path $skillDir.FullName "agents\openai.yaml"
    if (Test-Path -LiteralPath $openAiPath -PathType Leaf) {
        $openAiContent = Get-Content -LiteralPath $openAiPath -Raw
        $interfaceValues = @{}
        $interfaceSeen = $false
        $currentRoot = $null
        foreach ($openAiLine in ($openAiContent -split '\r?\n')) {
            if ($openAiLine -match "`t") {
                $errors.Add("Tab indentation is not allowed in $openAiPath")
                continue
            }
            if ([string]::IsNullOrWhiteSpace($openAiLine) -or $openAiLine.TrimStart().StartsWith("#")) {
                continue
            }
            if ($openAiLine -match '^([a-zA-Z0-9_-]+):\s*(.*)$') {
                $currentRoot = $matches[1]
                if ($currentRoot -eq "interface") {
                    if ($interfaceSeen) {
                        $errors.Add("Duplicate 'interface' root key in $openAiPath")
                    }
                    $interfaceSeen = $true
                    if (-not [string]::IsNullOrWhiteSpace($matches[2])) {
                        $errors.Add("The 'interface' key must contain a nested mapping in $openAiPath")
                    }
                }
                continue
            }
            if (($openAiLine -match '^  ([a-zA-Z0-9_-]+):\s*(.*)$') -and $currentRoot -eq "interface") {
                $interfaceKey = $matches[1]
                $interfaceValue = $matches[2].Trim()
                if ($interfaceValues.ContainsKey($interfaceKey)) {
                    $errors.Add("Duplicate interface field '$interfaceKey' in $openAiPath")
                }
                $interfaceValues[$interfaceKey] = $interfaceValue
                continue
            }
            if ($currentRoot -eq "interface" -and $openAiLine -match '^\s+') {
                $errors.Add("Invalid interface field syntax in $($openAiPath): '$openAiLine'")
            } elseif ($openAiLine -notmatch '^\s+') {
                $errors.Add("Invalid root YAML syntax in $($openAiPath): '$openAiLine'")
            }
        }

        if (-not $interfaceSeen) {
            $errors.Add("Missing 'interface:' root key in $openAiPath")
        }
        if (-not $interfaceValues.ContainsKey("display_name") -or [string]::IsNullOrWhiteSpace($interfaceValues["display_name"])) {
            $errors.Add("Missing 'display_name' in $openAiPath")
        }
        if (-not $interfaceValues.ContainsKey("short_description") -or [string]::IsNullOrWhiteSpace($interfaceValues["short_description"])) {
            $errors.Add("Missing 'short_description' in $openAiPath")
        }
        if (-not $interfaceValues.ContainsKey("default_prompt") -or [string]::IsNullOrWhiteSpace($interfaceValues["default_prompt"])) {
            $errors.Add("Missing 'default_prompt' in $openAiPath")
        } elseif ($interfaceValues["default_prompt"] -notmatch [regex]::Escape("`$$name")) {
            $errors.Add("Default prompt in $openAiPath does not mention the skill invocation token: `$$name")
        }
    }
}

# Keep the implementation workflow's explicit routing inventory synchronized
# with every stack skill declared by the collection manifest.
$implementSkillPath = Join-Path $skillsRoot "implement-change\SKILL.md"
if (Test-Path -LiteralPath $implementSkillPath -PathType Leaf) {
    $implementSkillContent = Get-Content -LiteralPath $implementSkillPath -Raw
    foreach ($stackName in $stackNames) {
        if ($implementSkillContent -notmatch [regex]::Escape("``$stackName``")) {
            $errors.Add("implement-change routing does not mention stack skill '$stackName'")
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { [Console]::Error.WriteLine($_) }
    exit 1
}

$skillCount = (Get-ChildItem -LiteralPath $skillsRoot -Directory).Count
$versionStr = if ($manifest) { $manifest.version } else { "unknown" }
Write-Output "Validated $skillCount skills from skillset.json version $versionStr."
exit 0
