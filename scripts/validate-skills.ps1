[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$collectionRoot = Split-Path -Parent $PSScriptRoot
$skillsRoot = Join-Path $collectionRoot "skills"
$manifestPath = Join-Path $collectionRoot "skillset.json"
$errors = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $skillsRoot -PathType Container)) {
    throw "Skills directory does not exist: $skillsRoot"
}
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "Manifest does not exist: $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$declaredNames = @($manifest.skills | ForEach-Object { $_.name } | Sort-Object)
$actualNames = @(Get-ChildItem -LiteralPath $skillsRoot -Directory | ForEach-Object { $_.Name } | Sort-Object)

foreach ($missing in @($declaredNames | Where-Object { $_ -notin $actualNames })) {
    $errors.Add("Manifest declares missing skill directory: $missing")
}
foreach ($undeclared in @($actualNames | Where-Object { $_ -notin $declaredNames })) {
    $errors.Add("Skill directory is not declared in skillset.json: $undeclared")
}

foreach ($skillDirectory in Get-ChildItem -LiteralPath $skillsRoot -Directory) {
    $name = $skillDirectory.Name
    if ($name -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$' -or $name.Length -gt 64) {
        $errors.Add("Invalid skill directory name: $name")
    }

    $skillPath = Join-Path $skillDirectory.FullName "SKILL.md"
    if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
        $errors.Add("Missing SKILL.md: $name")
        continue
    }

    $content = Get-Content -LiteralPath $skillPath -Raw
    if ($content -notmatch '(?s)^---\s*\r?\n.*?\r?\n---\s*\r?\n') {
        $errors.Add("Missing or invalid YAML frontmatter: $name")
    }
    if ($content -notmatch "(?m)^name:\s*$([regex]::Escape($name))\s*$") {
        $errors.Add("Frontmatter name does not match directory: $name")
    }
    if ($content -notmatch '(?m)^description:\s*\S.+$') {
        $errors.Add("Missing one-line description: $name")
    }
    if ($content -match '(?i)TODO|REPLACE_WITH|PLACEHOLDER') {
        $errors.Add("Unfinished scaffold marker in SKILL.md: $name")
    }

    $openAiPath = Join-Path $skillDirectory.FullName "agents\openai.yaml"
    if (-not (Test-Path -LiteralPath $openAiPath -PathType Leaf)) {
        $errors.Add("Missing agents/openai.yaml: $name")
        continue
    }
    $openAiContent = Get-Content -LiteralPath $openAiPath -Raw
    if ($openAiContent -notmatch [regex]::Escape("`$$name")) {
        $errors.Add(("Default prompt does not mention the skill invocation token: {0}" -f $name))
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "Validated $($actualNames.Count) skills from skillset.json version $($manifest.version)."
