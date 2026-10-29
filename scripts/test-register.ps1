$ts = Get-Date -Format "HHmmss"
$payload = @{
    email        = "test.playstore.$ts@example.com"
    password     = "TestPlay2026!"
    phone_e164   = "+24383$ts"
    display_name = "Test Play"
} | ConvertTo-Json -Compress

Write-Host "POST register ($ts)..."

try {
    $r = Invoke-RestMethod -Uri "https://sombatekaonline.com/api/auth/register" -Method POST -ContentType "application/json" -Body $payload
    Write-Host "OK"
    Write-Host ($r | ConvertTo-Json -Compress)
} catch {
    Write-Host "ERR"
    if ($_.ErrorDetails.Message) {
        Write-Host $_.ErrorDetails.Message
    } else {
        Write-Host $_.Exception.Message
    }
}
