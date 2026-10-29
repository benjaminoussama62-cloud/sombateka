# SombaTeka — migration sslip.io → sombatekaonline.com
param(
    [string]$VpsHost = "root@164.90.214.206",
    [string]$Domain = "sombatekaonline.com",
    [string]$VpsIp = "164.90.214.206",
    [switch]$SkipDnsPrompt
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent

function Get-DomainIpv4 {
    param([string]$Name)
    foreach ($type in @("A", "ANY")) {
        $records = @(Resolve-DnsName -Name $Name -Type $type -DnsOnly -ErrorAction SilentlyContinue)
        foreach ($r in $records) {
            if ($null -ne $r.IPAddress -and $r.IPAddress -match '^\d+\.\d+\.\d+\.\d+$') {
                return $r.IPAddress
            }
        }
    }
    return $null
}

Write-Host ""
Write-Host "=== SombaTeka — setup $Domain ===" -ForegroundColor Cyan
Write-Host ""

if (-not $SkipDnsPrompt) {
    Write-Host "ETAPE 1 — Cloudflare DNS (fais ca dans ton navigateur) :" -ForegroundColor Yellow
    Write-Host "  1. dash.cloudflare.com → sombatekaonline.com → DNS"
    Write-Host "  2. A    @    $VpsIp    Proxy = DNS only (nuage GRIS)"
    Write-Host "  3. CNAME www  $Domain   Proxy = DNS only (nuage GRIS)"
    Write-Host "  4. Attends 2-5 min puis appuie Entree ici"
    Write-Host ""
    Read-Host "Appuie Entree quand le DNS est configure" | Out-Null
}

Write-Host ""
Write-Host "Verification DNS..." -ForegroundColor Yellow
$resolved = Get-DomainIpv4 -Name $Domain
if (-not $resolved) {
    Write-Host "  ATTENTION: impossible de resoudre $Domain (propagation en cours ?)" -ForegroundColor Red
    Write-Host "  Continue quand meme ? (o/N)" -ForegroundColor Yellow
    $c = Read-Host
    if ($c -notmatch '^[oOyY]') { exit 1 }
} elseif ($resolved -ne $VpsIp) {
    Write-Host "  ATTENTION: $Domain -> $resolved (attendu $VpsIp)" -ForegroundColor Red
    Write-Host "  Continue quand meme ? (o/N)" -ForegroundColor Yellow
    $c = Read-Host
    if ($c -notmatch '^[oOyY]') { exit 1 }
} else {
    Write-Host "  OK $Domain -> $VpsIp" -ForegroundColor Green
}

Write-Host ""
Write-Host "ETAPE 2 — Upload nginx + script VPS..." -ForegroundColor Yellow
ssh $VpsHost "mkdir -p ~/SombaTeka/nginx/conf.d ~/SombaTeka/scripts"
scp (Join-Path $RepoRoot "nginx\conf.d\30-unified-webapp.conf") "${VpsHost}:~/SombaTeka/nginx/conf.d/30-unified-webapp.conf"
scp (Join-Path $RepoRoot "scripts\setup-sombatekaonline-vps.sh") "${VpsHost}:~/SombaTeka/scripts/setup-sombatekaonline-vps.sh"
ssh $VpsHost "chmod +x ~/SombaTeka/scripts/setup-sombatekaonline-vps.sh"

Write-Host ""
Write-Host "ETAPE 3 — TLS + backend sur VPS..." -ForegroundColor Yellow
ssh $VpsHost "bash ~/SombaTeka/scripts/setup-sombatekaonline-vps.sh"

Write-Host ""
Write-Host "ETAPE 4 — Build + deploy PWA..." -ForegroundColor Yellow
& (Join-Path $RepoRoot "scripts\deploy-web-vps.ps1") -Domain $Domain -ApiUrl "https://$Domain" -SkipBuild:$false

Write-Host ""
Write-Host "ETAPE 5 — A faire dans les consoles (manuel) :" -ForegroundColor Yellow
Write-Host "  Resend  : Domains → Add $Domain → copier DNS dans Cloudflare"
Write-Host "  Google  : Cloud Console → OAuth Web → Origines JS :"
Write-Host "            https://$Domain"
Write-Host "            https://www.$Domain"
Write-Host "  Cloudflare : apres HTTPS OK, tu peux remettre le nuage ORANGE (proxy)"
Write-Host ""
Write-Host "OK — https://$Domain/" -ForegroundColor Green
Write-Host ""
