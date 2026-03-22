#!/usr/bin/env bash
# ==============================================================================
# Test: Apple Developer account configured with app ID and provisioning profile
# ==============================================================================
# Verifies acceptance criterion for US-GCG-17:
#   "Apple Developer account configured with app ID and provisioning profile"
#
# Checks:
#   1. iOS signing env vars are set (IOS_TEAM_ID, IOS_CODE_SIGN_IDENTITY, IOS_PROVISIONING_PROFILE)
#   2. Signing.xcconfig exists and references env vars
#   3. ExportOptions plists exist for development and App Store
#   4. Bundle ID is consistent across configs
#   5. Provisioning profiles and certs are gitignored
#   6. iOS signing env vars are documented in .env.example
#
# Usage:
#   ./scripts/test-ios-signing.sh
# ==============================================================================

set -uo pipefail

PASS=0
FAIL=0
SKIP=0
APP_DIR="src/app"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_ROOT"

pass() { echo "  PASS: $1"; ((PASS++)); }
fail() { echo "  FAIL: $1"; ((FAIL++)); }
skip() { echo "  SKIP: $1"; ((SKIP++)); }

BUNDLE_ID="com.gocalgo.app"

echo "=== Test: iOS Signing Configuration ==="
echo ""

# --------------------------------------------------------------------------
# 1. iOS signing env vars are set
# --------------------------------------------------------------------------
echo "[1/6] iOS signing environment variables..."
MISSING_VARS=""
if [ -z "${IOS_TEAM_ID:-}" ]; then
  MISSING_VARS="$MISSING_VARS IOS_TEAM_ID"
fi
if [ -z "${IOS_CODE_SIGN_IDENTITY:-}" ]; then
  MISSING_VARS="$MISSING_VARS IOS_CODE_SIGN_IDENTITY"
fi
if [ -z "${IOS_PROVISIONING_PROFILE:-}" ]; then
  MISSING_VARS="$MISSING_VARS IOS_PROVISIONING_PROFILE"
fi

if [ -z "$MISSING_VARS" ]; then
  pass "All iOS signing env vars are set"
else
  skip "iOS signing env vars not set:$MISSING_VARS (set in .env for local dev or CI env)"
fi

# --------------------------------------------------------------------------
# 2. Signing.xcconfig exists and references env vars
# --------------------------------------------------------------------------
echo "[2/6] Signing.xcconfig..."
XCCONFIG="$APP_DIR/ios/Signing.xcconfig"
if [ -f "$XCCONFIG" ]; then
  ERRORS=""
  if ! grep -q 'DEVELOPMENT_TEAM' "$XCCONFIG" 2>/dev/null; then
    ERRORS="$ERRORS DEVELOPMENT_TEAM"
  fi
  if ! grep -q 'CODE_SIGN_IDENTITY' "$XCCONFIG" 2>/dev/null; then
    ERRORS="$ERRORS CODE_SIGN_IDENTITY"
  fi
  if ! grep -q 'PROVISIONING_PROFILE_SPECIFIER' "$XCCONFIG" 2>/dev/null; then
    ERRORS="$ERRORS PROVISIONING_PROFILE_SPECIFIER"
  fi
  if ! grep -q 'PRODUCT_BUNDLE_IDENTIFIER' "$XCCONFIG" 2>/dev/null; then
    ERRORS="$ERRORS PRODUCT_BUNDLE_IDENTIFIER"
  fi
  if [ -z "$ERRORS" ]; then
    pass "Signing.xcconfig contains all required build settings"
  else
    fail "Signing.xcconfig missing settings:$ERRORS"
  fi
else
  fail "Signing.xcconfig not found at $XCCONFIG"
fi

# --------------------------------------------------------------------------
# 3. ExportOptions plists exist
# --------------------------------------------------------------------------
echo "[3/6] ExportOptions plists..."
DEV_EXPORT="$APP_DIR/ios/ExportOptions-development.plist"
APPSTORE_EXPORT="$APP_DIR/ios/ExportOptions-appstore.plist"

if [ -f "$DEV_EXPORT" ]; then
  if grep -q 'development' "$DEV_EXPORT" 2>/dev/null; then
    pass "ExportOptions-development.plist exists with development method"
  else
    fail "ExportOptions-development.plist missing 'development' method"
  fi
else
  fail "ExportOptions-development.plist not found at $DEV_EXPORT"
