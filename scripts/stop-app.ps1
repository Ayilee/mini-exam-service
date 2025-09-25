$ErrorActionPreference = 'SilentlyContinue'

if (Test-Path app.pid) {
  Get-Content app.pid | ForEach-Object {
    try { Stop-Process -Id $_ -Force } catch {}
  }
}
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
exit 0
