#!/usr/bin/env bash
# ==============================================================================
# Firebase App Registration Script
# ==============================================================================
# Registers iOS and Android apps in the Firebase project, downloads config files,
# and generates a service account key for the backend.
#
# Prerequisites:
#   - Firebase CLI installed: npm install -g firebase-tools
#   - Logged in: firebase login
#   - Flutter platform dirs created: cd src/app && flutter create .
#
# Usage:
#   ./scripts/firebase-setup.sh
# ==============================================================================

set -euo pipefail

PROJECT_ID="gocalgo"
ANDROID_PACKAGE="com.gocalgo.app"
IOS_BUNDLE_ID="com.gocalgo.app"
APP_DIR="src/app"

echo "=== Firebase App Registration ==="
echo "Project: $PROJECT_ID"
echo ""

# ---- 1. Register Android app ------------------------------------------------
echo "[1/4] Registering Android app ($ANDROID_PACKAGE)..."
firebase apps:create android "$ANDROID_PACKAGE" \
  --project "$PROJECT_ID" \
  --package-name "$ANDROID_PACKAGE" \
  || echo "  (Android app may already exist — continuing)"

# ---- 2. Register iOS app ----------------------------------------------------
echo "[2/4] Registering iOS app ($IOS_BUNDLE_ID)..."
firebase apps:create ios "$IOS_BUNDLE_ID" \
  --project "$PROJECT_ID" \
  --bundle-id "$IOS_BUNDLE_ID" \
  || echo "  (iOS app may already exist — continuing)"

# ---- 3. Download config files -----------------------------------------------
echo "[3/4] Downloading config files..."

# Get Android app ID and download google-services.json
ANDROID_APP_ID=$(firebase apps:list --project "$PROJECT_ID" --filter=ANDROID -j \
  | python3 -c "import sys,json; apps=json.load(sys.stdin); print([a['appId'] for a in apps if a.get('packageName')=='$ANDROID_PACKAGE'][0])" 2>/dev/null || true)

if [ -n "$ANDROID_APP_ID" ]; then
  mkdir -p "$APP_DIR/android/app"
  firebase apps:sdkconfig android "$ANDROID_APP_ID" \
    --project "$PROJECT_ID" \
    --out "$APP_DIR/android/app/google-services.json"
  echo "  -> $APP_DIR/android/app/google-services.json"
else
  echo "  WARNING: Could not determine Android app ID. Download google-services.json manually."
fi

# Get iOS app ID and download GoogleService-Info.plist
IOS_APP_ID=$(firebase apps:list --project "$PROJECT_ID" --filter=IOS -j \
  | python3 -c "import sys,json; apps=json.load(sys.stdin); print([a['appId'] for a in apps if a.get('bundleId')=='$IOS_BUNDLE_ID'][0])" 2>/dev/null || true)

if [ -n "$IOS_APP_ID" ]; then
  mkdir -p "$APP_DIR/ios/Runner"
  firebase apps:sdkconfig ios "$IOS_APP_ID" \
    --project "$PROJECT_ID" \
    --out "$APP_DIR/ios/Runner/GoogleService-Info.plist"
  echo "  -> $APP_DIR/ios/Runner/GoogleService-Info.plist"
else
  echo "  WARNING: Could not determine iOS app ID. Download GoogleService-Info.plist manually."
fi

# ---- 4. Generate service account key ----------------------------------------
echo "[4/4] Generating Firebase Admin SDK service account key..."
SA_NAME="gocalgo-backend"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
KEY_FILE="src/backend/firebase-service-account.json"

# Create service account (may already exist)
gcloud iam service-accounts create "$SA_NAME" \
  --project "$PROJECT_ID" \
  --display-name "GoCalGo Backend" \
  2>/dev/null || echo "  (Service account may already exist)"

# Grant Firebase messaging permissions
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member "serviceAccount:$SA_EMAIL" \
  --role "roles/firebase.sdkAdminServiceAgent" \
  --quiet 2>/dev/null || true

# Download key
gcloud iam service-accounts keys create "$KEY_FILE" \
  --iam-account "$SA_EMAIL" \
  --project "$PROJECT_ID"
echo "  -> $KEY_FILE"

echo ""
echo "=== Done ==="
echo ""
echo "Next steps:"
echo "  1. Verify google-services.json is at:       $APP_DIR/android/app/google-services.json"
echo "  2. Verify GoogleService-Info.plist is at:    $APP_DIR/ios/Runner/GoogleService-Info.plist"
echo "  3. Verify service account key is at:         $KEY_FILE"
echo "  4. Set FIREBASE_CREDENTIALS_JSON=$KEY_FILE in your .env"
echo "  5. These credential files are git-ignored — do NOT commit them"
