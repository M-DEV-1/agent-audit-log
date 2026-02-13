#!/usr/bin/env bash
# Missing trace detector - find commits without traces
# Usage: detect-missing.sh [--fix] [--range RANGE]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

FIX_MODE=false
COMMIT_RANGE="HEAD~50..HEAD"

while [[ $# -gt 0 ]]; do
    case $1 in
        --fix) FIX_MODE=true; shift ;;
        --range) COMMIT_RANGE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Detect commits missing RFC 0.1.0 traces."
            echo ""
            echo "Options:"
            echo "  --fix           Generate backfill script"
            echo "  --range RANGE   Commit range (default: HEAD~50..HEAD)"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 --range HEAD~100..HEAD"
            echo "  $0 --fix > backfill.sh"
            exit 0
            ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

cd "$PROJECT_ROOT"

echo -e "${BLUE}═══════════════════════════════════════${NC}" >&2
echo -e "${BLUE}Missing Trace Detector${NC}" >&2
echo -e "${BLUE}═══════════════════════════════════════${NC}" >&2
echo "" >&2
echo -e "${BLUE}Range:${NC} $COMMIT_RANGE" >&2
echo "" >&2

COMMITS=$(git rev-list --reverse "$COMMIT_RANGE" 2>/dev/null || {
    echo -e "${RED}Error: Invalid commit range${NC}" >&2
    exit 1
})

TOTAL=$(echo "$COMMITS" | wc -l)
MISSING=0
MISSING_LIST=""

for COMMIT in $COMMITS; do
    COMMIT_SHORT="${COMMIT:0:7}"
    
    # Check for trace file
    TRACE_FILE=$(find .agent-trace -name "${COMMIT}*.json" 2>/dev/null | head -1)
    
    if [[ -z "$TRACE_FILE" ]]; then
        MISSING=$((MISSING + 1))
        MISSING_LIST="$MISSING_LIST $COMMIT"
        
        SUBJECT=$(git log -1 --format=%s "$COMMIT")
        AUTHOR=$(git log -1 --format=%an "$COMMIT")
        DATE=$(git log -1 --format=%ai "$COMMIT")
        
        echo -e "${YELLOW}⚠${NC} $COMMIT_SHORT - $SUBJECT" >&2
        echo -e "   ${BLUE}Author:${NC} $AUTHOR" >&2
        echo -e "   ${BLUE}Date:${NC} $DATE" >&2
        echo "" >&2
    fi
done

echo -e "${BLUE}═══════════════════════════════════════${NC}" >&2
echo -e "${BLUE}Summary${NC}" >&2
echo -e "${BLUE}═══════════════════════════════════════${NC}" >&2
echo "" >&2
echo -e "${BLUE}Total commits:${NC} $TOTAL" >&2
echo -e "${YELLOW}Missing traces:${NC} $MISSING" >&2
echo -e "${GREEN}Has traces:${NC} $((TOTAL - MISSING))" >&2

if [[ $MISSING -eq 0 ]]; then
    echo "" >&2
    echo -e "${GREEN}✓ All commits have traces!${NC}" >&2
    exit 0
fi

COVERAGE=$(echo "scale=1; (($TOTAL - $MISSING) / $TOTAL) * 100" | bc)
echo -e "${BLUE}Coverage:${NC} ${COVERAGE}%" >&2

if [[ "$FIX_MODE" == true ]]; then
    echo "" >&2
    echo -e "${BLUE}Generating backfill script...${NC}" >&2
    echo "" >&2
    
    cat << 'BACKFILL_HEADER'
#!/usr/bin/env bash
# Auto-generated backfill script for missing traces
# Run this to generate traces for commits without them

set -euo pipefail

BACKFILL_HEADER

    echo "MISSING_COMMITS=("
    for COMMIT in $MISSING_LIST; do
        echo "    \"$COMMIT\""
    done
    echo ")"
    echo ""
    
    cat << 'BACKFILL_BODY'

for COMMIT in "${MISSING_COMMITS[@]}"; do
    echo "Processing: $COMMIT"
    
    # Get commit metadata
    PARENT=$(git log -1 --format=%P "$COMMIT" | awk '{print $1}')
    MESSAGE=$(git log -1 --format=%s "$COMMIT")
    AUTHOR=$(git log -1 --format=%an "$COMMIT")
    DATE=$(git log -1 --format=%aI "$COMMIT")
    
    # Get changed files
    FILES=$(git diff-tree --no-commit-id --name-only -r "$COMMIT")
    
    # Build trace record (simplified - customize as needed)
    python3 << TRACE
import json, hashlib, uuid
from datetime import datetime, timezone

commit_sha = "$COMMIT"
parent_sha = "$PARENT"

trace_record = {
    'version': '1.0',
    'id': str(uuid.uuid4()),
    'timestamp': "$DATE",
    'vcs': {'type': 'git', 'revision': commit_sha},
    'tool': {'name': 'github-copilot', 'version': 'claude-sonnet-4.5'},
    'files': [],
    'metadata': {
        'commit_message': "$MESSAGE",
        'parent_commit': parent_sha,
        'backfilled': True
    }
}

canonical = json.dumps(trace_record, sort_keys=True, separators=(',', ':'))
trace_hash = hashlib.sha256(canonical.encode('utf-8')).hexdigest()
trace_record['metadata']['trace_hash'] = trace_hash
trace_record['metadata']['trace_hash_scope'] = 'sha256(canonical(record_without_trace_hash))'

with open(f'.agent-trace/{commit_sha}.json', 'w') as f:
    json.dump(trace_record, f, indent=2)

print(f"✓ Generated trace for {commit_sha[:7]}")
TRACE

done

echo ""
echo "✓ Backfill complete!"
echo "Note: Solana anchoring not included - run solana_anchor.py separately"
BACKFILL_BODY

else
    echo "" >&2
    echo -e "${YELLOW}To generate backfill script: $0 --fix > backfill.sh${NC}" >&2
fi

echo "" >&2

if [[ $MISSING -gt 0 ]]; then
    exit 1
else
    exit 0
fi