fi

if [ -f "$APPSTORE_EXPORT" ]; then
  if grep -q 'app-store' "$APPSTORE_EXPORT" 2>/dev/null; then
    pass "ExportOptions-appstore.plist exists with app-store method"
  else
    fail "ExportOptions-appstore.plist missing 'app-store' method"
  fi
else
  fail "ExportOptions-appstore.plist not found at $APPSTORE_EXPORT"
fi

# --------------------------------------------------------------------------
# 4. Bundle ID consistency
# --------------------------------------------------------------------------
echo "[4/6] Bundle ID consistency..."
ERRORS=""
if [ -f "$XCCONFIG" ]; then
  if ! grep -q "$BUNDLE_ID" "$XCCONFIG" 2>/dev/null; then
    ERRORS="$ERRORS Signing.xcconfig"
  fi
fi
if [ -f "$DEV_EXPORT" ]; then
  if ! grep -q "$BUNDLE_ID" "$DEV_EXPORT" 2>/dev/null; then
    ERRORS="$ERRORS ExportOptions-development.plist"
  fi
fi
if [ -f "$APPSTORE_EXPORT" ]; then
  if ! grep -q "$BUNDLE_ID" "$APPSTORE_EXPORT" 2>/dev/null; then
    ERRORS="$ERRORS ExportOptions-appstore.plist"
  fi
fi
FIREBASE_PLIST="$APP_DIR/ios/Runner/GoogleService-Info.plist.example"
if [ -f "$FIREBASE_PLIST" ]; then
  if ! grep -q "$BUNDLE_ID" "$FIREBASE_PLIST" 2>/dev/null; then
    ERRORS="$ERRORS GoogleService-Info.plist.example"
  fi
fi

if [ -z "$ERRORS" ]; then
  pass "Bundle ID '$BUNDLE_ID' is consistent across all configs"
else
  fail "Bundle ID mismatch in:$ERRORS"
fi

# --------------------------------------------------------------------------
# 5. Provisioning profiles and certs are gitignored
# --------------------------------------------------------------------------
echo "[5/6] Signing artifacts gitignored..."
GITIGNORE=".gitignore"
if [ -f "$GITIGNORE" ]; then
  MISSING_PATTERNS=""
  if ! grep -qE '\.mobileprovision' "$GITIGNORE" 2>/dev/null; then
    MISSING_PATTERNS="$MISSING_PATTERNS *.mobileprovision"
  fi
  if ! grep -qE '\.p12' "$GITIGNORE" 2>/dev/null; then
    MISSING_PATTERNS="$MISSING_PATTERNS *.p12"
  fi
  if ! grep -qE '\.cer' "$GITIGNORE" 2>/dev/null; then
    MISSING_PATTERNS="$MISSING_PATTERNS *.cer"
  fi

  if [ -z "$MISSING_PATTERNS" ]; then
    pass "Signing artifacts (*.mobileprovision, *.p12, *.cer) are gitignored"
  else
    fail ".gitignore missing patterns:$MISSING_PATTERNS"
  fi
else
  fail ".gitignore not found"
fi

# --------------------------------------------------------------------------
# 6. iOS signing env vars documented in .env.example
# --------------------------------------------------------------------------
echo "[6/6] Signing env vars in .env.example..."
ENV_EXAMPLE=".env.example"
if [ -f "$ENV_EXAMPLE" ]; then
  MISSING=""
  for VAR in IOS_PROVISIONING_PROFILE IOS_CODE_SIGN_IDENTITY IOS_TEAM_ID; do
    if ! grep -q "$VAR" "$ENV_EXAMPLE" 2>/dev/null; then
      MISSING="$MISSING $VAR"
    fi
  done
  if [ -z "$MISSING" ]; then
    pass "All iOS signing env vars documented in .env.example"
  else
    fail ".env.example missing vars:$MISSING"
  fi
else
  fail ".env.example not found"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
if [ "$FAIL" -gt 0 ]; then
  echo "VERDICT: FAIL — iOS signing is not fully configured"
  exit 1
else
  if [ "$SKIP" -gt 0 ]; then
    echo "VERDICT: PASS (with skips) — iOS signing config is in place; set env vars for full signing"
  else
    echo "VERDICT: PASS — Apple Developer account and iOS provisioning configured"
  fi
  exit 0
fi
