$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Config = Join-Path $Root 'local.build.ps1'

if (!(Test-Path $Config)) {
  Write-Host "Missing $Config"
  exit 1
}

. $Config

if ([string]::IsNullOrWhiteSpace($CIQ_SDK_BIN)) {
  Write-Host 'CIQ_SDK_BIN is required in local.build.ps1'
  exit 1
}
if ([string]::IsNullOrWhiteSpace($DEVICE_ID)) { $DEVICE_ID = 'fenix7' }

$OutFile = Join-Path $Root 'bin\TopSnipes.prg'
if (!(Test-Path $OutFile)) {
  Write-Host "Missing $OutFile. Run .\scripts\build.ps1 first."
  exit 1
}

& "$CIQ_SDK_BIN\monkeydo.bat" $OutFile $DEVICE_ID
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
