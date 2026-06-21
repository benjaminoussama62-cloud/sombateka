# Configure SMTP dans backend/.env.production (Brevo ou Gmail)
param(
    [ValidateSet("brevo", "gmail", "custom")]
    [string]$Preset = "brevo"
)

$ErrorActionPreference = "Stop"
$EnvFile = Join-Path $PSScriptRoot "..\backend\.env.production" | Resolve-Path

Write-Host ""
Write-Host "SombaTeka — Configuration email SMTP" -ForegroundColor Cyan
Write-Host "Fichier : $EnvFile"
Write-Host ""

function Read-Secret([string]$Prompt) {
    $sec = Read-Host $Prompt -AsSecureString
    [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    )
}

$alertEmail = Read-Host "Email admin (alertes KYC, signalements)"
$smtpUser = Read-Host "Email SMTP (login, souvent le meme)"
$smtpPassword = Read-Secret "Mot de passe / cle SMTP"

switch ($Preset) {
    "brevo" {
        $host_ = "smtp-relay.brevo.com"
        $port = "587"
        $tls = "true"
        $ssl = "false"
        Write-Host "Preset Brevo (smtp-relay.brevo.com)" -ForegroundColor Yellow
    }
    "gmail" {
        $host_ = "smtp.gmail.com"
        $port = "587"
        $tls = "true"
        $ssl = "false"
        Write-Host "Preset Gmail — utilisez un mot de passe d'application Google" -ForegroundColor Yellow
    }
    "custom" {
        $host_ = Read-Host "SMTP_HOST"
        $port = Read-Host "SMTP_PORT (587 ou 465)"
        if ($port -eq "465") {
            $tls = "false"
            $ssl = "true"
        } else {
            $tls = "true"
            $ssl = "false"
        }
    }
}

$from = "SombaTeka <$smtpUser>"
$content = Get-Content $EnvFile -Raw

$replacements = @{
    '(?m)^EMAIL_PROVIDER=.*'          = 'EMAIL_PROVIDER=smtp'
    '(?m)^EMAIL_FROM=.*'              = "EMAIL_FROM=$from"
    '(?m)^SMTP_HOST=.*'               = "SMTP_HOST=$host_"
    '(?m)^SMTP_PORT=.*'               = "SMTP_PORT=$port"
    '(?m)^SMTP_USER=.*'               = "SMTP_USER=$smtpUser"
    '(?m)^SMTP_PASSWORD=.*'           = "SMTP_PASSWORD=$smtpPassword"
    '(?m)^SMTP_USE_TLS=.*'            = "SMTP_USE_TLS=$tls"
    '(?m)^SMTP_USE_SSL=.*'            = "SMTP_USE_SSL=$ssl"
    '(?m)^ADMIN_ALERT_EMAILS=.*'      = "ADMIN_ALERT_EMAILS=$alertEmail"
}

foreach ($pattern in $replacements.Keys) {
    $value = $replacements[$pattern]
    if ($content -match $pattern) {
        $content = $content -replace $pattern, $value
    } else {
        $content = $content.TrimEnd() + "`n$value`n"
    }
}

Set-Content -Path $EnvFile -Value $content -NoNewline

Write-Host ""
Write-Host "OK — .env.production mis a jour" -ForegroundColor Green
Write-Host ""
Write-Host "Sur le VPS (apres upload ou copie manuelle) :" -ForegroundColor Yellow
Write-Host @"
  cd /root/SombaTeka/backend
  export DB_PASSWORD=`$(grep '^DB_PASSWORD=' .env.production | cut -d= -f2-)
  docker compose -f docker-compose.prod.yml -f docker-compose.beta.yml restart backend
  docker compose -f docker-compose.prod.yml -f docker-compose.beta.yml exec backend python scripts/test_email.py --to $alertEmail
"@
