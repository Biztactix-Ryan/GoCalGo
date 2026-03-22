#!/usr/bin/env bash
# Verify that app store screenshots exist for all required device sizes.
# Usage: ./scripts/verify-screenshots.sh

set -euo pipefail

SCREENSHOTS_DIR="docs/screenshots"
PASS=0
FAIL=0
WARN=0

check_dir() {
  local dir="$1"
  local label="$2"
  local required="$3"  # "required" or "recommended"
  local min_count="$4"

  local count
  count=$(find "$SCREENSHOTS_DIR/$dir" -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) 2>/dev/null | wc -l)

  if [ "$count" -ge "$min_count" ]; then
    echo "  PASS  $label: $count screenshot(s) found"
    PASS=$((PASS + 1))
  elif [ "$required" = "required" ]; then
    echo "  FAIL  $label: $count screenshot(s) found (need >= $min_count)"
    FAIL=$((FAIL + 1))
  else
    echo "  WARN  $label: $count screenshot(s) found (recommended >= $min_count)"
    WARN=$((WARN + 1))
  fi
}

echo "=== App Store Screenshot Verification ==="
echo ""
echo "iOS App Store:"
check_dir "ios/6.9"  "6.9\" iPhone 16 Pro Max (1320x2868)" "required" 3
check_dir "ios/6.7"  "6.7\" iPhone 15 Pro Max (1290x2796)" "required" 3
check_dir "ios/5.5"  "5.5\" iPhone 8 Plus (1242x2208)"     "required" 3
check_dir "ios/ipad" "12.9\" iPad Pro (2048x2732)"          "recommended" 3

echo ""
echo "Google Play Store:"
check_dir "android/phone"  "Phone (1080x1920)"       "required" 2
check_dir "android/7inch"  "7\" Tablet (1200x1920)"  "recommended" 2
check_dir "android/10inch" "10\" Tablet (1600x2560)" "recommended" 2

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $WARN warnings ==="

if [ "$FAIL" -gt 0 ]; then
  echo "Screenshot verification FAILED — missing required screenshots."
  exit 1
else
  echo "Screenshot verification PASSED."
  exit 0
fi
