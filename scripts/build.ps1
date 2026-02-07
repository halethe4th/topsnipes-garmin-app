$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Config = Join-Path $Root 'local.build.ps1'

if (!(Test-Path $Config)) {
  Write-Host "Missing $Config"
  Write-Host "Copy local.build.ps1.example to local.build.ps1 and set your paths."
  exit 1
}

. $Config

if ([string]::IsNullOrWhiteSpace($CIQ_SDK_BIN) -or [string]::IsNullOrWhiteSpace($DEVELOPER_KEY_PATH)) {
  Write-Host 'CIQ_SDK_BIN and DEVELOPER_KEY_PATH are required in local.build.ps1'
  exit 1
}

if ([string]::IsNullOrWhiteSpace($DEVICE_ID)) { $DEVICE_ID = 'fenix7' }

$OutDir = Join-Path $Root 'bin'
$OutFile = Join-Path $OutDir 'TopSnipes.prg'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

& "$CIQ_SDK_BIN\monkeyc.bat" -f "$Root\monkey.jungle" -o $OutFile -y $DEVELOPER_KEY_PATH -d $DEVICE_ID
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Build complete: $OutFile"
