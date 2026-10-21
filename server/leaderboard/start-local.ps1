# Yerel siralama sunucusunu baslatir. Ilk calistirmada rastgele bir imza anahtari (.secret) ve
# test amacli yonetim sayfasi anahtari (.admin) uretir.
# Kullanim:  powershell -File server\leaderboard\start-local.ps1
# Yonetim sayfasi:  http://localhost:8787/admin   (anahtar .admin dosyasinda)
$dir = $PSScriptRoot
function New-Key($file) {
  if (-not (Test-Path $file)) {
    $bytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    ($bytes | ForEach-Object { $_.ToString('x2') }) -join '' | Set-Content -NoNewline -Encoding ascii $file
  }
  (Get-Content -Raw $file).Trim()
}
$env:SECRET = New-Key (Join-Path $dir '.secret')
# Canliya cikarken ADMIN_TOKEN'i verme: yonetim sayfasi ve API kapali kalir.
if (-not $env:ADMIN_TOKEN) { $env:ADMIN_TOKEN = New-Key (Join-Path $dir '.admin') }
if (-not $env:PORT) { $env:PORT = '8787' }
if (-not $env:DATA_FILE) { $env:DATA_FILE = Join-Path $dir 'data.json' }
Write-Host "Sunucu http://localhost:$($env:PORT)  veri: $($env:DATA_FILE)"
Write-Host "Yonetim (TEST): http://localhost:$($env:PORT)/admin   anahtar: $(Join-Path $dir '.admin') dosyasinda"
node (Join-Path $dir 'server.js')
