#!/usr/bin/env bash
# Bulk trace downloader - fetch all traces from repository for external verification
# Useful for judges, auditors, or third-party verification

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

OUTPUT_DIR="traces-export"
FORMAT="json"
INCLUDE_LEGACY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
        --csv) FORMAT="csv"; shift ;;
        --legacy) INCLUDE_LEGACY=true; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Download all traces for external verification."
            echo ""
            echo "Options:"
            echo "  -o, --output DIR   Output directory (default: traces-export)"
            echo "  --csv              Export as CSV instead of JSON"
            echo "  --legacy           Include legacy traces"
            echo "  -h, --help         Show this help"
            echo ""
            echo "Examples:"
            echo "  $0"
            echo "  $0 -o my-traces --csv"
            echo "  $0 --legacy"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

cd "$PROJECT_ROOT"

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}Bulk Trace Downloader${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"
echo -e "${BLUE}Output directory:${NC} $OUTPUT_DIR"
echo -e "${BLUE}Format:${NC} $FORMAT"
echo ""

# Copy RFC traces
RFC_COUNT=0
if [[ -d ".agent-trace" ]]; then
    echo -e "${BLUE}Copying RFC 0.1.0 traces...${NC}"
    for trace in .agent-trace/*.json; do
        [[ -f "$trace" ]] || continue
        cp "$trace" "$OUTPUT_DIR/"
        RFC_COUNT=$((RFC_COUNT + 1))
    done
    echo -e "${GREEN}✓${NC} Copied $RFC_COUNT RFC traces"
fi

# Copy legacy traces if requested
LEGACY_COUNT=0
if [[ "$INCLUDE_LEGACY" == true && -d "traces" ]]; then
    echo -e "${BLUE}Copying legacy traces...${NC}"
    for trace in traces/*.json; do
        [[ -f "$trace" ]] || continue
        cp "$trace" "$OUTPUT_DIR/"
        LEGACY_COUNT=$((LEGACY_COUNT + 1))
    done
    echo -e "${GREEN}✓${NC} Copied $LEGACY_COUNT legacy traces"
fi

TOTAL=$((RFC_COUNT + LEGACY_COUNT))

# Generate CSV if requested
if [[ "$FORMAT" == "csv" ]]; then
    echo ""
    echo -e "${BLUE}Generating CSV export...${NC}"
    
    CSV_FILE="$OUTPUT_DIR/traces.csv"
    echo "id,timestamp,commit,tool,model,trace_hash,tx_hash,file_count" > "$CSV_FILE"
    
    for trace in "$OUTPUT_DIR"/*.json; do
        [[ -f "$trace" ]] || continue
        
        ID=$(jq -r '.id // ""' "$trace")
        TS=$(jq -r '.timestamp // ""' "$trace")
        COMMIT=$(jq -r '.vcs.revision // ""' "$trace")
        TOOL=$(jq -r '.tool.name // ""' "$trace")
        MODEL=$(jq -r '.tool.version // ""' "$trace")
        HASH=$(jq -r '.metadata.trace_hash // ""' "$trace")
        TX=$(jq -r '.metadata.solana_anchor.tx_hash // ""' "$trace")
        FILES=$(jq '.files | length' "$trace")
        
        echo "$ID,$TS,$COMMIT,$TOOL,$MODEL,$HASH,$TX,$FILES" >> "$CSV_FILE"
    done
    
    echo -e "${GREEN}✓${NC} CSV export: $CSV_FILE"
fi

# Generate manifest
MANIFEST="$OUTPUT_DIR/manifest.json"
jq -n \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg rfc "$RFC_COUNT" \
    --arg legacy "$LEGACY_COUNT" \
    --arg total "$TOTAL" \
    --arg format "$FORMAT" \
    '{
        export_timestamp: $ts,
        rfc_traces: ($rfc | tonumber),
        legacy_traces: ($legacy | tonumber),
        total_traces: ($total | tonumber),
        format: $format,
        verification_tool: "scripts/verify-trace.sh"
    }' > "$MANIFEST"

echo -e "${GREEN}✓${NC} Manifest: $MANIFEST"

# Create README
cat > "$OUTPUT_DIR/README.md" << 'EOF'
# Trace Export

This directory contains all traces from the agent-audit-log repository.

## Verification

To verify a trace:

```bash
# Single trace
bash scripts/verify-trace.sh <commit-sha>

# Batch verification
bash scripts/verify-batch.sh HEAD~10..HEAD
```

## Trace Format

All traces follow RFC 0.1.0 specification:
- Version: 1.0
- UUID identifier
- Timestamp (ISO 8601)
- VCS revision (Git SHA)
- Tool attribution (AI model)
- File contributions
- Solana anchor (devnet)
- SHA-256 hash integrity

## Solana Verification

Each trace is anchored on Solana devnet. View anchors at:
https://solscan.io/tx/<tx_hash>?cluster=devnet

## AI Authorship

These traces prove 100% AI authorship via:
1. RFC 0.1.0 compliance
2. Cryptographic hash integrity
3. On-chain Solana anchoring
4. Tool attribution metadata

For questions, see: https://github.com/M-DEV-1/agent-audit-log
EOF

echo -e "${GREEN}✓${NC} README: $OUTPUT_DIR/README.md"

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Total traces exported:${NC} $TOTAL"
echo -e "${BLUE}RFC traces:${NC} $RFC_COUNT"
[[ "$INCLUDE_LEGACY" == true ]] && echo -e "${BLUE}Legacy traces:${NC} $LEGACY_COUNT"
echo -e "${BLUE}Output:${NC} $OUTPUT_DIR"
echo ""
echo -e "${GREEN}✓ Export complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Verify traces: bash scripts/verify-batch.sh HEAD~10..HEAD"
echo "  2. Share traces: zip -r traces-export.zip $OUTPUT_DIR"
echo "  3. Publish: Upload to verification platform"
echo ""
