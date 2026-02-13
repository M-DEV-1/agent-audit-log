# Verification Guide

**Complete guide to verifying AI authorship for agent-audit-log commits.**

---

## Quick Start (30 seconds)

### Option 1: Web Verification
1. Visit https://agent-audit.mdev1.me/verify
2. Paste a commit SHA or trace JSON
3. Click "Verify"
4. ✅ See instant validation results

### Option 2: CLI Verification
```bash
# Verify single commit
bash scripts/verify-trace.sh <commit-sha>

# Verify commit range
bash scripts/verify-batch.sh HEAD~10..HEAD
```

---

## What Gets Verified?

Every verification checks:

1. ✅ **RFC 0.1.0 Schema Compliance** - Trace follows official specification
2. ✅ **SHA-256 Hash Integrity** - Cryptographic proof of data integrity
3. ✅ **Solana Anchor** - On-chain proof on Solana devnet
4. ✅ **AI Tool Attribution** - Model ID and tool metadata present

---

## Step-by-Step: Web Verification

### Method A: Verify by Commit SHA

**Step 1:** Get a commit SHA
```bash
git log --oneline | head -5
```

**Step 2:** Copy a commit SHA (first 7-40 characters)
```
3f123c6
```

**Step 3:** Visit `/verify` page
- Open: https://agent-audit.mdev1.me/verify
- Paste commit SHA in the input field
- Click "Verify"

**Step 4:** Review results
- ✅ Green checkmarks = PASS
- ❌ Red X = FAIL
- See detailed breakdown of each validation step

### Method B: Verify by Trace JSON

**Step 1:** Get a trace file
```bash
cat .agent-trace/<commit-sha>.json
```

**Step 2:** Copy entire JSON content

**Step 3:** Visit `/verify` page
- Paste JSON into input field
- Click "Verify"

**Step 4:** See validation results with trace metadata

---

## Step-by-Step: CLI Verification

### Single Commit Verification

**Step 1:** Navigate to repository
```bash
cd agent-audit-log
```

**Step 2:** Run verification script
```bash
bash scripts/verify-trace.sh <commit-sha>
```

**Example:**
```bash
bash scripts/verify-trace.sh 3f123c6
```

**Step 3:** Read output
```
🔍 Verifying trace for commit: 3f123c6

✓ Trace file found
✓ RFC 0.1.0 schema valid
✓ SHA-256 hash verified
✓ Solana anchor confirmed

Trace Hash: a1b2c3d4...
Solana TX:  https://solscan.io/tx/xyz?cluster=devnet

✓ Verification PASSED
```

### Batch Verification

**Step 1:** Choose commit range
```bash
# Last 10 commits
bash scripts/verify-batch.sh HEAD~10..HEAD

# Specific range
bash scripts/verify-batch.sh abc123..def456

# All commits
bash scripts/verify-batch.sh --all
```

**Step 2:** Review summary
```
═══════════════════════════════════════
Batch Verification Report
═══════════════════════════════════════

Range:    HEAD~10..HEAD
Commits:  10

✓✓✓✓✓✓✓✓✓✓

═══════════════════════════════════════
Summary
═══════════════════════════════════════

Passed:  10 / 10
Failed:  0 / 10
Missing: 0 / 10

Success Rate: 100%

✓ Verification PASSED
```

**Step 3:** (Optional) Save JSON report
```bash
bash scripts/verify-batch.sh HEAD~10..HEAD --json report.json
```

---

## Step-by-Step: Generate Report

### HTML Report (Shareable)

**Step 1:** Generate HTML report
```bash
bash scripts/generate-report.sh --html -o verification-report.html
```

**Step 2:** Open in browser
```bash
# macOS
open verification-report.html

# Linux
xdg-open verification-report.html

# Or manually open file:// URL
```

**Step 3:** Share report
- Email as attachment
- Upload to file host
- Commit to repository

### Markdown Report (GitHub-friendly)

**Step 1:** Generate Markdown
```bash
bash scripts/generate-report.sh --md -o VERIFICATION.md
```

**Step 2:** View or commit
```bash
# View
cat VERIFICATION.md

# Commit
git add VERIFICATION.md
git commit -m "docs: add verification report"
```

---

## Step-by-Step: Bulk Export

**For judges/auditors who want all traces:**

**Step 1:** Download all traces
```bash
bash scripts/download-traces.sh -o traces-export
```

**Step 2:** Review export
```bash
cd traces-export
ls -la  # See all trace JSON files
cat manifest.json  # See metadata
```

**Step 3:** (Optional) Export as CSV
```bash
bash scripts/download-traces.sh --csv -o traces-export
cat traces-export/traces.csv
```

**Step 4:** Share traces
```bash
# Create archive
zip -r traces-export.zip traces-export

# Or tar
tar czf traces-export.tar.gz traces-export
```

---

## Step-by-Step: Check Anchor Health

**Step 1:** Run health check
```bash
bash scripts/check-anchors.sh
```

**Step 2:** Review coverage
```
═══════════════════════════════════════
Solana Anchor Health Check
═══════════════════════════════════════

Wallet:  7kr9BpCqQhLt9g97Y2WJpATqd5pL8KbZf6DNE5fDdq1e
Network: devnet

Total traces: 69

Anchored:   69 / 69
Unanchored: 0 / 69

Coverage: 100%
████████████████████████████████████████ 100%

✓ All traces properly anchored!
```

