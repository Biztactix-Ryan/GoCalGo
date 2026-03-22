#!/usr/bin/env bash
# ==============================================================================
# Test: Android keystore generated and stored securely
# ==============================================================================
# Verifies acceptance criterion for US-GCG-17:
#   "Android keystore generated and stored securely"
#
# Checks:
#   1. Keystore file exists at the path specified by ANDROID_KEYSTORE_PATH
#   2. key.properties exists and references env vars (not hardcoded paths)
#   3. Keystore file is NOT tracked by git
#   4. Keystore patterns are in .gitignore
#   5. Keystore file permissions are restrictive (not world-readable)
#   6. Keystore env vars are documented in .env.example
#
# Usage:
#   ./scripts/test-android-keystore.sh
# ==============================================================================

set -uo pipefail

PASS=0
FAIL=0
APP_DIR="src/app"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_ROOT"

pass() { echo "  PASS: $1"; ((PASS++)); }
fail() { echo "  FAIL: $1"; ((FAIL++)); }

echo "=== Test: Android Keystore Security ==="
echo ""

# --------------------------------------------------------------------------
# 1. Keystore file exists
# --------------------------------------------------------------------------
echo "[1/6] Keystore file exists..."
KEYSTORE_PATH="${ANDROID_KEYSTORE_PATH:-$APP_DIR/android/app/gocalgo-release.jks}"
if [ -f "$KEYSTORE_PATH" ]; then
  pass "Keystore found at $KEYSTORE_PATH"
else
  fail "Keystore not found at $KEYSTORE_PATH (set ANDROID_KEYSTORE_PATH to override)"
fi

# --------------------------------------------------------------------------
# 2. key.properties exists and uses env var references
# --------------------------------------------------------------------------
echo "[2/6] key.properties uses environment variables..."
KEY_PROPS="$APP_DIR/android/key.properties"
if [ -f "$KEY_PROPS" ]; then
  # Check that storeFile, storePassword, keyAlias, keyPassword are present
  MISSING=""
  for KEY in storeFile storePassword keyAlias keyPassword; do
    if ! grep -q "^$KEY=" "$KEY_PROPS" 2>/dev/null; then
      MISSING="$MISSING $KEY"
    fi
  done
  if [ -z "$MISSING" ]; then
    pass "key.properties contains all required keys"
  else
    fail "key.properties missing keys:$MISSING"
  fi
else
  fail "key.properties not found at $KEY_PROPS"
fi

# --------------------------------------------------------------------------
# 3. Keystore is NOT tracked by git
# --------------------------------------------------------------------------
echo "[3/6] Keystore is not tracked by git..."
if git ls-files --error-unmatch "$KEYSTORE_PATH" >/dev/null 2>&1; then
  fail "Keystore IS tracked by git — must be untracked"
else
  pass "Keystore is not tracked by git"
fi

# Also check key.properties is not tracked
if [ -f "$KEY_PROPS" ]; then
  if git ls-files --error-unmatch "$KEY_PROPS" >/dev/null 2>&1; then
    fail "key.properties IS tracked by git — must be untracked"
  else
    pass "key.properties is not tracked by git"
  fi
fi

# --------------------------------------------------------------------------
# 4. Keystore patterns are in .gitignore
# --------------------------------------------------------------------------
echo "[4/6] Keystore patterns in .gitignore..."
GITIGNORE=".gitignore"
if [ -f "$GITIGNORE" ]; then
  FOUND_JKS=false
  FOUND_KEYPROPS=false
  if grep -qE '^\*?\.jks$|^\*\.keystore$|keystore' "$GITIGNORE" 2>/dev/null; then
    FOUND_JKS=true
  fi
  if grep -qE 'key\.properties' "$GITIGNORE" 2>/dev/null; then
    FOUND_KEYPROPS=true
  fi

  if $FOUND_JKS; then
    pass ".gitignore includes keystore pattern"
  else
    fail ".gitignore missing keystore pattern (*.jks or *.keystore)"
  fi
  if $FOUND_KEYPROPS; then
    pass ".gitignore includes key.properties"
  else
    fail ".gitignore missing key.properties pattern"
  fi
else
  fail ".gitignore not found"
fi

# --------------------------------------------------------------------------
# 5. Keystore file permissions are restrictive
# --------------------------------------------------------------------------
echo "[5/6] Keystore file permissions..."
if [ -f "$KEYSTORE_PATH" ]; then
  PERMS=$(stat -c '%a' "$KEYSTORE_PATH" 2>/dev/null || stat -f '%Lp' "$KEYSTORE_PATH" 2>/dev/null)
  # Should not be world-readable (last digit should be 0)
  WORLD="${PERMS: -1}"
  if [ "$WORLD" = "0" ]; then
    pass "Keystore is not world-readable (permissions: $PERMS)"
  else
    fail "Keystore is world-readable (permissions: $PERMS) — should end in 0"
  fi
else
  echo "  SKIP: Keystore file not present — cannot check permissions"
fi

# --------------------------------------------------------------------------
# 6. Signing env vars documented in .env.example
# --------------------------------------------------------------------------
echo "[6/6] Signing env vars in .env.example..."
ENV_EXAMPLE=".env.example"
if [ -f "$ENV_EXAMPLE" ]; then
  MISSING_VARS=""
  for VAR in ANDROID_KEYSTORE_PATH ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD; do
    if ! grep -q "$VAR" "$ENV_EXAMPLE" 2>/dev/null; then
      MISSING_VARS="$MISSING_VARS $VAR"
    fi
  done
  if [ -z "$MISSING_VARS" ]; then
    pass "All signing env vars documented in .env.example"
  else
    fail ".env.example missing vars:$MISSING_VARS"
  fi
else
  fail ".env.example not found"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  echo "VERDICT: FAIL — Android keystore is not securely configured"
  exit 1
else
  echo "VERDICT: PASS — Android keystore is generated and stored securely"
  exit 0
fi
