# Arrête TOUS les serveurs sur le port 8000 et relance l'API avec le panneau admin à jour.
$ErrorActionPreference = "Stop"
$backend = Split-Path $PSScriptRoot -Parent

Write-Host "Arret des processus sur le port 8000..." -ForegroundColor Yellow
for ($i = 0; $i -lt 3; $i++) {
    Get-NetTCPConnection -LocalPort 8000 -ErrorAction SilentlyContinue |
        ForEach-Object {
            Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
        }
    Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match 'uvicorn\s+app\.main:app' } |
        ForEach-Object {
            Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
        }
    Start-Sleep -Seconds 2
}

$still = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if ($still) {
    Write-Host "ATTENTION: le port 8000 est encore occupe. Fermez les fenetres uvicorn manuellement." -ForegroundColor Red
} else {
    Write-Host "Port 8000 libre." -ForegroundColor Green
}

Set-Location $backend
Write-Host ""
Write-Host "Demarrage API..." -ForegroundColor Cyan
Write-Host "  Login admin : http://127.0.0.1:8000/admin/login" -ForegroundColor White
Write-Host "  Dashboard   : http://127.0.0.1:8000/admin/dashboard" -ForegroundColor White
Write-Host "  Test routes : http://127.0.0.1:8000/admin/ping" -ForegroundColor Gray
Write-Host ""
& ".\.venv\Scripts\uvicorn.exe" app.main:app --host 0.0.0.0 --port 8000 --reload
