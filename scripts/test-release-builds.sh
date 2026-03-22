#!/usr/bin/env bash
# ==============================================================================
# Test: Release builds succeed for both iOS and Android
# ==============================================================================
# Verifies acceptance criterion for US-GCG-17:
#   "Release builds succeed for both iOS and Android"
#
# Checks:
#   1. Flutter SDK is available
#   2. Flutter project is valid (pubspec.yaml, platform dirs)
#   3. Android release build succeeds (flutter build apk --release)
#   4. iOS release build succeeds (flutter build ios --release --no-codesign)
#   5. Build artifacts are created
#   6. Environment config files exist for prod builds
#
# Usage:
#   ./scripts/test-release-builds.sh [--android-only | --ios-only]
#
# Environment:
#   iOS builds require macOS with Xcode installed.
#   Android builds require the Android SDK.
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

ANDROID_ONLY=false
IOS_ONLY=false
for arg in "$@"; do
  case "$arg" in
    --android-only) ANDROID_ONLY=true ;;
    --ios-only)     IOS_ONLY=true ;;
  esac
done

echo "=== Test: Release Builds ==="
echo ""

# --------------------------------------------------------------------------
# 1. Flutter SDK is available
# --------------------------------------------------------------------------
echo "[1/6] Flutter SDK available..."
if command -v flutter >/dev/null 2>&1; then
  FLUTTER_VERSION=$(flutter --version --machine 2>/dev/null | head -1 || flutter --version 2>&1 | head -1)
  pass "Flutter SDK found: $FLUTTER_VERSION"
else
  fail "Flutter SDK not found in PATH"
  echo ""
  echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
  echo "VERDICT: FAIL — Flutter SDK is required for release builds"
  exit 1
fi

# --------------------------------------------------------------------------
# 2. Flutter project is valid
# --------------------------------------------------------------------------
echo "[2/6] Flutter project structure..."
ERRORS=""
if [ ! -f "$APP_DIR/pubspec.yaml" ]; then
  ERRORS="$ERRORS pubspec.yaml"
fi
if [ ! -d "$APP_DIR/lib" ]; then
  ERRORS="$ERRORS lib/"
fi
if [ ! -f "$APP_DIR/lib/main.dart" ]; then
  ERRORS="$ERRORS lib/main.dart"
fi

if [ -z "$ERRORS" ]; then
  pass "Flutter project structure is valid"
else
  fail "Missing project files:$ERRORS"
  echo ""
  echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
  echo "VERDICT: FAIL — Flutter project is incomplete"
  exit 1
fi

# Check platform directories have native files
if [ "$IOS_ONLY" = false ]; then
  if [ ! -f "$APP_DIR/android/app/build.gradle" ] && [ ! -f "$APP_DIR/android/app/build.gradle.kts" ]; then
    fail "Android native project not initialized (run 'flutter create .' in $APP_DIR)"
  else
    pass "Android native project exists"
  fi
fi

if [ "$ANDROID_ONLY" = false ]; then
  if [ ! -d "$APP_DIR/ios/Runner.xcodeproj" ]; then
    if [[ "$(uname)" == "Darwin" ]]; then
      fail "iOS native project not initialized (run 'flutter create .' in $APP_DIR)"
    else
      skip "iOS native project check — not on macOS"
    fi
  else
    pass "iOS native project exists"
  fi
fi

# --------------------------------------------------------------------------
# 3. Android release build
# --------------------------------------------------------------------------
if [ "$IOS_ONLY" = false ]; then
  echo "[3/6] Android release build..."
  cd "$REPO_ROOT/$APP_DIR"
  if flutter build apk --release --dart-define-from-file=config/prod.env 2>&1; then
    pass "Android APK release build succeeded"
  else
    fail "Android APK release build failed"
  fi
  cd "$REPO_ROOT"
else
  echo "[3/6] Android release build..."
  skip "Android build skipped (--ios-only)"
fi

# --------------------------------------------------------------------------
# 4. iOS release build
# --------------------------------------------------------------------------
if [ "$ANDROID_ONLY" = false ]; then
  echo "[4/6] iOS release build..."
  if [[ "$(uname)" != "Darwin" ]]; then
    skip "iOS build requires macOS with Xcode — skipping on $(uname)"
  else
    if ! command -v xcodebuild >/dev/null 2>&1; then
      skip "Xcode not installed — cannot build iOS"
    else
      cd "$REPO_ROOT/$APP_DIR"
      # Use --no-codesign for CI environments without provisioning profiles
      if flutter build ios --release --no-codesign --dart-define-from-file=config/prod.env 2>&1; then
        pass "iOS release build succeeded"
      else
        fail "iOS release build failed"
      fi
      cd "$REPO_ROOT"
    fi
  fi
else
  echo "[4/6] iOS release build..."
  skip "iOS build skipped (--android-only)"
fi

# --------------------------------------------------------------------------
# 5. Build artifacts exist
# --------------------------------------------------------------------------
echo "[5/6] Build artifacts..."
if [ "$IOS_ONLY" = false ]; then
  APK_PATH="$APP_DIR/build/app/outputs/flutter-apk/app-release.apk"
  if [ -f "$APK_PATH" ]; then
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    pass "Android APK exists ($APK_SIZE): $APK_PATH"
  else
    if [ "$IOS_ONLY" = true ]; then
      skip "Android APK check skipped"
    else
      fail "Android APK not found at $APK_PATH"
    fi
  fi
fi

if [ "$ANDROID_ONLY" = false ]; then
  IOS_APP_DIR="$APP_DIR/build/ios/iphoneos/Runner.app"
  if [ -d "$IOS_APP_DIR" ]; then
    pass "iOS app bundle exists: $IOS_APP_DIR"
  else
    if [[ "$(uname)" != "Darwin" ]]; then
      skip "iOS artifact check — not on macOS"
    else
      fail "iOS app bundle not found at $IOS_APP_DIR"
    fi
  fi
fi

# --------------------------------------------------------------------------
# 6. Production environment config
# --------------------------------------------------------------------------
echo "[6/6] Production environment config..."
if [ -f "$APP_DIR/config/prod.env" ]; then
  # Verify required keys are present
  MISSING_KEYS=""
  for KEY in ENV API_BASE_URL; do
    if ! grep -q "^$KEY=" "$APP_DIR/config/prod.env" 2>/dev/null; then
      MISSING_KEYS="$MISSING_KEYS $KEY"
    fi
  done
  if [ -z "$MISSING_KEYS" ]; then
    pass "Production config has all required keys"
  else
    fail "Production config missing keys:$MISSING_KEYS"
  fi
else
  fail "Production config not found at $APP_DIR/config/prod.env"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
if [ "$FAIL" -gt 0 ]; then
  echo "VERDICT: FAIL — Release builds did not all succeed"
  exit 1
else
  if [ "$SKIP" -gt 0 ]; then
    echo "VERDICT: PASS (with skips) — All runnable builds succeeded"
  else
    echo "VERDICT: PASS — Release builds succeed for both iOS and Android"
  fi
  exit 0
fi
