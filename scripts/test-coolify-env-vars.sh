#!/usr/bin/env bash
# ==============================================================================
# Test: Environment variables configured in Coolify for DB and Redis connections
# ==============================================================================
# Verifies acceptance criterion for US-GCG-3:
#   "Environment variables configured in Coolify for DB and Redis connections"
#
# Checks:
#   1. .env.example documents all required PostgreSQL variables
#   2. .env.example documents all required Redis variables
#   3. docker-compose.yml references DB vars in the API connection string
#   4. docker-compose.yml references Redis in the API connection string
#   5. Connection string formats are valid for ASP.NET Core
#
# Usage:
#   ./scripts/test-coolify-env-vars.sh
# ==============================================================================

set -uo pipefail

PASS=0
FAIL=0
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$REPO_ROOT"

pass() { echo "  PASS: $1"; ((PASS++)); }
fail() { echo "  FAIL: $1"; ((FAIL++)); }

echo "=== Test: Environment Variables for DB and Redis Connections ==="
echo ""

# --------------------------------------------------------------------------
# 1. .env.example documents required PostgreSQL variables
# --------------------------------------------------------------------------
echo "[1/5] PostgreSQL variables in .env.example..."

PG_VARS=("POSTGRES_HOST" "POSTGRES_PORT" "POSTGRES_DB" "POSTGRES_USER" "POSTGRES_PASSWORD")
PG_MISSING=()

if [ ! -f ".env.example" ]; then
  fail ".env.example not found"
  echo ""
  echo "=== Results: $PASS passed, $FAIL failed ==="
  echo "VERDICT: FAIL — .env.example is required to document environment variables"
  exit 1
fi

for var in "${PG_VARS[@]}"; do
  if ! grep -q "^${var}=" .env.example; then
    PG_MISSING+=("$var")
  fi
done

if [ ${#PG_MISSING[@]} -eq 0 ]; then
  pass "All PostgreSQL variables documented in .env.example (${PG_VARS[*]})"
else
  fail "Missing PostgreSQL variables in .env.example: ${PG_MISSING[*]}"
fi

# --------------------------------------------------------------------------
# 2. .env.example documents required Redis variables
# --------------------------------------------------------------------------
echo "[2/5] Redis variables in .env.example..."

REDIS_VARS=("REDIS_HOST" "REDIS_PORT")
REDIS_MISSING=()

for var in "${REDIS_VARS[@]}"; do
  if ! grep -q "^${var}=" .env.example; then
    REDIS_MISSING+=("$var")
  fi
done

if [ ${#REDIS_MISSING[@]} -eq 0 ]; then
  pass "All Redis variables documented in .env.example (${REDIS_VARS[*]})"
else
  fail "Missing Redis variables in .env.example: ${REDIS_MISSING[*]}"
fi

# --------------------------------------------------------------------------
# 3. docker-compose.yml wires DB vars into API service connection string
# --------------------------------------------------------------------------
echo "[3/5] API service uses DB environment variables in connection string..."

COMPOSE="docker-compose.yml"
if [ ! -f "$COMPOSE" ]; then
  fail "docker-compose.yml not found"
  echo ""
  echo "=== Results: $PASS passed, $FAIL failed ==="
  echo "VERDICT: FAIL — docker-compose.yml is required"
  exit 1
fi

# Check that the API service has a PostgreSQL connection string using env vars
if grep -q 'ConnectionStrings__PostgreSQL' "$COMPOSE" && \
   grep 'ConnectionStrings__PostgreSQL' "$COMPOSE" | grep -q 'POSTGRES_DB' && \
   grep 'ConnectionStrings__PostgreSQL' "$COMPOSE" | grep -q 'POSTGRES_USER' && \
   grep 'ConnectionStrings__PostgreSQL' "$COMPOSE" | grep -q 'POSTGRES_PASSWORD'; then
  pass "API service PostgreSQL connection string references POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD"
else
  fail "API service missing or incomplete PostgreSQL connection string in docker-compose.yml"
fi

# --------------------------------------------------------------------------
# 4. docker-compose.yml wires Redis into API service
# --------------------------------------------------------------------------
echo "[4/5] API service uses Redis connection string..."

if grep -q 'ConnectionStrings__Redis' "$COMPOSE"; then
  pass "API service has Redis connection string (ConnectionStrings__Redis)"
else
  fail "API service missing Redis connection string in docker-compose.yml"
fi

# --------------------------------------------------------------------------
# 5. Connection string formats are valid for ASP.NET Core
# --------------------------------------------------------------------------
echo "[5/5] Connection string format validation..."

# PostgreSQL: should follow Npgsql format "Host=...;Port=...;Database=...;Username=...;Password=..."
PG_CONN=$(grep 'ConnectionStrings__PostgreSQL' "$COMPOSE" 2>/dev/null || true)
PG_OK=true

if [ -n "$PG_CONN" ]; then
  for keyword in "Host=" "Port=" "Database=" "Username=" "Password="; do
    if ! echo "$PG_CONN" | grep -q "$keyword"; then
      PG_OK=false
    fi
  done
fi

# Redis: should be a host:port string
REDIS_CONN=$(grep 'ConnectionStrings__Redis' "$COMPOSE" 2>/dev/null || true)

if $PG_OK && [ -n "$REDIS_CONN" ]; then
  pass "Connection strings follow expected ASP.NET Core / Npgsql / StackExchange.Redis format"
else
  fail "Connection string format issues detected"
fi

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -gt 0 ]; then
  echo "VERDICT: FAIL — Environment variables are not fully configured for DB and Redis"
  exit 1
else
  echo "VERDICT: PASS — Environment variables configured for DB and Redis connections"
  exit 0
fi
