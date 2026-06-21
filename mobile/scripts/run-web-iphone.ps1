# SombaTeka — Web accessible depuis iPhone (même Wi‑Fi), sans erreurs DWDS/debug.
$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$backend = Join-Path $root "backend"
$mobile = Join-Path $root "mobile"

function Get-LanIPv4 {
    $candidates = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notmatch '^127\.' -and
            $_.PrefixOrigin -ne 'WellKnown' -and
            (
                $_.IPAddress -match '^192\.168\.' -or
                $_.IPAddress -match '^10\.' -or
                $_.IPAddress -match '^172\.(1[6-9]|2\d|3[0-1])\.'
            )
        } |
        Sort-Object -Property InterfaceMetric
    if ($candidates) { return ($candidates | Select-Object -First 1).IPAddress }
    return $null
}

foreach ($port in 8000, 8080, 8081, 8082) {
    Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
        ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
}
Start-Sleep -Seconds 1

$lanIp = Get-LanIPv4
if (-not $lanIp) {
    Write-Warning "IP LAN introuvable. Utilisez l'IP affichée dans ipconfig (carte Wi‑Fi)."
    $lanIp = "127.0.0.1"
}

Write-Host ""
Write-Host "=== SombaTeka — acces iPhone (release, pas de WebSocket DWDS) ===" -ForegroundColor Cyan
Write-Host "API (PC + iPhone) : http://${lanIp}:8000"
Write-Host "App Web (iPhone)  : http://${lanIp}:8080"
Write-Host "Swagger           : http://${lanIp}:8000/docs"
Write-Host ""
Write-Host "Sur iPhone (Safari, meme Wi-Fi) : http://${lanIp}:8080"
Write-Host "Si ca ne charge pas : pare-feu Windows -> autoriser TCP 8000 et 8080"
Write-Host ""

$uvicorn = Join-Path $backend ".venv\Scripts\uvicorn.exe"
if (-not (Test-Path $uvicorn)) {
    $uvicorn = "uvicorn"
}

Start-Process powershell -ArgumentList @(
    "-NoExit", "-Command",
    "Set-Location '$backend'; & '$uvicorn' app.main:app --host 0.0.0.0 --port 8000 --reload"
) -WindowStyle Normal

Set-Location $mobile
flutter pub get
# --release : pas de DWDS / ws://127.0.0.1/.../$dwdsSseHandler (inutile sur iPhone)
flutter run -d web-server --release --web-hostname 0.0.0.0 --web-port 8080
