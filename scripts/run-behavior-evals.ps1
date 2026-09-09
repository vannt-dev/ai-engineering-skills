[CmdletBinding()]
param(
    [ValidateRange(1, 10)][int]$Runs = 1,
    [ValidateRange(0.0, 1.0)][double]$Threshold = 0.75,
    [ValidateRange(0.01, 100.0)][double]$MaxCostUsd = 2.00
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$collectionRoot = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot "validate-evals.ps1")
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    throw "Claude Code CLI is required to execute behavioral evals."
}

Write-Warning "This command invokes a model and may incur up to USD $MaxCostUsd in usage."
& claude plugin eval $collectionRoot --no-publish --runs $Runs --threshold $Threshold --max-cost-usd $MaxCostUsd
if ($LASTEXITCODE -ne 0) { throw "Claude behavioral evals failed with exit code $LASTEXITCODE." }
