# Build Flutter Web production + pages legales
param(
    [string]$ApiUrl = "https://sombatekaonline.com",
    [string]$Domain = "sombatekaonline.com",
    [string]$GoogleWebClientId = "508328631175-2gpdu705sfbqa8anhj71m42tsf9dpk5p.apps.googleusercontent.com",
    [string]$OutputDir = ""
)

$ErrorActionPreference = "Stop"
$MobileRoot = Join-Path $PSScriptRoot ".."
$RepoRoot = Join-Path $MobileRoot ".."
if (-not $OutputDir) {
    $OutputDir = Join-Path $RepoRoot "web-dist"
}

Set-Location $MobileRoot

Write-Host ""
Write-Host "SombaTeka - Build Web App (Flutter)" -ForegroundColor Cyan
Write-Host "  API : $ApiUrl"
Write-Host "  Out : $OutputDir"
Write-Host ""

Write-Host "-> Icones SombaTeka..." -ForegroundColor Yellow
try {
    pip install -q -r (Join-Path $MobileRoot "scripts\requirements.txt") 2>$null
    python (Join-Path $MobileRoot "scripts\generate_store_assets.py")
    & (Join-Path $MobileRoot "scripts\update-deep-links.ps1")
} catch {
    Write-Host "  (icones: skip)" -ForegroundColor DarkGray
}

flutter pub get

$defines = @(
    "--dart-define=ST_TERMS_URL=https://$Domain/terms",
    "--dart-define=ST_PRIVACY_URL=https://$Domain/privacy",
    "--dart-define=ST_DELETE_ACCOUNT_URL=https://$Domain/account-deletion",
    "--dart-define=ST_SOCIAL_AUTH_ENABLED=true",
    "--dart-define=ST_GOOGLE_WEB_CLIENT_ID=$GoogleWebClientId"
)

Write-Host "-> Compilation Flutter Web release..." -ForegroundColor Yellow
# --no-web-resources-cdn : CanvasKit/Skwasm servis depuis notre domaine (déjà dans build/web),
# pas de dépendance à gstatic.com — évite les boots bloqués quand le CDN est lent/injoignable.
flutter build web --release --no-tree-shake-icons --no-wasm-dry-run --no-web-resources-cdn @defines
if ($LASTEXITCODE -ne 0) {
    throw "flutter build web a echoue (code $LASTEXITCODE)"
}

$buildWeb = Join-Path $MobileRoot "build\web"
$mainJs = Join-Path $buildWeb "main.dart.js"
if (-not (Test-Path $mainJs)) {
    throw "Build incomplet: main.dart.js introuvable dans $buildWeb"
}

Write-Host "-> Assemblage web-dist..." -ForegroundColor Yellow
if (Test-Path $OutputDir) { Remove-Item $OutputDir -Recurse -Force }
New-Item -ItemType Directory -Path $OutputDir | Out-Null
Copy-Item -Path "$buildWeb\*" -Destination $OutputDir -Recurse

# SW : cache assets Flutter (JS/WASM/fonts), pas l'API
Copy-Item (Join-Path $MobileRoot "web\flutter_service_worker.js") (Join-Path $OutputDir "flutter_service_worker.js") -Force

# Material Icons — copie racine /fonts/ (PWA iOS charge souvent depuis la racine)
$fontSrc = Join-Path $OutputDir "assets\fonts\MaterialIcons-Regular.otf"
if (-not (Test-Path $fontSrc)) {
    throw "Police MaterialIcons introuvable: $fontSrc"
}
$fontsRoot = Join-Path $OutputDir "fonts"
New-Item -ItemType Directory -Path $fontsRoot -Force | Out-Null
Copy-Item $fontSrc (Join-Path $fontsRoot "MaterialIcons-Regular.otf") -Force
Write-Host "  OK MaterialIcons -> /fonts/ + /assets/fonts/" -ForegroundColor DarkGray

$assetManifest = Join-Path $OutputDir "assets\AssetManifest.bin.json"
if (-not (Test-Path $assetManifest)) {
    throw "AssetManifest.bin.json introuvable - build Flutter incomplet"
}

