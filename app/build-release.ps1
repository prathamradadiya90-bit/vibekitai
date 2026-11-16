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

# Build defines
$defines = @()
if ($ApiUrl -ne "") {
    $defines += "--dart-define=API_URL=$ApiUrl"
} else {
    $defines += "--dart-define=API_URL=https://api.vibekit.ai"
}
if ($AdmobBannerId -ne "") {
    $defines += "--dart-define=ADMOB_BANNER_ID=$AdmobBannerId"
}
if ($AdmobRewardedId -ne "") {
    $defines += "--dart-define=ADMOB_REWARDED_ID=$AdmobRewardedId"
}

Write-Host "`n[1/2] Assembling Signed Android App Bundle (AAB for Google Play)..." -ForegroundColor Yellow
& flutter build appbundle --release $defines

if ($ApkOnly) {
    Write-Host "`n[Optional] Assembling Standalone Signed APK for device testing..." -ForegroundColor Yellow
    & flutter build apk --release $defines
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
