#!/usr/bin/env bash
# Batch verification tool - verify entire commit ranges at once
# Usage: verify-batch.sh [start-commit]..[end-commit]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

COMMIT_RANGE=""
VERBOSE=false
JSON_OUTPUT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        --json) JSON_OUTPUT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [start]..[end] [--verbose] [--json output.json]"
            echo ""
            echo "Verify all traces in a commit range."
            echo ""
            echo "Examples:"
            echo "  $0 HEAD~10..HEAD"
            echo "  $0 abc123..def456 --json report.json"
            echo "  $0 --verbose HEAD~5..HEAD"
            exit 0
            ;;
        *) COMMIT_RANGE="$1"; shift ;;
    esac
done

if [[ -z "$COMMIT_RANGE" ]]; then
    echo -e "${RED}Error: No commit range provided${NC}"
    echo "Usage: $0 [start]..[end]"
    exit 1
fi

cd "$PROJECT_ROOT"

# Get list of commits
COMMITS=$(git rev-list --reverse "$COMMIT_RANGE" 2>/dev/null || {
    echo -e "${RED}Error: Invalid commit range${NC}"
    exit 1
})

TOTAL=$(echo "$COMMITS" | wc -l)
PASSED=0
FAILED=0
MISSING=0

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}Batch Verification Report${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Range:${NC} $COMMIT_RANGE"
echo -e "${BLUE}Commits:${NC} $TOTAL"
echo ""

RESULTS="[]"

for COMMIT in $COMMITS; do
    COMMIT_SHORT="${COMMIT:0:7}"
    
    # Check if trace exists
    TRACE_FILE=$(find .agent-trace -name "${COMMIT}*.json" 2>/dev/null | head -1)
    
    if [[ -z "$TRACE_FILE" ]]; then
        echo -e "${YELLOW}⚠${NC} $COMMIT_SHORT - No trace file found"
        MISSING=$((MISSING + 1))
        RESULTS=$(echo "$RESULTS" | jq --arg commit "$COMMIT" '. += [{commit: $commit, status: "missing"}]')
        continue
    fi
    
    # Run verification
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}Verifying:${NC} $COMMIT_SHORT"
    fi
    
    if bash "$SCRIPT_DIR/verify-trace.sh" "$COMMIT" > /dev/null 2>&1; then
        if [[ "$VERBOSE" == true ]]; then
            echo -e "${GREEN}✓${NC} $COMMIT_SHORT - PASSED"
        else
            echo -ne "${GREEN}✓${NC}"
        fi
        PASSED=$((PASSED + 1))
        RESULTS=$(echo "$RESULTS" | jq --arg commit "$COMMIT" '. += [{commit: $commit, status: "passed"}]')
    else
        echo -e "${RED}✗${NC} $COMMIT_SHORT - FAILED"
        FAILED=$((FAILED + 1))
        RESULTS=$(echo "$RESULTS" | jq --arg commit "$COMMIT" '. += [{commit: $commit, status: "failed"}]')
    fi
done

[[ "$VERBOSE" == false ]] && echo ""

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Passed:${NC}  $PASSED / $TOTAL"
echo -e "${RED}Failed:${NC}  $FAILED / $TOTAL"
echo -e "${YELLOW}Missing:${NC} $MISSING / $TOTAL"
echo ""

SUCCESS_RATE=$(echo "scale=1; ($PASSED / $TOTAL) * 100" | bc)
echo -e "${BLUE}Success Rate:${NC} ${SUCCESS_RATE}%"

# Save JSON report
if [[ -n "$JSON_OUTPUT" ]]; then
    REPORT=$(jq -n \
        --arg range "$COMMIT_RANGE" \
        --arg total "$TOTAL" \
        --arg passed "$PASSED" \
        --arg failed "$FAILED" \
        --arg missing "$MISSING" \
        --arg rate "$SUCCESS_RATE" \
        --argjson results "$RESULTS" \
        '{
            range: $range,
            timestamp: (now | todate),
            total: ($total | tonumber),
            passed: ($passed | tonumber),
            failed: ($failed | tonumber),
            missing: ($missing | tonumber),
            success_rate: ($rate | tonumber),
            results: $results
        }')
    
    echo "$REPORT" > "$JSON_OUTPUT"
    echo ""
    echo -e "${BLUE}Report saved:${NC} $JSON_OUTPUT"
fi

echo ""

if [[ "$FAILED" -gt 0 ]]; then
    echo -e "${RED}✗ Verification FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Verification PASSED${NC}"
    exit 0
fi
