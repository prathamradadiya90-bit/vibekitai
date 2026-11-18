#!/bin/bash
BASE_URL="http://127.0.0.1:8787"

echo "=========================================="
echo "🚀 VIBEKIT AI — COMPREHENSIVE LIVE AUDIT"
echo "Target Base URL: $BASE_URL"
echo "=========================================="

pass_count=0
fail_count=0

test_endpoint() {
  local name="$1"
  local method="$2"
  local path="$3"
  local data="$4"
  local expected_key="$5"
  local install_id="test-$(date +%s%N | cut -b1-13)-$RANDOM"

  echo ""
  echo "▶ Testing: $name ($method $path)..."
  
  if [ "$method" = "GET" ]; then
    response=$(curl -s -w "\nHTTP_STATUS:%{http_code}\nTIME_TOTAL:%{time_total}" -X GET "$BASE_URL$path" \
      -H "X-Installation-Id: $install_id" \
      -H "X-App-Instance-Id: $install_id")
  else
    response=$(curl -s -w "\nHTTP_STATUS:%{http_code}\nTIME_TOTAL:%{time_total}" -X POST "$BASE_URL$path" \
      -H "Content-Type: application/json" \
      -H "X-Installation-Id: $install_id" \
      -H "X-App-Instance-Id: $install_id" \
      -d "$data")
  fi

  http_status=$(echo "$response" | grep "HTTP_STATUS" | cut -d':' -f2)
  time_total=$(echo "$response" | grep "TIME_TOTAL" | cut -d':' -f2)
  body=$(echo "$response" | sed '/HTTP_STATUS/d' | sed '/TIME_TOTAL/d')

  if [ "$http_status" = "200" ]; then
    if [ -n "$expected_key" ]; then
      if echo "$body" | grep -q "$expected_key"; then
        echo "✅ PASS (Status: $http_status, Time: ${time_total}s)"
        echo "   Sample Response: $(echo "$body" | head -c 160)..."
        ((pass_count++))
      else
        echo "❌ FAIL - Expected key '$expected_key' not found in body."
        echo "   Body: $body"
        ((fail_count++))
      fi
    else
      echo "✅ PASS (Status: $http_status, Time: ${time_total}s)"
      ((pass_count++))
    fi
  else
    echo "❌ FAIL - Status: $http_status (Time: ${time_total}s)"
    echo "   Error Body: $body"
    ((fail_count++))
  fi
}

# 1. Health Endpoint
test_endpoint "API Health Check" "GET" "/v1/health" "" "healthy"

# 2. Smart Replies - Witty
test_endpoint "Smart Replies (Witty)" "POST" "/v1/generations/reply" \
  '{"message": "Why did you reply so late?", "tone": "Witty", "language": "English", "count": 2}' \
  "suggestions"

# 3. Smart Replies - Flirty
test_endpoint "Smart Replies (Flirty)" "POST" "/v1/generations/reply" \
  '{"message": "What are you doing this weekend?", "tone": "Flirty", "language": "English", "count": 2}' \
  "suggestions"

# 4. Smart Replies - Savage
test_endpoint "Smart Replies (Savage)" "POST" "/v1/generations/reply" \
  '{"message": "You think you are so special", "tone": "Savage", "language": "English", "count": 2}' \
  "suggestions"

# 5. Captions Generator - Instagram Reels Aesthetic
test_endpoint "Captions (Reels Aesthetic)" "POST" "/v1/generations/caption" \
  '{"topic": "Sunset drive along the Pacific coast", "platform": "Instagram Reels", "tone": "Aesthetic", "language": "English", "include_hooks": true, "include_hashtags": true}' \
  "captions"

# 6. Captions Generator - TikTok Trendy
test_endpoint "Captions (TikTok Trendy)" "POST" "/v1/generations/caption" \
  '{"topic": "My morning coffee routine before anyone wakes up", "platform": "TikTok", "tone": "Trendy", "language": "English", "include_hooks": true, "include_hashtags": true}' \
  "captions"

# 7. Bio Generator - Instagram Aesthetic
test_endpoint "Bios (Instagram Aesthetic)" "POST" "/v1/generations/bio" \
  '{"interests": "Coffee, indie film, street photography", "platform": "Instagram", "vibe": "Aesthetic", "language": "English", "include_usernames": true}' \
  "bios"

# 8. Bio Generator - LinkedIn Professional
test_endpoint "Bios (LinkedIn Professional)" "POST" "/v1/generations/bio" \
  '{"interests": "Full-stack cloud engineering and AI architectures", "platform": "LinkedIn", "vibe": "Professional", "language": "English", "include_usernames": false}' \
  "bios"

# 9. Vibe Check - Roast Mode
test_endpoint "Vibe Check (Roast)" "POST" "/v1/generations/vibe-check" \
  '{"text": "Hey sorry to bug you again, did you see my last message? Let me know whenever!", "mode": "roast", "language": "English"}' \
  "score"

# 10. Vibe Check - Polish Mode
test_endpoint "Vibe Check (Polish)" "POST" "/v1/generations/vibe-check" \
  '{"text": "Can you do this task today or what?", "mode": "polish", "language": "English"}' \
  "score"

# 11. Daily Streak Status
test_endpoint "Streak Status Query" "GET" "/v1/streak" "" "current_streak"

# 12. Daily Streak Check-in
test_endpoint "Streak Check-in Action" "POST" "/v1/streak/checkin" \
  '{"action": "checkin", "utc_offset_minutes": 330}' \
  "success"

# 13. Privacy Web Page
test_endpoint "Privacy Policy Page" "GET" "/privacy" "" "Privacy Policy"

# 14. Data Deletion Page
test_endpoint "Data Deletion Page" "GET" "/delete-data" "" "Account & Data Deletion"

echo ""
echo "=========================================="
echo "📊 AUDIT SUMMARY"
echo "Total Passed: $pass_count"
echo "Total Failed: $fail_count"
echo "=========================================="

if [ "$fail_count" -eq 0 ]; then
  echo "🎉 ALL TESTS PASSED! 100% OPERATIONAL."
  exit 0
else
  echo "⚠️ Some tests failed. Review logs above."
  exit 1
fi
