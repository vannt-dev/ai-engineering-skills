[CmdletBinding()]
param(
    [string]$EvalsRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$evalsRoot = if ($EvalsRoot) { $EvalsRoot } else { Join-Path (Split-Path -Parent $PSScriptRoot) "evals" }
$errors = [System.Collections.Generic.List[string]]::new()
if (-not (Test-Path -LiteralPath $evalsRoot -PathType Container)) {
    throw "Evals directory does not exist: $evalsRoot"
}

$cases = @(Get-ChildItem -LiteralPath $evalsRoot -Directory)
if ($cases.Count -lt 4) { $errors.Add("Expected at least 4 behavioral eval cases, found $($cases.Count).") }
foreach ($case in $cases) {
    if ($case.Name -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { $errors.Add("Invalid eval case name: '$($case.Name)'.") }
    $promptPath = Join-Path $case.FullName "prompt.md"
    $gradersRoot = Join-Path $case.FullName "graders"
    if (-not (Test-Path -LiteralPath $promptPath -PathType Leaf)) {
        $errors.Add("Eval '$($case.Name)' is missing prompt.md.")
    } elseif ((Get-Content -LiteralPath $promptPath -Raw).Trim().Length -lt 40) {
        $errors.Add("Eval '$($case.Name)' prompt is too short to be meaningful.")
    }
    $graders = @(if (Test-Path -LiteralPath $gradersRoot -PathType Container) { Get-ChildItem -LiteralPath $gradersRoot -Filter "*.md" -File })
    if ($graders.Count -eq 0) { $errors.Add("Eval '$($case.Name)' has no Markdown grader.") }
    foreach ($grader in $graders) {
        if ((Get-Content -LiteralPath $grader.FullName -Raw).Trim().Length -lt 80) { $errors.Add("Eval grader '$($grader.FullName)' is too short to be meaningful.") }
        # `claude plugin eval` refuses a grader with no frontmatter ("graders: Required"), and the
        # paid eval run is not part of CI, so the structure is checked here.
        $graderLines = @(Get-Content -LiteralPath $grader.FullName)
        $frontmatter = @()
        if ($graderLines.Count -gt 2 -and $graderLines[0].Trim() -eq '---') {
            for ($index = 1; $index -lt $graderLines.Count; $index++) {
                if ($graderLines[$index].Trim() -eq '---') { break }
                $frontmatter += $graderLines[$index]
            }
            if ($index -ge $graderLines.Count) { $frontmatter = @() }
        }
        if (@($frontmatter | Where-Object { $_ -match '^type:\s*\S' }).Count -eq 0) {
            $errors.Add("Eval grader '$($grader.FullName)' needs YAML frontmatter with a 'type' field (for example 'type: llm'); the eval runner cannot load it otherwise.")
        }
    }
}

if ($errors.Count -gt 0) {
    $errors | ForEach-Object { [Console]::Error.WriteLine($_) }
    exit 1
}
Write-Output "Validated $($cases.Count) behavioral eval cases."
exit 0
