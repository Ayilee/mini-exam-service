$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath 'health.json')) {
  Write-Host 'health.json not found'
  exit 1
}
try {
  $c = Get-Content -Raw health.json | ConvertFrom-Json
} catch {
  Write-Host 'health.json is not valid JSON'
  exit 1
}
if ($c.status -eq 'UP') {
  Write-Host 'HEALTH OK: UP'
  exit 0
} else {
  Write-Host 'HEALTH BAD:'
  Write-Host ($c | ConvertTo-Json -Compress)
  exit 1
}
