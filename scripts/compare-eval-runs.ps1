[CmdletBinding()]
param(
    # The earlier run: its folder under evals/results/ or its aggregate-result.json.
    [Parameter(Mandatory = $true)][string]$Baseline,
    # The later run, given the same way.
    [Parameter(Mandatory = $true)][string]$Candidate,
    # A case passes when this share of its runs with the collection passed. Both runs are judged on
    # it, because a run's own threshold can differ (0 lets every case pass). 0.6 is the runner's.
    [ValidateRange(0.0, 1.0)][double]$Threshold = 0.6,
    # Text for the console, Markdown for a pull request comment, Json for other tools.
    [ValidateSet("Text", "Markdown", "Json")][string]$Format = "Text"
)

# Exit codes: 0 no case regressed, 1 a case that passed in the baseline fails in the candidate,
# 2 a result could not be read.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$invariant = [System.Globalization.CultureInfo]::InvariantCulture

function Get-Field($Object, [string]$Name) {
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $null
}

function Read-EvalRun([string]$Path) {
    $file = $Path
    if (Test-Path -LiteralPath $Path -PathType Container) { $file = Join-Path $Path "aggregate-result.json" }
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "No eval result at '$Path'." }
    try {
        $run = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
    } catch {
        throw "'$file' is not JSON: $($_.Exception.Message)"
    }
    $version = Get-Field $run "schemaVersion"
    if ($version -ne 1) { throw "'$file' has schemaVersion '$version'; this script reads version 1." }
    if ($null -eq (Get-Field $run "cases")) { throw "'$file' has no cases." }

    $cases = @{}
    foreach ($case in @($run.cases)) {
        $arms = Get-Field $case "arms"
        $with = @(Get-Field $arms "with")
        $without = @(Get-Field $arms "without")
        $aggregates = Get-Field $case "aggregates"
        $all = @($with + $without | Where-Object { $null -ne $_ })
        $costs = @($all | ForEach-Object { [double](Get-Field $_ "costUsd") + [double](Get-Field $_ "judgeCostUsd") })
        $withRuns = @($with | Where-Object { $null -ne $_ })
        $cases[$case.name] = [pscustomobject]@{
            PassRate = [double](Get-Field $aggregates "passRate")
            PassRateWithout = Get-Field $aggregates "passRateWithout"
            Runs = $withRuns.Count
            CostUsd = ($costs | Measure-Object -Sum).Sum
            MeanSeconds = Get-Mean @($withRuns | ForEach-Object { Get-Field $_ "durationSeconds" })
            MeanTurns = Get-Mean @($withRuns | ForEach-Object { Get-Field $_ "turns" })
        }
    }
    $startedAt = Get-Field $run "startedAt"
    # PowerShell 7 reads an ISO 8601 string in JSON as a date; print it as the report wrote it.
    if ($startedAt -is [datetime]) {
        $startedAt = $startedAt.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ", $invariant)
    }
    $plugins = @(Get-Field (Get-Field $run "suite") "plugins")
    $plugin = $plugins | Where-Object { $null -ne $_ } | Select-Object -First 1
    $passed = @($cases.Values | Where-Object { $_.PassRate -ge $Threshold }).Count
    return [pscustomobject]@{
        Path = $Path
        StartedAt = $startedAt
        ClaudeVersion = Get-Field $run "claudeVersion"
        PluginVersion = Get-Field $plugin "version"
        Partial = [bool](Get-Field $run "partial")
        CostUsd = Get-Field $run "costUsd"
        DurationSeconds = Get-Field $run "durationSeconds"
        CasesTotal = $cases.Count
        CasesPassed = $passed
        Cases = $cases
    }
}

function Get-Mean([object[]]$Values) {
    $numbers = @($Values | Where-Object { $null -ne $_ })
    if ($numbers.Count -eq 0) { return $null }
    return ($numbers | Measure-Object -Average).Average
}

function New-Change($Before, $After) {
    $delta = $null
    if ($null -ne $Before -and $null -ne $After) { $delta = [double]$After - [double]$Before }
    return [pscustomobject][ordered]@{ baseline = $Before; candidate = $After; delta = $delta }
}

function Format-Rate($Value) {
    if ($null -eq $Value) { return "-" }
    return ([Math]::Round([double]$Value * 100)).ToString($invariant) + "%"
}

function Format-RateChange($Change) {
    if ($null -eq $Change.baseline) { return Format-Rate $Change.candidate }
    if ($null -eq $Change.candidate) { return Format-Rate $Change.baseline }
    return "$(Format-Rate $Change.baseline) -> $(Format-Rate $Change.candidate)"
}

function Format-Delta($Change, [string]$Unit, [string]$Pattern) {
    if ($null -eq $Change.delta) { return "-" }
    $magnitude = [Math]::Abs($Change.delta).ToString($Pattern, $invariant)
    # A change that rounds to zero reads "+0s", not "-0s".
    $sign = if ($Change.delta -lt 0 -and [double]::Parse($magnitude, $invariant) -ne 0) { "-" } else { "+" }
    if ($Unit -eq "$") { return "$sign`$$magnitude" }
    return "$sign$magnitude$Unit"
}

try {
    $before = Read-EvalRun $Baseline
    $after = Read-EvalRun $Candidate
} catch {
    [Console]::Error.WriteLine("compare-eval-runs: $($_.Exception.Message)")
    exit 2
}

