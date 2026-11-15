<#
.SYNOPSIS
  Automated Cloudflare Workers Production Deployment Script for VibeKit AI Edge Backend.
.DESCRIPTION
  Performs pre-flight quality checks (typecheck, tests), verifies Cloudflare authentication,
  provisions or applies remote D1 database migrations, and deploys the Cloudflare Worker.
#>

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  VibeKit AI Edge Backend - Cloudflare Production Deploy  " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Pre-flight Quality Gate
Write-Host "`n[1/5] Running TypeScript compiler checks..." -ForegroundColor Yellow
npm run typecheck
if ($LASTEXITCODE -ne 0) {
    Write-Host "TypeScript check failed. Fix errors before deploying." -ForegroundColor Red
    exit 1
}
Write-Host "TypeScript checks passed (0 errors)." -ForegroundColor Green

Write-Host "`n[2/5] Running backend test suite..." -ForegroundColor Yellow
npm test
if ($LASTEXITCODE -ne 0) {
    Write-Host "Backend tests failed. Aborting deployment." -ForegroundColor Red
    exit 1
}
Write-Host "All backend tests passed (100% pass rate)." -ForegroundColor Green

# 2. Check Wrangler Authentication
Write-Host "`n[3/5] Checking Cloudflare Wrangler authentication..." -ForegroundColor Yellow
$whoami = npx wrangler whoami 2>&1
if ($whoami -match "You are not authenticated") {
    Write-Host "`n[ACTION REQUIRED] Cloudflare authentication required." -ForegroundColor Red
    Write-Host "Please authenticate using one of the following methods:" -ForegroundColor Yellow
    Write-Host "  Option A: Run 'npx wrangler login' in this terminal to log in via browser." -ForegroundColor White
    Write-Host "  Option B: Set `$env:CLOUDFLARE_API_TOKEN = '<your-api-token>' in your environment." -ForegroundColor White
    exit 1
}
Write-Host "Cloudflare Wrangler authenticated successfully." -ForegroundColor Green

# 3. Apply Remote D1 Database Migrations
Write-Host "`n[4/5] Applying remote D1 database migrations (vibekit-prod)..." -ForegroundColor Yellow
npx wrangler d1 migrations apply vibekit-prod --remote
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: Remote migration returned non-zero exit code. Ensure database 'vibekit-prod' exists in your Cloudflare account." -ForegroundColor Yellow
    Write-Host "Create it if needed using: npx wrangler d1 create vibekit-prod" -ForegroundColor Yellow
} else {
    Write-Host "Remote D1 migrations applied successfully." -ForegroundColor Green
}

# 4. Deploy Cloudflare Worker
Write-Host "`n[5/5] Deploying Cloudflare Worker to production..." -ForegroundColor Yellow
npx wrangler deploy
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n Deployment successful!" -ForegroundColor Green
    Write-Host "Your VibeKit AI edge backend is live." -ForegroundColor Green
    Write-Host "Copy the live endpoint URL and pass it to Flutter release build:" -ForegroundColor Cyan
    Write-Host "  flutter build appbundle --release --dart-define=API_URL=https://<your-worker>.workers.dev" -ForegroundColor White
} else {
    Write-Host "Cloudflare Worker deployment failed." -ForegroundColor Red
    exit 1
}
