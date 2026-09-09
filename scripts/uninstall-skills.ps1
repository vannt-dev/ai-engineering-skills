[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet("Codex", "Claude", "OpenCode", "Antigravity", "Universal")]
    [string]$Target = "Universal",

    [ValidateSet("User", "Project")]
    [string]$Scope = "User",

    [string]$ProjectRoot,

    [string]$UserHome,

    [Parameter(DontShow)]
    [ValidateRange(0, 10000)]
    [int]$TestFailAfterMove = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Scope -eq "User") {
    $root = if ($UserHome) { $UserHome } elseif ($env:USERPROFILE) { $env:USERPROFILE } elseif ($env:HOME) { $env:HOME } else { throw "Could not determine User home directory. Specify -UserHome." }
    $root = [System.IO.Path]::GetFullPath($root)
} else {
    if ([string]::IsNullOrWhiteSpace($ProjectRoot) -or -not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
        throw "ProjectRoot must name an existing directory when Scope is 'Project'."
    }
    $root = [System.IO.Path]::GetFullPath($ProjectRoot)
}

$destinations = [System.Collections.Generic.List[hashtable]]::new()
function Add-Flat([string]$Path) { $destinations.Add(@{ Type = "CanonicalFlat"; Path = $Path }) }
function Add-Claude([string]$Path) { $destinations.Add(@{ Type = "ClaudeNestedPlugin"; Path = $Path }) }

if ($Scope -eq "User") {
    switch ($Target) {
        "Codex"       { Add-Flat (Join-Path $root ".agents\skills") }
        "Claude"      { Add-Claude (Join-Path $root ".claude\skills\ai-engineering-skills") }
        "OpenCode"    { Add-Flat (Join-Path $root ".config\opencode\skills") }
        "Antigravity" { Add-Flat (Join-Path $root ".gemini\config\skills") }
        "Universal"   {
            Add-Flat (Join-Path $root ".agents\skills")
            Add-Claude (Join-Path $root ".claude\skills\ai-engineering-skills")
            Add-Flat (Join-Path $root ".gemini\config\skills")
        }
    }
} else {
    switch ($Target) {
        "Codex"       { Add-Flat (Join-Path $root ".agents\skills") }
        "Claude"      { Add-Claude (Join-Path $root ".claude\skills\ai-engineering-skills") }
        "OpenCode"    { Add-Flat (Join-Path $root ".opencode\skills") }
        "Antigravity" { Add-Flat (Join-Path $root ".agents\skills") }
        "Universal"   {
            Add-Flat (Join-Path $root ".agents\skills")
            Add-Claude (Join-Path $root ".claude\skills\ai-engineering-skills")
        }
    }
}

function Read-Receipt([string]$ReceiptPath) {
    if (-not (Test-Path -LiteralPath $ReceiptPath -PathType Leaf)) { return $null }
    try { $receipt = Get-Content -LiteralPath $ReceiptPath -Raw | ConvertFrom-Json } catch { throw "Refusing to uninstall because receipt is invalid JSON: '$ReceiptPath'" }
    if (-not $receipt.PSObject.Properties["collection"] -or $receipt.collection -ne "ai-engineering-skills") {
        throw "Refusing to uninstall because receipt does not identify ai-engineering-skills: '$ReceiptPath'"
    }
    if (-not $receipt.PSObject.Properties["skills"] -or $receipt.skills -isnot [System.Array]) {
        throw "Refusing to uninstall because receipt has no skills list: '$ReceiptPath'"
    }
    return $receipt
}

# Preflight every receipt and build the complete removal plan before changing disk.
$removals = [System.Collections.Generic.List[string]]::new()
foreach ($dest in $destinations) {
    $receiptPath = if ($dest.Type -eq "CanonicalFlat") { Join-Path $dest.Path ".ai-engineering-skills.receipt.json" } else { Join-Path $dest.Path ".ai-engineering-skills.receipt.json" }
    $receipt = Read-Receipt $receiptPath
    if (-not $receipt) {
        Write-Warning "No managed installation receipt found at '$receiptPath'; nothing will be removed there."
        continue
    }

    if ($dest.Type -eq "ClaudeNestedPlugin") {
        $removals.Add($dest.Path)
        continue
    }

    $destFull = [System.IO.Path]::GetFullPath($dest.Path)
    $destPrefix = $destFull.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    foreach ($skillName in @($receipt.skills)) {
        if ($skillName -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { throw "Receipt '$receiptPath' contains unsafe skill name '$skillName'." }
        $skillPath = [System.IO.Path]::GetFullPath((Join-Path $destFull $skillName))
        if (-not $skillPath.StartsWith($destPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw "Receipt path escapes installation root: '$skillName'." }
        if (Test-Path -LiteralPath $skillPath) { $removals.Add($skillPath) }
    }
    $removals.Add($receiptPath)
}

if ($removals.Count -eq 0) {
    Write-Output "No managed ai-engineering-skills installation found for the selected target and scope."
    return
}

foreach ($path in $removals) {
    if (-not $PSCmdlet.ShouldProcess($path, "Uninstall receipt-managed content") -and -not $WhatIfPreference) { return }
}
if ($WhatIfPreference) { return }

$transactionId = [System.Guid]::NewGuid().ToString("N")
$moved = [System.Collections.Generic.List[hashtable]]::new()
$moveCount = 0
try {
    foreach ($path in $removals) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $quarantine = "$path.ai-engineering-skills-uninstall-$transactionId"
        Move-Item -LiteralPath $path -Destination $quarantine
        $moved.Add(@{ Original = $path; Quarantine = $quarantine })
        $moveCount++
        if ($TestFailAfterMove -gt 0 -and $moveCount -eq $TestFailAfterMove) { throw "Injected uninstaller failure after move $moveCount." }
    }
} catch {
    for ($i = $moved.Count - 1; $i -ge 0; $i--) {
        Move-Item -LiteralPath $moved[$i].Quarantine -Destination $moved[$i].Original -ErrorAction SilentlyContinue
    }
    throw "Uninstall transaction failed and was rolled back: $($_.Exception.Message)"
}

foreach ($entry in $moved) {
    try { Remove-Item -LiteralPath $entry.Quarantine -Recurse -Force } catch { Write-Warning "Content was uninstalled but quarantine cleanup failed for '$($entry.Quarantine)': $($_.Exception.Message)" }
}
Write-Output "Removed $($moved.Count) receipt-managed path(s); unrelated content was preserved."
