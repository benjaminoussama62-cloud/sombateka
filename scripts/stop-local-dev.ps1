# Arrete les serveurs de dev locaux (API Flutter web) avant de quitter.
$ErrorActionPreference = "SilentlyContinue"
$ports = 8000, 8080, 8081, 8082

foreach ($port in $ports) {
    $conns = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    foreach ($c in $conns) {
        Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue
        Write-Host "Port $port arrete (PID $($c.OwningProcess))" -ForegroundColor Green
    }
}

Write-Host "Dev local arrete." -ForegroundColor Cyan
