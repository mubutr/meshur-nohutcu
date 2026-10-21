# Yerel siralama sunucusunu baslatir. Ilk calistirmada rastgele bir imza anahtari uretir (.secret).
# Kullanim:  powershell -File server\leaderboard\start-local.ps1
$dir = $PSScriptRoot
$secretFile = Join-Path $dir '.secret'
if (-not (Test-Path $secretFile)) {
  $bytes = New-Object byte[] 32
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  ($bytes | ForEach-Object { $_.ToString('x2') }) -join '' | Set-Content -NoNewline -Encoding ascii $secretFile
}
$env:SECRET = (Get-Content -Raw $secretFile).Trim()
if (-not $env:PORT) { $env:PORT = '8787' }
if (-not $env:DATA_FILE) { $env:DATA_FILE = Join-Path $dir 'data.json' }
Write-Host "Sunucu http://localhost:$($env:PORT)  veri: $($env:DATA_FILE)"
node (Join-Path $dir 'server.js')
