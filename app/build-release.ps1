# VibeKit AI — 1-Click Release Builder (Google Play AAB & Test APK)
param(
    [string]$ApiUrl = "",
    [string]$AdmobBannerId = "",
    [string]$AdmobRewardedId = "",
    [switch]$ApkOnly = $false
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  VibeKit AI — Building Production Release Artifacts" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Configure safe environments
$env:TEMP = "D:\Temp"
$env:TMP = "D:\Temp"
$env:GRADLE_USER_HOME = "D:\.gradle"
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"

if (-not (Test-Path "D:\Temp")) { New-Item -ItemType Directory -Path "D:\Temp" -Force | Out-Null }

# Build defines
$defines = @()
if ($ApiUrl -ne "") {
    $defines += "--dart-define=API_URL=$ApiUrl"
}
if ($AdmobBannerId -ne "") {
    $defines += "--dart-define=ADMOB_BANNER_ID=$AdmobBannerId"
}
if ($AdmobRewardedId -ne "") {
    $defines += "--dart-define=ADMOB_REWARDED_ID=$AdmobRewardedId"
}

Write-Host "`n[1/2] Compiling Flutter Assets & Code..." -ForegroundColor Yellow
& flutter build bundle $defines

Write-Host "`n[2/2] Assembling Signed Android App Bundle (AAB for Google Play)..." -ForegroundColor Yellow
Push-Location "$PSScriptRoot\android"
try {
    & .\gradlew.bat bundleRelease
} finally {
    Pop-Location
}

if (-not $ApkOnly) {
    Write-Host "`n[Optional] Assembling Standalone Signed APK for device testing..." -ForegroundColor Yellow
    Push-Location "$PSScriptRoot\android"
    try {
        & .\gradlew.bat assembleRelease
    } finally {
        Pop-Location
    }
}

$apkPath = "$PSScriptRoot\build\app\outputs\apk\release\app-release.apk"
$aabPath = "$PSScriptRoot\build\app\outputs\bundle\release\app-release.aab"

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  RELEASE ARTIFACTS STATUS:" -ForegroundColor Green
if (Test-Path $aabPath) {
    Write-Host "  [AAB for Play Store] $aabPath ($([math]::Round((Get-Item $aabPath).Length / 1MB, 2)) MB)" -ForegroundColor Green
    Write-Host "  -> Upload this file to Google Play Console: Production / Closed Testing track." -ForegroundColor Yellow
} else {
    Write-Host "  [AAB] Not found at $aabPath" -ForegroundColor Red
}

if (Test-Path $apkPath) {
    Write-Host "  [APK for direct test] $apkPath ($([math]::Round((Get-Item $apkPath).Length / 1MB, 2)) MB)" -ForegroundColor White
}
Write-Host "==========================================================" -ForegroundColor Green