**Step 3:** (Optional) Check missing traces
```bash
bash scripts/detect-missing.sh
```

---

## Troubleshooting

### Problem: Trace not found

**Error:**
```
✗ Trace file not found for commit: abc123
```

**Solution:**
1. Check if commit exists: `git show abc123`
2. Look for trace file: `ls .agent-trace/abc123*.json`
3. If missing, run: `bash scripts/detect-missing.sh`

### Problem: Hash verification failed

**Error:**
```
✗ SHA-256 hash mismatch
```

**Cause:** Trace file was modified after creation

**Solution:** Trace is invalid. Do not trust this commit.

### Problem: Solana anchor not confirmed

**Error:**
```
⚠ Solana transaction not found
```

**Solution:**
1. Check devnet status: https://status.solana.com/
2. Wait a few seconds and retry
3. Verify transaction on Solscan (link in trace)

### Problem: API endpoint not responding

**Error:**
```
Failed to fetch /api/verify
```

**Solution:**
1. Check deployment: https://agent-audit.mdev1.me
2. Verify Vercel is online
3. Use CLI verification as fallback

---

## For Judges: Quick Audit Checklist

### 5-Minute Audit
1. ✅ Visit https://agent-audit.mdev1.me
2. ✅ Check dashboard shows recent traces
3. ✅ Click "Verify Proof" on any trace
4. ✅ Confirm Solana anchor links work
5. ✅ Run: `bash scripts/verify-batch.sh HEAD~20..HEAD`

### 15-Minute Deep Audit
1. ✅ Clone repository
2. ✅ Run: `bash scripts/download-traces.sh`
3. ✅ Run: `bash scripts/check-anchors.sh -v`
4. ✅ Run: `bash scripts/generate-report.sh --html`
5. ✅ Review HTML report in browser
6. ✅ Spot-check 5 random traces manually
7. ✅ Verify Solscan links are valid

### 30-Minute Comprehensive Audit
1. ✅ All steps from 15-minute audit
2. ✅ Run: `bash scripts/verify-batch.sh --all`
3. ✅ Check schema: `cat TRACE_SCHEMA.md`
4. ✅ Validate trace hashes with `jq`:
   ```bash
   for f in .agent-trace/*.json; do
     bash scripts/verify-trace.sh $(basename "$f" .json)
   done
   ```
5. ✅ Review GitHub Actions CI logs
6. ✅ Test `/verify` API endpoint with curl
7. ✅ Verify commit authorship attribution

---

## Advanced: Manual Verification

If you want to verify without scripts:

### Verify Hash Integrity

```bash
TRACE=".agent-trace/<commit-sha>.json"

# Extract hash from trace
STORED_HASH=$(jq -r '.metadata.trace_hash' "$TRACE")

# Compute hash from canonical JSON
COMPUTED_HASH=$(jq -cS 'del(.metadata.trace_hash, .metadata.trace_hash_scope, .metadata.solana_anchor)' "$TRACE" | shasum -a 256 | awk '{print $1}')

# Compare
if [[ "$STORED_HASH" == "$COMPUTED_HASH" ]]; then
  echo "✓ Hash valid"
else
  echo "✗ Hash mismatch"
fi
```

### Verify Solana Anchor

```bash
TX_HASH=$(jq -r '.metadata.solana_anchor.tx_hash' "$TRACE")
curl "https://api.devnet.solana.com" \
  -X POST \
  -H "Content-Type: application/json" \
  -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getTransaction\",\"params\":[\"$TX_HASH\",{\"encoding\":\"json\"}]}"
```

Or view on Solscan:
```
https://solscan.io/tx/$TX_HASH?cluster=devnet
```

### Verify RFC 0.1.0 Schema

```bash
# Check required fields
jq 'has("version") and has("id") and has("timestamp") and has("vcs") and has("tool") and has("files")' "$TRACE"

# Validate version
jq -e '.version == "1.0"' "$TRACE"

# Check AI contributor
jq -e '.files[].conversations[].contributor.type == "ai"' "$TRACE"
```

---

## FAQ

**Q: How long does verification take?**  
A: ~2 seconds per trace (web/CLI). Batch verification processes 5-10 traces/second.

**Q: Can I verify offline?**  
A: Yes for hash/schema checks. Solana anchor verification requires internet.

**Q: Are old commits verifiable?**  
A: Yes! All 69 commits have permanent traces and Solana anchors.

**Q: What if Solana devnet goes down?**  
A: Trace files and hashes remain valid. Devnet transactions are permanent once confirmed.

**Q: Can traces be faked?**  
A: No. Hash integrity + Solana anchoring make forgery cryptographically infeasible.

**Q: How do I verify the verifier?**  
A: All scripts are open source. Read `scripts/verify-trace.sh` - it's ~200 lines of bash.

---

## Support

- **Documentation:** https://github.com/M-DEV-1/agent-audit-log
- **Live Demo:** https://agent-audit.mdev1.me
- **Issues:** https://github.com/M-DEV-1/agent-audit-log/issues

---

**Last Updated:** 2026-02-13  
**Version:** 1.0  
**Commit:** 69/500 (13.8%)
