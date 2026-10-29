# Smoke test production SombaTeka - lancer apres chaque deploiement
param(
    [string]$Domain = "sombatekaonline.com",
    [switch]$SkipRegister
)

$ErrorActionPreference = "Stop"
$Base = "https://$Domain"
$failed = @()

function Get-HttpCode {
    param([string]$Url)
    curl.exe -sk -o NUL -w "%{http_code}" $Url 2>$null
}

function Test-Step {
    param([string]$Name, [scriptblock]$Action)
    try {
        & $Action
        Write-Host "  OK  $Name" -ForegroundColor Green
    } catch {
        Write-Host "  FAIL $Name" -ForegroundColor Red
        Write-Host "       $($_.Exception.Message)" -ForegroundColor DarkRed
        if ($_.ErrorDetails.Message) { Write-Host "       $($_.ErrorDetails.Message)" -ForegroundColor DarkRed }
        $script:failed += $Name
    }
}

Write-Host ""
Write-Host "=== Smoke test prod : $Base ===" -ForegroundColor Cyan
Write-Host ""

Test-Step "API /healthz" {
    $h = Invoke-RestMethod -Uri "$Base/healthz" -TimeoutSec 20
    if (-not $h.ok) { throw "healthz ok=false" }
    if ($null -ne $h.PSObject.Properties['db'] -and -not $h.db) { throw "healthz db=false" }
}

Test-Step "Page accueil PWA" {
    $code = Get-HttpCode "$Base/"
    if ($code -ne "200") { throw "HTTP $code" }
}

Test-Step "Headers securite (accueil)" {
    $headers = curl.exe -sIk "$Base/" 2>$null | Out-String
    if ($headers -notmatch "(?i)strict-transport-security") { throw "HSTS manquant" }
    if ($headers -notmatch "(?i)x-frame-options") { throw "X-Frame-Options manquant" }
    if ($headers -notmatch "(?i)x-content-type-options") { throw "X-Content-Type-Options manquant" }
}

Test-Step "Chemins sensibles en 404" {
    foreach ($p in @("/.env", "/.git/config", "/.env.production", "/openapi.json", "/docs")) {
        $code = Get-HttpCode "$Base$p"
        if ($code -ne "404") { throw "$p -> HTTP $code (attendu 404)" }
    }
}

Test-Step "CGU /terms" {
    $code = Get-HttpCode "$Base/terms"
    if ($code -ne "200") { throw "HTTP $code" }
    $html = curl.exe -sk "$Base/terms" 2>$null | Out-String
    if ($html.Length -lt 8000) { throw "terms trop court ($($html.Length) octets)" }
    if ($html -notmatch "SombaTeka") { throw "contenu terms invalide" }
}

Test-Step "Confidentialite /privacy" {
    $code = Get-HttpCode "$Base/privacy"
    if ($code -ne "200") { throw "HTTP $code" }
    $html = curl.exe -sk "$Base/privacy" 2>$null | Out-String
    if ($html.Length -lt 6000) { throw "privacy trop court ($($html.Length) octets)" }
    if ($html -notmatch "SombaTeka") { throw "contenu privacy invalide" }
}

Test-Step "Suppression compte /account-deletion" {
    $code = Get-HttpCode "$Base/account-deletion"
    if ($code -ne "200") { throw "HTTP $code" }
}

Test-Step "Police MaterialIcons (PWA)" {
    $code = Get-HttpCode "$Base/fonts/MaterialIcons-Regular.otf"
    if ($code -ne "200") { throw "HTTP $code - icones PWA cassees" }
}

Test-Step "Admin login protege (401 sans Basic Auth)" {
    # Le panneau staff est derriere une Basic Auth nginx : le public
    # ne doit JAMAIS recevoir la page de login (200 = fuite).
    $code = Get-HttpCode "$Base/admin/login"
    if ($code -ne "401") { throw "HTTP $code - attendu 401 (Basic Auth)" }
}

Test-Step "OpenAPI masque (prod)" {
    $code = Get-HttpCode "$Base/openapi.json"
    if ($code -ne "404") { throw "HTTP $code - openapi doit rester masque en prod" }
}

Test-Step "Auth /me sans token -> 401" {
    $code = Get-HttpCode "$Base/api/auth/me"
    if ($code -notin @("401", "403")) { throw "HTTP $code (attendu 401)" }
}

if (-not $SkipRegister) {
    Test-Step "Inscription API (register)" {
        $rnd = Get-Random -Minimum 1000000 -Maximum 9999999
        $body = @{
            email        = "smoke.$rnd@gmail.com"
            password     = "TestPlay2026!"
            phone_e164   = "+24388$rnd"
            display_name = "Smoke Test"
        } | ConvertTo-Json -Compress
        $res = Invoke-RestMethod -Uri "$Base/api/auth/register" -Method POST -ContentType "application/json" -Body $body -TimeoutSec 30
        if (-not $res.access_token) { throw "pas de access_token" }
    }
}

# Optional uptime heartbeat (Healthchecks.io / similar)
$pingUrl = $env:HEALTHCHECKS_PING_URL
if (-not [string]::IsNullOrWhiteSpace($pingUrl)) {
    Test-Step "Uptime heartbeat" {
        $code = Get-HttpCode $pingUrl
        if ($code -notmatch "^20") { throw "ping HTTP $code" }
    }
}

Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "=== TOUS LES TESTS OK ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== ECHEC : $($failed.Count) test(s) ===" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
