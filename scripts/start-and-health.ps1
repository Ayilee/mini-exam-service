# Starts server.js, writes app.pid, fetches /health to health.json (does NOT gate)
$ErrorActionPreference = 'SilentlyContinue'

# stop any old node
Get-Process -Name node | Stop-Process -Force

# start app
$ErrorActionPreference = 'Stop'
$proc = Start-Process node -ArgumentList 'server.js' -PassThru -WindowStyle Hidden
Set-Content -Encoding ascii app.pid $proc.Id

Start-Sleep -Seconds 2

try {
  (Invoke-WebRequest -UseBasicParsing http://localhost:3000/health).Content |
    Set-Content -Encoding ascii health.json
} catch {
  '' | Set-Content -Encoding ascii health.json
}
exit 0
