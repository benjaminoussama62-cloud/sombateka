# Update assetlinks.json (Android) and apple-app-site-association (iOS)
param(
    [string]$AppleTeamId = ""
)

$ErrorActionPreference = "Stop"
$Mobile = Join-Path $PSScriptRoot ".."
$Repo = Join-Path $Mobile ".."
$WellKnown = Join-Path $Repo "website\.well-known"
$KeyProps = Join-Path $Mobile "android\key.properties"

function Get-ReleaseSha256 {
    if (-not (Test-Path $KeyProps)) {
        Write-Host "  key.properties missing - skip assetlinks" -ForegroundColor Yellow
        return $null
    }
    $props = @{}
    Get-Content $KeyProps | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') { $props[$matches[1].Trim()] = $matches[2].Trim() }
    }
    $storeFile = $props['storeFile']
    $storePass = $props['storePassword']
    $alias = if ($props['keyAlias']) { $props['keyAlias'] } else { 'upload' }
    if (-not $storeFile -or -not $storePass) { return $null }
    $ks = if ([System.IO.Path]::IsPathRooted($storeFile)) {
        $storeFile
    } else {
        [System.IO.Path]::GetFullPath((Join-Path (Join-Path $Mobile "android") $storeFile))
    }
    if (-not (Test-Path $ks)) {
        $fallback = Join-Path (Join-Path $Mobile "android") "sombateka-upload.jks"
        if (Test-Path $fallback) { $ks = $fallback }
    }
    if (-not (Test-Path $ks)) {
        Write-Host "  Keystore missing: $ks" -ForegroundColor Yellow
        return $null
    }
    $javaHome = $env:JAVA_HOME
    if (-not $javaHome -or -not (Test-Path (Join-Path $javaHome "bin\keytool.exe"))) {
        $candidates = @(
            "C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot",
            "C:\Program Files\Android\Android Studio\jbr"
        )
        foreach ($c in $candidates) {
            if (Test-Path (Join-Path $c "bin\keytool.exe")) { $javaHome = $c; break }
        }
    }
    $keytool = if ($javaHome) { Join-Path $javaHome "bin\keytool.exe" } else { "keytool" }
    $out = & $keytool -list -v -keystore $ks -alias $alias -storepass $storePass 2>&1 | Out-String
    if ($out -match 'SHA256:\s*([0-9A-Fa-f:]+)') {
        return $matches[1].ToUpper()
    }
    return $null
}

New-Item -ItemType Directory -Path $WellKnown -Force | Out-Null

$sha256 = Get-ReleaseSha256
if ($sha256) {
    $assetlinks = @(
        @{
            relation = @("delegate_permission/common.handle_all_urls")
            target   = @{
                namespace                = "android_app"
                package_name             = "com.sombateka.st"
                sha256_cert_fingerprints = @($sha256)
            }
        }
    ) | ConvertTo-Json -Depth 5
    Set-Content -Path (Join-Path $WellKnown "assetlinks.json") -Value $assetlinks -Encoding UTF8
    Write-Host "  OK assetlinks.json (release SHA256)" -ForegroundColor Green
} else {
    Write-Host "  assetlinks.json unchanged (no SHA256)" -ForegroundColor Yellow
}

$aasaPath = Join-Path $WellKnown "apple-app-site-association"
if ($AppleTeamId) {
    $aasa = @{
        applinks = @{
            apps    = @()
            details = @(
                @{
                    appID = "$AppleTeamId.com.sombateka.st"
                    paths = @("/listing/*", "/product/*", "/app/*")
                }
            )
        }
    } | ConvertTo-Json -Depth 5
    Set-Content -Path $aasaPath -Value $aasa -Encoding UTF8
    Write-Host "  OK apple-app-site-association (Team $AppleTeamId)" -ForegroundColor Green
} elseif (Test-Path $aasaPath) {
    Write-Host "  apple-app-site-association unchanged (no AppleTeamId)" -ForegroundColor DarkGray
}
