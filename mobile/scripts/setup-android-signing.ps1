# Génère le keystore Android + key.properties pour publication Play Store.
# Les identifiants sont sauvegardés dans android/signing-credentials.local.txt (NE PAS COMMITTER).

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$keystorePath = Join-Path "android" "sombateka-upload.jks"
$keyPropsPath = Join-Path "android" "key.properties"
$credsPath = Join-Path "android" "signing-credentials.local.txt"

if ((Test-Path $keystorePath) -and (Test-Path $keyPropsPath)) {
    Write-Host "OK: keystore et key.properties existent déjà." -ForegroundColor Green
    Write-Host "  Keystore: $keystorePath"
    exit 0
}

Write-Host "==> SombaTeka — configuration signature Android" -ForegroundColor Cyan

$storePass = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
$keyPass = $storePass
$alias = "sombateka"

$javaHome = $env:JAVA_HOME
if (-not $javaHome) {
    $candidates = @(
        "C:\Android\AndroidStudio\jbr",
        "$env:ProgramFiles\Android\Android Studio\jbr",
        "$env:LOCALAPPDATA\Programs\Android Studio\jbr"
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "bin\keytool.exe")) {
            $javaHome = $c
            break
        }
    }
}

$keytool = if ($javaHome) { Join-Path $javaHome "bin\keytool.exe" } else { "keytool" }

$dname = "CN=SombaTeka, OU=Mobile, O=SombaTeka, L=Kinshasa, ST=Kinshasa, C=CD"
$keystoreAbs = (Resolve-Path "android" -ErrorAction SilentlyContinue)
if (-not $keystoreAbs) { New-Item -ItemType Directory -Path "android" | Out-Null }
$keystoreFull = Join-Path (Get-Location) $keystorePath

& $keytool -genkeypair -v `
    -storetype PKCS12 `
    -keystore $keystoreFull `
    -alias $alias `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -storepass $storePass `
    -keypass $keyPass `
    -dname $dname

@"
storePassword=$storePass
keyPassword=$keyPass
keyAlias=$alias
storeFile=../sombateka-upload.jks
"@ | Set-Content -Path $keyPropsPath -Encoding UTF8

@"
SombaTeka — identifiants de signature Android (CONFIDENTIEL)
Généré le: $(Get-Date -Format "yyyy-MM-dd HH:mm")

Keystore : android/sombateka-upload.jks
Alias    : $alias
Store PW : $storePass
Key PW   : $keyPass

IMPORTANT:
- Sauvegardez ce fichier et le .jks dans un coffre-fort (1Password, etc.)
- Sans ce keystore, vous ne pourrez PAS publier de mises à jour sur le Play Store
- Ne commitez JAMAIS ces fichiers sur Git
"@ | Set-Content -Path $credsPath -Encoding UTF8

Write-Host ""
Write-Host "OK: keystore créé → $keystorePath" -ForegroundColor Green
Write-Host "OK: key.properties créé" -ForegroundColor Green
Write-Host "OK: identifiants sauvegardés → $credsPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "Prochaine étape:" -ForegroundColor Cyan
Write-Host "  .\scripts\build-android-release.ps1 -ApiUrl `"https://api.sombateka.cd`""
