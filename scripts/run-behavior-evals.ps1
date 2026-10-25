[CmdletBinding()]
param(
    # Three runs settle a case: at one run a single split vote of the judge decides it.
    [ValidateRange(1, 10)][int]$Runs = 3,
    # The share of a case's runs that must pass; 0.6 is two runs of three.
    [ValidateRange(0.0, 1.0)][double]$Threshold = 0.6,
    # Three runs of every case, with and without the collection, came to about USD 4.
    [ValidateRange(0.01, 100.0)][double]$MaxCostUsd = 6.00,
    # The model that grades the answers; the CLI's own choice when not given.
    [string]$JudgeModel,
    # Only the cases whose name matches this glob, for example "review-*".
    [string]$Case
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$collectionRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot "validate-evals.ps1")
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    throw "Claude Code CLI is required to execute behavioral evals."
}

$evalArguments = @($collectionRoot, "--no-publish", "--runs", $Runs, "--threshold", $Threshold, "--max-cost-usd", $MaxCostUsd)
if ($JudgeModel) { $evalArguments += @("--judge-model", $JudgeModel) }
if ($Case) { $evalArguments += @("--case", $Case) }

Write-Warning "This command invokes a model and may incur up to USD $MaxCostUsd in usage."
# On Windows PowerShell 5.1, with output redirected, "Stop" turns the CLI's notices on stderr
# into a terminating error; the exit code is what decides.
$ErrorActionPreference = "Continue"
& claude plugin eval @evalArguments
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0) { throw "Claude behavioral evals failed with exit code $LASTEXITCODE." }
