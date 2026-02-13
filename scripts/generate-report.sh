#!/usr/bin/env bash
# Verification report generator - creates detailed HTML/Markdown reports
# Usage: generate-report.sh [--html|--md] [--output file]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

FORMAT="html"
OUTPUT=""
COMMIT_RANGE="HEAD~20..HEAD"

while [[ $# -gt 0 ]]; do
    case $1 in
        --html) FORMAT="html"; shift ;;
        --md|--markdown) FORMAT="md"; shift ;;
        -o|--output) OUTPUT="$2"; shift 2 ;;
        --range) COMMIT_RANGE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Generate verification reports with statistics and graphs."
            echo ""
            echo "Options:"
            echo "  --html              HTML format (default)"
            echo "  --md, --markdown    Markdown format"
            echo "  -o, --output FILE   Output file"
            echo "  --range RANGE       Commit range (default: HEAD~20..HEAD)"
            echo ""
            echo "Examples:"
            echo "  $0 --html -o report.html"
            echo "  $0 --md --range HEAD~50..HEAD"
            exit 0
            ;;
        *) echo "Unknown: $1"; exit 1 ;;
    esac
done

[[ -z "$OUTPUT" ]] && OUTPUT="verification-report.$FORMAT"

cd "$PROJECT_ROOT"

# Run batch verification
TEMP_JSON=$(mktemp)
bash scripts/verify-batch.sh "$COMMIT_RANGE" --json "$TEMP_JSON" > /dev/null 2>&1 || true

TOTAL=$(jq -r '.total // 0' "$TEMP_JSON")
PASSED=$(jq -r '.passed // 0' "$TEMP_JSON")
FAILED=$(jq -r '.failed // 0' "$TEMP_JSON")
MISSING=$(jq -r '.missing // 0' "$TEMP_JSON")
RATE=$(jq -r '.success_rate // 0' "$TEMP_JSON")

if [[ "$FORMAT" == "html" ]]; then
    cat > "$OUTPUT" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Agent Audit Log - Verification Report</title>
    <style>
        body { font-family: system-ui, -apple-system, sans-serif; max-width: 900px; margin: 40px auto; padding: 20px; background: #0f172a; color: #e2e8f0; }
        h1 { color: #10b981; border-bottom: 2px solid #10b981; padding-bottom: 10px; }
        h2 { color: #38bdf8; margin-top: 30px; }
        .metric { display: inline-block; padding: 20px; margin: 10px; background: #1e293b; border-radius: 8px; min-width: 150px; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; margin: 10px 0; }
        .passed { color: #10b981; }
        .failed { color: #ef4444; }
        .missing { color: #f59e0b; }
        .progress-bar { width: 100%; height: 30px; background: #1e293b; border-radius: 5px; overflow: hidden; margin: 20px 0; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #10b981, #38bdf8); transition: width 0.3s; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #334155; }
        th { background: #1e293b; color: #38bdf8; }
        tr:hover { background: #1e293b; }
        .badge { padding: 4px 8px; border-radius: 4px; font-size: 0.85em; font-weight: bold; }
        .badge-pass { background: #065f46; color: #10b981; }
        .badge-fail { background: #7f1d1d; color: #ef4444; }
        .badge-missing { background: #78350f; color: #f59e0b; }
        footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #334155; color: #64748b; font-size: 0.9em; }
    </style>
</head>
<body>
    <h1>🔍 Verification Report</h1>
    <p><strong>Generated:</strong> $(date -u +"%Y-%m-%d %H:%M:%S UTC")</p>
    <p><strong>Commit Range:</strong> <code>$COMMIT_RANGE</code></p>
    
    <h2>📊 Summary Statistics</h2>
    <div>
        <div class="metric">
            <div>Total Commits</div>
            <div class="metric-value">$TOTAL</div>
        </div>
        <div class="metric">
            <div>Passed</div>
            <div class="metric-value passed">$PASSED</div>
        </div>
        <div class="metric">
            <div>Failed</div>
            <div class="metric-value failed">$FAILED</div>
        </div>
        <div class="metric">
            <div>Missing</div>
            <div class="metric-value missing">$MISSING</div>
        </div>
        <div class="metric">
            <div>Success Rate</div>
            <div class="metric-value passed">${RATE}%</div>
        </div>
    </div>
    
    <h2>📈 Progress</h2>
    <div class="progress-bar">
        <div class="progress-fill" style="width: ${RATE}%"></div>
    </div>
    
    <h2>📋 Verification Results</h2>
    <table>
        <thead>
            <tr>
                <th>Commit</th>
                <th>Status</th>
            </tr>
        </thead>
        <tbody>
EOF

    jq -r '.results[] | "\(.commit[0:7])\t\(.status)"' "$TEMP_JSON" | while IFS=$'\t' read -r commit status; do
        case "$status" in
            passed) badge="badge-pass" text="✓ PASSED" ;;
            failed) badge="badge-fail" text="✗ FAILED" ;;
            missing) badge="badge-missing" text="⚠ MISSING" ;;
        esac
        echo "            <tr><td><code>$commit</code></td><td><span class=\"badge $badge\">$text</span></td></tr>" >> "$OUTPUT"
    done

    cat >> "$OUTPUT" << EOF
        </tbody>
    </table>
    
    <h2>✅ Verification Criteria</h2>
    <ul>
        <li>RFC 0.1.0 schema compliance</li>
        <li>SHA-256 hash integrity</li>
        <li>Solana devnet anchoring</li>
        <li>AI tool attribution</li>
    </ul>
    
    <footer>
        <p>Generated by agent-audit-log verification suite</p>
        <p><a href="https://github.com/M-DEV-1/agent-audit-log" style="color: #38bdf8;">GitHub Repository</a></p>
    </footer>
</body>
</html>
EOF

else
    cat > "$OUTPUT" << EOF
# Verification Report

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")  
**Commit Range:** \`$COMMIT_RANGE\`

## Summary Statistics

| Metric | Value |
|--------|-------|
| Total Commits | $TOTAL |
| Passed | $PASSED |
| Failed | $FAILED |
| Missing | $MISSING |
| Success Rate | ${RATE}% |

## Verification Results

| Commit | Status |
|--------|--------|
EOF

    jq -r '.results[] | "\(.commit[0:7]) | \(.status)"' "$TEMP_JSON" | while IFS='|' read -r commit status; do
        case "$status" in
            *passed*) emoji="✓" ;;
            *failed*) emoji="✗" ;;
            *missing*) emoji="⚠" ;;
        esac
        echo "| \`$commit\` | $emoji $status |" >> "$OUTPUT"
    done

    cat >> "$OUTPUT" << EOF

## Verification Criteria

- RFC 0.1.0 schema compliance
- SHA-256 hash integrity
- Solana devnet anchoring
- AI tool attribution

---

Generated by [agent-audit-log](https://github.com/M-DEV-1/agent-audit-log)
EOF
fi

rm -f "$TEMP_JSON"

echo "✓ Report generated: $OUTPUT"
[[ "$FORMAT" == "html" ]] && echo "  Open in browser: file://$(realpath "$OUTPUT")"