$legal = Join-Path $RepoRoot "website"
foreach ($f in @("terms.html", "privacy.html", "account-deletion.html", "robots.txt", "sitemap.xml", "sitemap-index.xml", "marketplace-rdc.html", "kinshasa.html")) {
    $src = Join-Path $legal $f
    if (Test-Path $src) { Copy-Item $src $OutputDir -Force }
}
$aboutSrc = Join-Path $legal "index.html"
if (Test-Path $aboutSrc) {
    Copy-Item $aboutSrc (Join-Path $OutputDir "about.html") -Force
}
Get-ChildItem -Path $legal -Filter "google*.html" -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item $_.FullName $OutputDir
}
if (Test-Path (Join-Path $legal ".well-known")) {
    Copy-Item (Join-Path $legal ".well-known") (Join-Path $OutputDir ".well-known") -Recurse
}

$websiteAssets = Join-Path $legal "assets"
if (Test-Path $websiteAssets) {
    $destAssets = Join-Path $OutputDir "assets"
    New-Item -ItemType Directory -Path $destAssets -Force | Out-Null
    Copy-Item (Join-Path $websiteAssets "style.css") $destAssets -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $websiteAssets "favicon-*.png") $destAssets -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $websiteAssets "og-image.png") $destAssets -ErrorAction SilentlyContinue
    foreach ($logo in @("logo-mark.svg", "android-logo.svg", "apple-logo.svg", "apple-logo-dark.svg")) {
        $srcLogo = Join-Path $websiteAssets $logo
        if (Test-Path $srcLogo) { Copy-Item $srcLogo $destAssets -Force }
    }
    $storeBadges = Join-Path $websiteAssets "stores"
    if (Test-Path $storeBadges) {
        $destStores = Join-Path $destAssets "stores"
        New-Item -ItemType Directory -Path $destStores -Force | Out-Null
        Copy-Item (Join-Path $storeBadges "*") $destStores -Force
    }
}
$icon512 = Join-Path $MobileRoot "web\icons\Icon-512.png"
$icon192 = Join-Path $MobileRoot "web\icons\Icon-192.png"
$favicon32 = Join-Path $MobileRoot "web\favicon.png"
if (Test-Path $icon512) {
    $destAssets = Join-Path $OutputDir "assets"
    New-Item -ItemType Directory -Path $destAssets -Force | Out-Null
    if (-not (Test-Path (Join-Path $destAssets "og-image.png"))) {
        Copy-Item $icon512 (Join-Path $destAssets "og-image.png") -Force
    }
    if (-not (Test-Path (Join-Path $destAssets "favicon-192.png"))) {
        Copy-Item $icon192 (Join-Path $destAssets "favicon-192.png") -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path (Join-Path $destAssets "favicon-32.png"))) {
        Copy-Item $favicon32 (Join-Path $destAssets "favicon-32.png") -Force -ErrorAction SilentlyContinue
    }
}

# Fichiers racine attendus par navigateurs/crawlers (corrige les 404 Search Console)
$adminIco = Join-Path $RepoRoot "backend\admin-panel\assets\favicon.ico"
if (Test-Path $adminIco) {
    Copy-Item $adminIco (Join-Path $OutputDir "favicon.ico") -Force
} elseif (Test-Path $favicon32) {
    Copy-Item $favicon32 (Join-Path $OutputDir "favicon.ico") -Force
}
$touchIcon = Join-Path $RepoRoot "backend\admin-panel\assets\apple-touch-icon.png"
if (Test-Path $touchIcon) {
    Copy-Item $touchIcon (Join-Path $OutputDir "apple-touch-icon.png") -Force
}
$manifestBin = Join-Path $OutputDir "assets\AssetManifest.bin.json"
if (Test-Path $manifestBin) {
    Copy-Item $manifestBin (Join-Path $OutputDir "assets\AssetManifest.json") -Force
}
$ogRoot = Join-Path $OutputDir "assets\og-image.png"
if (Test-Path $ogRoot) {
    Copy-Item $ogRoot (Join-Path $OutputDir "og-image.png") -Force
}

