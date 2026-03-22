#!/usr/bin/env bash
# ==============================================================================
# Test: Coolify webhook triggers on push to main
# ==============================================================================
# Verifies acceptance criterion for US-GCG-3:
#   "Coolify webhook triggers on push to main"
#
# Checks:
#   1. GitHub CLI (gh) is available and authenticated
#   2. Repository has at least one webhook configured
#   3. A webhook is active and triggers on push events
#   4. Dockerfile exists at the expected path for Coolify to build
#   5. Default branch is 'main' (webhook should target this branch)
#
# Usage:
#   ./scripts/test-coolify-webhook.sh
#
# Environment:
#   Requires `gh` CLI authenticated with access to the repository.
#   COOLIFY_DOMAIN (optional): expected domain in webhook URL (e.g. "coolify.example.com")
# ==============================================================================

set -uo pipefail

PASS=0
FAIL=0
SKIP=0
REPO="Biztactix-Ryan/GoCalGo"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_ROOT"

pass() { echo "  PASS: $1"; ((PASS++)); }
fail() { echo "  FAIL: $1"; ((FAIL++)); }
skip() { echo "  SKIP: $1"; ((SKIP++)); }

echo "=== Test: Coolify Webhook Triggers on Push to Main ==="
echo ""

# --------------------------------------------------------------------------
# 1. GitHub CLI is available and authenticated
# --------------------------------------------------------------------------
echo "[1/5] GitHub CLI available and authenticated..."
if ! command -v gh >/dev/null 2>&1; then
  fail "GitHub CLI (gh) not found in PATH"
  echo ""
  echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
  echo "VERDICT: FAIL — gh CLI is required to verify webhook configuration"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  fail "GitHub CLI not authenticated (run 'gh auth login')"
  echo ""
  echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
  echo "VERDICT: FAIL — gh must be authenticated to check webhooks"
  exit 1
fi

pass "GitHub CLI is available and authenticated"

# --------------------------------------------------------------------------
# 2. Repository has webhooks configured
# --------------------------------------------------------------------------
echo "[2/5] Repository webhooks exist..."
HOOKS_JSON=$(gh api "repos/$REPO/hooks" 2>&1) || {
  fail "Could not fetch webhooks (check repository permissions)"
  echo "  Error: $HOOKS_JSON"
  echo ""
  echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
  echo "VERDICT: FAIL — Cannot access webhook configuration"
  exit 1
}

HOOK_COUNT=$(echo "$HOOKS_JSON" | jq 'length' 2>/dev/null)
if [ "$HOOK_COUNT" = "0" ] || [ -z "$HOOK_COUNT" ]; then
  fail "No webhooks configured on $REPO"
  echo ""
  echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
  echo "VERDICT: FAIL — Repository needs at least one webhook for Coolify"
  exit 1
fi

pass "Repository has $HOOK_COUNT webhook(s) configured"

# --------------------------------------------------------------------------
# 3. An active webhook triggers on push events
# --------------------------------------------------------------------------
echo "[3/5] Active webhook with push event..."
PUSH_HOOK=$(echo "$HOOKS_JSON" | jq '[.[] | select(.active == true and (.events | index("push")))] | length' 2>/dev/null)

if [ "$PUSH_HOOK" = "0" ] || [ -z "$PUSH_HOOK" ]; then
  # Also check for wildcard hooks that receive all events
  WILDCARD_HOOK=$(echo "$HOOKS_JSON" | jq '[.[] | select(.active == true and (.events | index("*")))] | length' 2>/dev/null)
  if [ "$WILDCARD_HOOK" != "0" ] && [ -n "$WILDCARD_HOOK" ]; then
    pass "Active webhook with wildcard (*) event subscription (includes push)"
  else
    fail "No active webhook subscribes to push events"
  fi
else
  pass "Found $PUSH_HOOK active webhook(s) subscribed to push events"
fi

# Check if Coolify domain matches (optional validation)
if [ -n "${COOLIFY_DOMAIN:-}" ]; then
  DOMAIN_MATCH=$(echo "$HOOKS_JSON" | jq --arg domain "$COOLIFY_DOMAIN" '[.[] | select(.active == true and (.config.url | contains($domain)))] | length' 2>/dev/null)
  if [ "$DOMAIN_MATCH" != "0" ] && [ -n "$DOMAIN_MATCH" ]; then
    pass "Webhook URL matches Coolify domain ($COOLIFY_DOMAIN)"
  else
    fail "No webhook URL contains Coolify domain ($COOLIFY_DOMAIN)"
  fi
else
  skip "COOLIFY_DOMAIN not set — cannot verify webhook points to Coolify instance"
fi

# --------------------------------------------------------------------------
# 4. Dockerfile exists for Coolify to build
# --------------------------------------------------------------------------
echo "[4/5] Dockerfile exists for Coolify build..."
if [ -f "src/backend/GoCalGo.Api/Dockerfile" ]; then
  pass "Dockerfile exists at src/backend/GoCalGo.Api/Dockerfile"
else
  fail "Dockerfile not found — Coolify needs a Dockerfile to build the container"
fi

# --------------------------------------------------------------------------
# 5. Default branch is 'main'
# --------------------------------------------------------------------------
echo "[5/5] Default branch is 'main'..."
DEFAULT_BRANCH=$(gh api "repos/$REPO" --jq '.default_branch' 2>/dev/null)
if [ "$DEFAULT_BRANCH" = "main" ]; then
  pass "Default branch is 'main' — push webhook will fire on merges to main"
else
  fail "Default branch is '$DEFAULT_BRANCH', expected 'main'"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="
if [ "$FAIL" -gt 0 ]; then
  echo "VERDICT: FAIL — Coolify webhook is not fully configured"
  exit 1
else
  if [ "$SKIP" -gt 0 ]; then
    echo "VERDICT: PASS (with skips) — Webhook is configured for push events on main"
  else
    echo "VERDICT: PASS — Coolify webhook triggers on push to main"
  fi
  exit 0
fi
