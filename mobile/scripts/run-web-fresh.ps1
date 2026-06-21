# Relance Flutter Web avec cache vide (corrige Image.file sur Web)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\..

Write-Host "Arret des ports 8080-8082..."
foreach ($port in 8080, 8081, 8082) {
  Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
    ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
}

Write-Host "flutter clean..."
flutter clean
flutter pub get

Write-Host "Lancement web (build v3) sur http://127.0.0.1:8082"
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8082 `
  --dart-define=ST_API_BASE_URL=http://127.0.0.1:8000
