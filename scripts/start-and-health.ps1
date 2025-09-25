$ErrorActionPreference = 'SilentlyContinue'

# stop any existing node
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# start app
$proc = Start-Process node -ArgumentList 'server.js' -PassThru -WindowStyle Hidden
Set-Content -Encoding ascii app.pid $proc.Id

# wait and check health
Start-Sleep -Seconds 2
try {
  (Invoke-WebRequest -UseBasicParsing http://localhost:3000/health).Content | Set-Content -Encoding ascii health.json
} catch {
  '' | Set-Content -Encoding ascii health.json
}

# gate: fail if not UP
$c = Get-Content -Raw health.json | ConvertFrom-Json
if ($c.status -ne 'UP') {
  Write-Host 'HEALTH BAD:'
  Write-Host ($c | ConvertTo-Json -Compress)
  exit 1
}
exit 0
