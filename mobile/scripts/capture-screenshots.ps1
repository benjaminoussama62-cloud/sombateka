# Capture automatique de captures Play Store via adb
param(
    [string]$DeviceId = "",
    [string]$OutDir = "store/play/screenshots/phone"
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) {
    Write-Host "❌ adb introuvable — installez Android SDK Platform Tools" -ForegroundColor Red
    Write-Host "   Ou capturez manuellement : store/play/SCREENSHOTS.md"
    exit 1
}

$fullOut = Join-Path (Get-Location) $OutDir
New-Item -ItemType Directory -Force -Path $fullOut | Out-Null

$adbArgs = @()
if ($DeviceId) { $adbArgs += "-s", $DeviceId }

Write-Host ""
Write-Host "Capture Play Store — SombaTeka" -ForegroundColor Cyan
Write-Host "Dossier : $fullOut"
Write-Host ""
Write-Host "Naviguez manuellement vers chaque écran sur l'émulateur/téléphone."
Write-Host "Appuyez Entrée pour capturer (ou 'q' pour quitter)."
Write-Host ""

$i = 1
while ($true) {
    $label = Read-Host "Nom écran (ex: home, detail) ou q"
    if ($label -eq "q") { break }
    if (-not $label) { $label = "screen" }
    $file = Join-Path $fullOut ("{0:D2}-{1}.png" -f $i, $label)
    $remote = "/sdcard/st_capture.png"
    & adb @adbArgs shell screencap -p $remote
    & adb @adbArgs pull $remote $file | Out-Null
    & adb @adbArgs shell rm $remote 2>$null
    Write-Host "✓ $file" -ForegroundColor Green
    $i++
}

Write-Host ""
Write-Host "Terminé — uploadez vers Play Console" -ForegroundColor Green
