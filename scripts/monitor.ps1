$ErrorActionPreference = 'SilentlyContinue'

Remove-Item -Path monitor.log -ErrorAction SilentlyContinue

for ($i = 1; $i -le 4; $i++) {
  $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
  try {
    $resp = Invoke-WebRequest -UseBasicParsing http://localhost:3000/health
    $code = [int]$resp.StatusCode
    $body = $resp.Content
  } catch {
    $code = 0
    $body = ''
  }
  Add-Content -Encoding ascii -Path monitor.log -Value "$ts status:$code body:$body"
  Start-Sleep -Seconds 30
}
