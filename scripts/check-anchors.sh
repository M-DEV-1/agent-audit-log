#!/usr/bin/env bash
# Anchor health checker - verify Solana anchor status and wallet balance
# Usage: check-anchors.sh [--verbose]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        -h|--help)
            echo "Usage: $0 [--verbose]"
            echo ""
            echo "Check Solana anchor health and wallet balance."
            echo ""
            echo "Options:"
            echo "  -v, --verbose   Show detailed output"
            echo ""
            exit 0
            ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

cd "$PROJECT_ROOT"

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}Solana Anchor Health Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Load wallet config
CONFIG_FILE="$HOME/.agentwallet/config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}✗ AgentWallet config not found${NC}"
    echo -e "  Expected: $CONFIG_FILE"
    exit 1
fi

WALLET_ADDRESS=$(jq -r '.solanaAddress' "$CONFIG_FILE")
NETWORK="devnet"

echo -e "${BLUE}Wallet:${NC} $WALLET_ADDRESS"
echo -e "${BLUE}Network:${NC} $NETWORK"
echo ""

# Check traces
TOTAL_TRACES=$(find .agent-trace -name "*.json" 2>/dev/null | wc -l)
echo -e "${BLUE}Total traces:${NC} $TOTAL_TRACES"

# Count anchored traces
ANCHORED=0
UNANCHORED=0
PENDING=0
FAILED=0

for trace in .agent-trace/*.json; do
    [[ -f "$trace" ]] || continue
    
    TX_HASH=$(jq -r '.metadata.solana_anchor.tx_hash // empty' "$trace")
    
    if [[ -z "$TX_HASH" ]]; then
        UNANCHORED=$((UNANCHORED + 1))
        [[ "$VERBOSE" == true ]] && echo -e "${YELLOW}⚠${NC} Unanchored: $(basename "$trace")"
    else
        ANCHORED=$((ANCHORED + 1))
        
        # Check status if available
        STATUS=$(jq -r '.metadata.solana_anchor.status // "unknown"' "$trace")
        case "$STATUS" in
            completed|success) ;;
            pending) PENDING=$((PENDING + 1)) ;;
            failed|error) FAILED=$((FAILED + 1)) ;;
        esac
        
        [[ "$VERBOSE" == true ]] && echo -e "${GREEN}✓${NC} Anchored: $(basename "$trace") ($STATUS)"
    fi
done

echo ""
echo -e "${GREEN}Anchored:${NC}   $ANCHORED / $TOTAL_TRACES"
echo -e "${YELLOW}Unanchored:${NC} $UNANCHORED / $TOTAL_TRACES"
[[ $PENDING -gt 0 ]] && echo -e "${BLUE}Pending:${NC}    $PENDING"
[[ $FAILED -gt 0 ]] && echo -e "${RED}Failed:${NC}     $FAILED"

COVERAGE=$(echo "scale=1; ($ANCHORED / $TOTAL_TRACES) * 100" | bc)
echo ""
echo -e "${BLUE}Coverage:${NC} ${COVERAGE}%"

# Progress bar
BAR_WIDTH=40
FILLED=$(echo "scale=0; ($COVERAGE / 100) * $BAR_WIDTH" | bc)
BAR=$(printf "%${FILLED}s" | tr ' ' '█')
EMPTY=$(printf "%$((BAR_WIDTH - FILLED))s" | tr ' ' '░')
echo -e "${GREEN}${BAR}${NC}${EMPTY} ${COVERAGE}%"

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}Recommendations${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

if [[ $UNANCHORED -gt 0 ]]; then
    echo -e "${YELLOW}⚠${NC} $UNANCHORED traces without anchors"
    echo -e "  Run: python3 solana_anchor.py <commit-sha>"
    echo ""
fi

if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}✗${NC} $FAILED failed anchors"
    echo -e "  Check wallet balance and retry"
    echo ""
fi

if [[ $PENDING -gt 0 ]]; then
    echo -e "${BLUE}ℹ${NC} $PENDING pending anchors"
    echo -e "  Wait for blockchain confirmation"
    echo ""
fi

# Wallet balance check (requires solana CLI)
if command -v solana &> /dev/null; then
    echo -e "${BLUE}Checking wallet balance...${NC}"
    BALANCE=$(solana balance "$WALLET_ADDRESS" --url devnet 2>/dev/null || echo "unknown")
    if [[ "$BALANCE" != "unknown" ]]; then
        echo -e "${BLUE}Balance:${NC} $BALANCE"
        
        # Parse balance (assuming format "X SOL")
        AMOUNT=$(echo "$BALANCE" | awk '{print $1}')
        if (( $(echo "$AMOUNT < 1" | bc -l) )); then
            echo -e "${YELLOW}⚠${NC} Low balance - request airdrop:"
            echo -e "  solana airdrop 2 $WALLET_ADDRESS --url devnet"
        else
            echo -e "${GREEN}✓${NC} Balance sufficient"
        fi
    fi
    echo ""
else
    echo -e "${YELLOW}ℹ${NC} Install solana CLI to check wallet balance"
    echo -e "  https://docs.solana.com/cli/install-solana-cli-tools"
    echo ""
fi

# Summary
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}Health Status${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

if [[ $UNANCHORED -eq 0 && $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All traces properly anchored!${NC}"
    EXIT_CODE=0
elif (( $(echo "$COVERAGE >= 95" | bc -l) )); then
    echo -e "${GREEN}✓ Coverage above 95%${NC}"
    EXIT_CODE=0
elif (( $(echo "$COVERAGE >= 80" | bc -l) )); then
    echo -e "${YELLOW}⚠ Coverage at ${COVERAGE}% - consider backfilling${NC}"
    EXIT_CODE=1
else
    echo -e "${RED}✗ Coverage at ${COVERAGE}% - action required${NC}"
    EXIT_CODE=1
fi

echo ""

exit $EXIT_CODE
