$ErrorActionPreference = 'SilentlyContinue'
if (Test-Path app.pid) {
  Get-Content app.pid | ForEach-Object {
    try { Stop-Process -Id $_ -Force } catch {}
  }
  Remove-Item app.pid -Force
}
Get-Process -Name node | Stop-Process -Force
exit 0
