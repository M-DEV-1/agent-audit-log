#!/usr/bin/env bash
# Local development setup script for agent-audit-log
# Installs dependencies, verifies environment, and starts dev server.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}  Agent Audit Log — Dev Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# ── Prerequisites ────────────────────────────────────────────────

check_cmd() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 found: $(command -v "$1")"
        return 0
    else
        echo -e "${RED}✗${NC} $1 not found"
        return 1
    fi
}

MISSING=0
echo -e "${BLUE}Checking prerequisites…${NC}"
check_cmd node   || MISSING=$((MISSING + 1))
check_cmd npm    || MISSING=$((MISSING + 1))
check_cmd git    || MISSING=$((MISSING + 1))
check_cmd jq     || echo -e "${YELLOW}⚠${NC} jq not found (optional — needed for verify scripts)"
check_cmd python3 || echo -e "${YELLOW}⚠${NC} python3 not found (optional — needed for Python verify tools)"
echo ""

if [[ "$MISSING" -gt 0 ]]; then
    echo -e "${RED}Error: Missing $MISSING required tool(s). Install them and retry.${NC}"
    exit 1
fi

# ── Node version check ──────────────────────────────────────────

NODE_MAJOR=$(node -v | sed 's/^v//' | cut -d. -f1)
if [[ "$NODE_MAJOR" -lt 18 ]]; then
    echo -e "${RED}Error: Node.js >= 18 required (found v${NODE_MAJOR})${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Node.js $(node -v)"

# ── Install web viewer dependencies ─────────────────────────────

echo ""
echo -e "${BLUE}Installing web viewer dependencies…${NC}"
cd "$PROJECT_ROOT/web"

if [[ -f "package-lock.json" ]]; then
    npm ci --silent
else
    npm install --silent
fi

echo -e "${GREEN}✓${NC} Dependencies installed"

# ── Verify trace directory ──────────────────────────────────────

cd "$PROJECT_ROOT"

TRACE_COUNT=0
if [[ -d ".agent-trace" ]]; then
    TRACE_COUNT=$(find .agent-trace -name "*.json" | wc -l)
fi

echo ""
echo -e "${BLUE}Trace files:${NC} $TRACE_COUNT"

if [[ "$TRACE_COUNT" -eq 0 ]]; then
    echo -e "${YELLOW}⚠${NC} No trace files found. The viewer will show empty data."
fi

# ── Environment hints ───────────────────────────────────────────

echo ""
echo -e "${BLUE}Environment:${NC}"
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    echo -e "  ${GREEN}✓${NC} GITHUB_TOKEN set (remote trace loading enabled)"
else
    echo -e "  ${YELLOW}⚠${NC} GITHUB_TOKEN not set (will use local traces only)"
fi

# ── Start dev server ────────────────────────────────────────────

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Setup complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""
echo -e "Start the dev server with:"
echo -e "  ${BLUE}cd web && npm run dev${NC}"
echo ""
echo -e "Verify traces with:"
echo -e "  ${BLUE}bash scripts/verify-batch.sh HEAD~10..HEAD${NC}"
echo -e "  ${BLUE}python scripts/verify-batch.py HEAD~10..HEAD${NC}"
echo ""
