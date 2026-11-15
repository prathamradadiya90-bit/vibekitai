<#
.SYNOPSIS
  One-Click Production Release Bundle Builder for VibeKit AI.
.DESCRIPTION
  Builds a signed, minified, production-ready Android App Bundle (AAB)
  with custom Cloudflare Worker API URL and AdMob Unit IDs.
.EXAMPLE
  .\build-release.ps1 -ApiUrl "https://api.vibekit.ai"
#>

param(
    [string]$ApiUrl = "https://api.vibekit.ai",
    [string]$AdmobBannerId = "",
    [string]$AdmobRewardedId = "",
    [string]$AdmobInterstitialId = ""
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     VibeKit AI - Android Release Bundle Generator        " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Target API URL: $ApiUrl" -ForegroundColor Yellow

$buildArgs = @(
    "build", "appbundle", "--release",
    "--dart-define=API_URL=$ApiUrl"
)

if ($AdmobBannerId) {
    $buildArgs += "--dart-define=ADMOB_BANNER_ID=$AdmobBannerId"
    Write-Host "AdMob Banner: $AdmobBannerId" -ForegroundColor Yellow
}
if ($AdmobRewardedId) {
    $buildArgs += "--dart-define=ADMOB_REWARDED_ID=$AdmobRewardedId"
    Write-Host "AdMob Rewarded: $AdmobRewardedId" -ForegroundColor Yellow
}
if ($AdmobInterstitialId) {
    $buildArgs += "--dart-define=ADMOB_INTERSTITIAL_ID=$AdmobInterstitialId"
    Write-Host "AdMob Interstitial: $AdmobInterstitialId" -ForegroundColor Yellow
}

Write-Host "`n[1/2] Compiling Dart AOT and assets..." -ForegroundColor Yellow
Set-Location app

# Set NDK location for symbol processing
if (Test-Path "D:\Android\Sdk\ndk\28.2.13676358") {
    $env:ANDROID_HOME = "D:\Android\Sdk"
    $env:ANDROID_NDK_HOME = "D:\Android\Sdk\ndk\28.2.13676358"
}

# Run Flutter pub get
flutter pub get

Write-Host "`n[2/2] Generating signed Android App Bundle (bundleRelease)..." -ForegroundColor Yellow
Set-Location android
.\gradlew bundleRelease

if ($LASTEXITCODE -eq 0) {
    Set-Location ../..
    $aabPath = "app/build/app/outputs/bundle/release/app-release.aab"
    if (Test-Path $aabPath) {
        $fileItem = Get-Item $aabPath
        $sizeMb = [math]::Round($fileItem.Length / 1MB, 2)
        Write-Host "`n SUCCESS! Production Android App Bundle created." -ForegroundColor Green
        Write-Host "Path: $($fileItem.FullName)" -ForegroundColor White
        Write-Host "Size: $sizeMb MB" -ForegroundColor White
        Write-Host "`nYou can upload this file directly to Google Play Console under Internal/Closed Testing or Production." -ForegroundColor Green
    }
} else {
    Set-Location ../..
    Write-Host "`n Build failed. Review gradle logs above." -ForegroundColor Red
    exit 1
}
