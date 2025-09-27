$ErrorActionPreference = 'SilentlyContinue'
Get-Process -Name node | Stop-Process -Force
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
