#!/usr/bin/env bash
set -e

echo "=========================================================="
echo "  VibeKit AI Edge Backend - Cloudflare Production Deploy  "
echo "=========================================================="

echo -e "\n[1/5] Running TypeScript compiler checks..."
npm run typecheck

echo -e "\n[2/5] Running backend test suite..."
npm test

echo -e "\n[3/5] Checking Cloudflare Wrangler authentication..."
if ! npx wrangler whoami > /dev/null 2>&1; then
    echo -e "\n[ACTION REQUIRED] Cloudflare authentication required."
    echo "  Option A: Run 'npx wrangler login' to authenticate via browser."
    echo "  Option B: Export CLOUDFLARE_API_TOKEN='<your-api-token>' in your shell."
    exit 1
fi
echo "Cloudflare Wrangler authenticated successfully."

echo -e "\n[4/5] Applying remote D1 database migrations (vibekit-prod)..."
npx wrangler d1 migrations apply vibekit-prod --remote || {
    echo "Warning: Ensure database 'vibekit-prod' exists: npx wrangler d1 create vibekit-prod"
}

echo -e "\n[5/5] Deploying Cloudflare Worker..."
npx wrangler deploy

echo -e "\n Deployment successful! Copy the live endpoint URL and pass it to Flutter release build:"
echo "  flutter build appbundle --release --dart-define=API_URL=https://<your-worker>.workers.dev"
