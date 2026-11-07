param(
  [Parameter(Mandatory=$true)][string]$BaseApk,
  [Parameter(Mandatory=$true)][string]$Arm64SplitApk,
  [string]$OutputDirectory = ".\jindoblu-analysis",
  [switch]$RunReaAndroidInspection
)
$ErrorActionPreference = "Stop"

function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found on PATH."
  }
}
Require-Command "python"
if (-not (Test-Path -LiteralPath $BaseApk -PathType Leaf)) { throw "base APK not found: $BaseApk" }
if (-not (Test-Path -LiteralPath $Arm64SplitApk -PathType Leaf)) { throw "ARM64 split APK not found: $Arm64SplitApk" }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Analyzer = Join-Path $ScriptDir "analyze_apks.py"
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
python $Analyzer --base $BaseApk --split $Arm64SplitApk --out $OutputDirectory
if ($LASTEXITCODE -ne 0) { throw "Offline APK inventory failed with exit code $LASTEXITCODE" }

if ($RunReaAndroidInspection) {
  Require-Command "node"
  Require-Command "npm"
  $nodeVersionText = (& node -p "process.versions.node").Trim()
  $nodeVersion = [version]$nodeVersionText
  $supportedNode = (($nodeVersion.Major -eq 22 -and $nodeVersion -ge [version]"22.19.0") -or
                    ($nodeVersion.Major -eq 24 -and $nodeVersion -ge [version]"24.11.0") -or
                    ($nodeVersion.Major -ge 26))
  if (-not $supportedNode) {
    throw "REA requires Node 22.19+ (22.x), 24.11+ (24.x), or 26+. Found $nodeVersionText. Upgrade Node, reopen PowerShell, then rerun."
  }
  $jarDir = Join-Path $HOME ".local\share\rea\android"
  $jar = Join-Path $jarDir "jadx-headless-mcp-0.7.1-all.jar"
  New-Item -ItemType Directory -Force -Path $jarDir | Out-Null
  if (-not (Test-Path -LiteralPath $jar -PathType Leaf)) {
    $uri = "https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar"
    Invoke-WebRequest -Uri $uri -OutFile $jar
  }
  $expected = "6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75"
  $actual = (Get-FileHash -LiteralPath $jar -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $expected) { throw "JADX JAR SHA-256 mismatch. Expected $expected; got $actual. File retained for inspection, not used." }
  $env:REA_JADX_MCP_JAR = $jar
  $reaOut = Join-Path (Resolve-Path $OutputDirectory) "rea-base-package.txt"
  # Inspect only the base APK for Android/DEX package information. The ABI split is
  # not a standalone base package; neither command decompiles Unity IL2CPP native methods.
  & npx --yes rea-agents@latest inspect-android-package (Resolve-Path $BaseApk).Path 2>&1 | Tee-Object -FilePath $reaOut
  if ($LASTEXITCODE -ne 0) { throw "REA package inspection failed with exit code $LASTEXITCODE. See $reaOut" }
  Write-Host "REA Android package report: $reaOut"
}
Write-Host "Done. Open $(Join-Path (Resolve-Path $OutputDirectory).Path 'COMBINED_INVENTORY.md')"