$buildStamp = Get-Date -Format "yyyyMMddHHmmss"

# Cache-bust main.dart.js dans flutter_bootstrap.js
$bootstrapPath = Join-Path $OutputDir "flutter_bootstrap.js"
$bootstrap = Get-Content $bootstrapPath -Raw
$bootstrap = $bootstrap -replace '"mainJsPath":"main\.dart\.js"', "`"mainJsPath`":`"main.dart.js?v=$buildStamp`""
$bootstrap = $bootstrap -replace 'serviceWorkerSettings:\s*\{[^}]+\}', 'serviceWorkerSettings: null'
Set-Content -Path $bootstrapPath -Value $bootstrap -NoNewline

$indexPath = Join-Path $OutputDir "index.html"
$html = Get-Content $indexPath -Raw
$html = $html -replace '<meta name="description" content="[^"]*">', '<meta name="description" content="SombaTeka : marketplace en ligne en RDC. Achetez et vendez à Kinshasa et partout au Congo. Annonces, messagerie, vendeurs certifiés, Mobile Money MTN et Orange.">'
$html = $html -replace '<title>[^<]*</title>', '<title>SombaTeka — Marketplace en ligne RDC | Achat et vente</title>'
$manifestLink = "<link rel=`"manifest`" href=`"manifest.json?v=$buildStamp`">"
$html = $html -replace '<link rel="manifest" href="manifest.json(\?[^"]*)?">', $manifestLink
$bootstrapScript = "<script src=`"flutter_bootstrap.js?v=$buildStamp`""
$html = $html -replace '<script src="flutter_bootstrap.js(\?[^"]*)?"', $bootstrapScript
# st-api-base vide → index.html utilise window.location.origin (www ou apex, même origine API)
$buildMeta = "<meta name=`"st-build`" content=`"$buildStamp`">"
$html = $html -replace '<meta name="st-build" content="[^"]*">', $buildMeta
if ($GoogleWebClientId) {
    $html = $html -replace '<meta name="google-signin-client_id" content="[^"]*">', "<meta name=`"google-signin-client_id`" content=`"$GoogleWebClientId`">"
}
$html = $html -replace '<link rel="preload" href="fonts/MaterialIcons-Regular\.otf[^"]*"', "<link rel=`"preload`" href=`"fonts/MaterialIcons-Regular.otf?v=$buildStamp`""
$html = $html -replace '<link rel="preload" href="assets/fonts/MaterialIcons-Regular\.otf[^"]*"', "<link rel=`"preload`" href=`"assets/fonts/MaterialIcons-Regular.otf?v=$buildStamp`""
$html = $html -replace "url\('fonts/MaterialIcons-Regular\.otf'\)", "url('fonts/MaterialIcons-Regular.otf?v=$buildStamp')"
$html = $html -replace "url\('assets/fonts/MaterialIcons-Regular\.otf'\)", "url('assets/fonts/MaterialIcons-Regular.otf?v=$buildStamp')"
Set-Content -Path $indexPath -Value $html -NoNewline

# version.json pour controle deploy
$versionJson = Join-Path $OutputDir "version.json"
Set-Content -Path $versionJson -Value "{ `"build`": `"$buildStamp`", `"api`": `"$ApiUrl`" }" -NoNewline

# manifest start_url cache-bust
$manifestPath = Join-Path $OutputDir "manifest.json"
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath -Raw
    $manifest = $manifest -replace '"start_url":\s*"[^"]*"', "`"start_url`": `"/?v=$buildStamp`""
    Set-Content -Path $manifestPath -Value $manifest -NoNewline
}

Write-Host ""
Write-Host "OK - Web app prete : $OutputDir (build $buildStamp)" -ForegroundColor Green
Write-Host "  Deployer : ..\scripts\deploy-web-vps.ps1 -SkipBuild"
Write-Host ""
