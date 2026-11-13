# VibeKit AI — 1-Click Cloudflare Edge Deployment Script
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  VibeKit AI — Cloudflare Workers Production Deployment" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check Wrangler login
Write-Host "`n[1/5] Checking Cloudflare Authentication..." -ForegroundColor Yellow
$whoami = npx wrangler whoami 2>&1 | Out-String
if ($whoami -match "You are not authenticated") {
    Write-Host "You are not logged in to Cloudflare. Opening login page in browser..." -ForegroundColor Red
    npx wrangler login
} else {
    Write-Host "Cloudflare authentication verified!" -ForegroundColor Green
}

# 2. Check / Create D1 Database
Write-Host "`n[2/5] Checking Production D1 Database..." -ForegroundColor Yellow
$d1List = npx wrangler d1 list 2>&1 | Out-String
if ($d1List -notmatch "vibekit-prod") {
    Write-Host "Creating D1 database 'vibekit-prod'..." -ForegroundColor Cyan
    $createOutput = npx wrangler d1 create vibekit-prod 2>&1 | Out-String
    Write-Host $createOutput
    Write-Host "IMPORTANT: If database_id is printed above, verify it is set in backend/wrangler.toml" -ForegroundColor Yellow
} else {
    Write-Host "D1 Database 'vibekit-prod' verified!" -ForegroundColor Green
}

# 3. Apply D1 Migrations
Write-Host "`n[3/5] Applying All 9 Production D1 Migrations..." -ForegroundColor Yellow
npx wrangler d1 migrations apply vibekit-prod --remote

# 4. Secrets Setup Reminder
Write-Host "`n[4/5] Production Secrets Configuration" -ForegroundColor Yellow
Write-Host "Ensure the following secrets are configured:" -ForegroundColor Gray
Write-Host "  - GEMINI_API_KEY:                     npx wrangler secret put GEMINI_API_KEY" -ForegroundColor White
Write-Host "  - GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:   npx wrangler secret put GOOGLE_PLAY_SERVICE_ACCOUNT_JSON" -ForegroundColor White

# 5. Deploy Worker
Write-Host "`n[5/5] Deploying Edge Worker to Cloudflare Global Edge..." -ForegroundColor Yellow
npx wrangler deploy

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  DEPLOYMENT COMPLETE!" -ForegroundColor Green
Write-Host "  Verification URLs:" -ForegroundColor Green
Write-Host "    - Healthcheck:          /v1/health" -ForegroundColor White
Write-Host "    - Privacy Policy:       /privacy" -ForegroundColor White
Write-Host "    - Account Deletion:     /delete-account" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Green