$order = @{ "regressed" = 0; "worse" = 1; "fixed" = 2; "better" = 3; "same" = 4; "baseline-only" = 5; "candidate-only" = 6 }
$rows = foreach ($name in @(@($before.Cases.Keys) + @($after.Cases.Keys) | Sort-Object -Unique)) {
    $old = $before.Cases[$name]
    $new = $after.Cases[$name]
    $status = if ($null -eq $new) { "baseline-only" }
    elseif ($null -eq $old) { "candidate-only" }
    else {
        $wasPassing = $old.PassRate -ge $Threshold
        $isPassing = $new.PassRate -ge $Threshold
        if ($wasPassing -and -not $isPassing) { "regressed" }
        elseif ($isPassing -and -not $wasPassing) { "fixed" }
        elseif ($new.PassRate -lt $old.PassRate) { "worse" }
        elseif ($new.PassRate -gt $old.PassRate) { "better" }
        else { "same" }
    }
    $pick = { param($Record, [string]$Field) if ($null -eq $Record) { $null } else { $Record.$Field } }
    [pscustomobject][ordered]@{
        name = $name
        status = $status
        with = New-Change (& $pick $old "PassRate") (& $pick $new "PassRate")
        without = New-Change (& $pick $old "PassRateWithout") (& $pick $new "PassRateWithout")
        runs = New-Change (& $pick $old "Runs") (& $pick $new "Runs")
        costUsd = New-Change (& $pick $old "CostUsd") (& $pick $new "CostUsd")
        meanSeconds = New-Change (& $pick $old "MeanSeconds") (& $pick $new "MeanSeconds")
        meanTurns = New-Change (& $pick $old "MeanTurns") (& $pick $new "MeanTurns")
    }
}
$rows = @($rows | Sort-Object @{ Expression = { $order[$_.status] } }, @{ Expression = { $_.name } })
$regressions = @($rows | Where-Object { $_.status -eq "regressed" }).Count
$counts = @(foreach ($status in @("regressed", "worse", "fixed", "better", "same", "baseline-only", "candidate-only")) {
        $count = @($rows | Where-Object { $_.status -eq $status }).Count
        if ($count -gt 0) { "$count $status" }
    }) -join ", "

function Get-RunLabel($Run) {
    $label = "$($Run.Path) (started $($Run.StartedAt), Claude Code $($Run.ClaudeVersion), collection $($Run.PluginVersion))"
    if ($Run.Partial) { $label += " PARTIAL RUN" }
    return $label
}

$summary = @(
    "Cases passed: $($before.CasesPassed)/$($before.CasesTotal) -> $($after.CasesPassed)/$($after.CasesTotal)",
    "run cost: $(Format-Delta (New-Change $before.CostUsd $after.CostUsd) '$' '0.00')",
    "run time: $(Format-Delta (New-Change $before.DurationSeconds $after.DurationSeconds) 's' '0')"
) -join "; "
$threshold = $Threshold.ToString($invariant)
$headers = @("Status", "Case", "With", "Without", "Runs", "Cost", "Time/run", "Turns/run")
$cells = @(foreach ($row in $rows) {
        , @($row.status, $row.name, (Format-RateChange $row.with), (Format-RateChange $row.without),
            (@($row.runs.baseline, $row.runs.candidate | Where-Object { $null -ne $_ }) -join " -> "),
            (Format-Delta $row.costUsd '$' '0.00'), (Format-Delta $row.meanSeconds 's' '0'),
            (Format-Delta $row.meanTurns '' '0.0'))
    })

switch ($Format) {
    "Json" {
        [ordered]@{
            baseline = [ordered]@{ path = $before.Path; startedAt = $before.StartedAt; claudeVersion = $before.ClaudeVersion; collectionVersion = $before.PluginVersion; partial = $before.Partial; casesPassed = $before.CasesPassed; casesTotal = $before.CasesTotal; costUsd = $before.CostUsd; durationSeconds = $before.DurationSeconds }
            candidate = [ordered]@{ path = $after.Path; startedAt = $after.StartedAt; claudeVersion = $after.ClaudeVersion; collectionVersion = $after.PluginVersion; partial = $after.Partial; casesPassed = $after.CasesPassed; casesTotal = $after.CasesTotal; costUsd = $after.CostUsd; durationSeconds = $after.DurationSeconds }
            threshold = $Threshold
            regressions = $regressions
            cases = $rows
        } | ConvertTo-Json -Depth 6
    }
    "Markdown" {
        "### Eval comparison"
        ""
        "- Baseline: $(Get-RunLabel $before)"
        "- Candidate: $(Get-RunLabel $after)"
        "- $summary"
        "- A case passes at a pass rate of $threshold or more with the collection; $counts."
        ""
        "| $($headers -join ' | ') |"
        "|$((@($headers | ForEach-Object { ' --- ' })) -join '|')|"
        foreach ($line in $cells) {
            $line[1] = "``$($line[1])``"
            "| $($line -join ' | ') |"
        }
    }
    default {
        "Baseline:  $(Get-RunLabel $before)"
        "Candidate: $(Get-RunLabel $after)"
        $summary
        "A case passes at a pass rate of $threshold or more with the collection; $counts."
        ""
        $widths = @(for ($column = 0; $column -lt $headers.Count; $column++) {
                (@($headers[$column]) + @($cells | ForEach-Object { $_[$column] }) | Measure-Object -Property Length -Maximum).Maximum
            })
        $all = @(, $headers) + $cells
        foreach ($line in $all) {
            (@(for ($column = 0; $column -lt $headers.Count; $column++) { "$($line[$column])".PadRight($widths[$column]) }) -join "  ").TrimEnd()
        }
    }
}

if ($regressions -gt 0) { exit 1 }
exit 0
