#!/bin/bash
# Pre-deployment validation script
# Runs before Vercel deployment to catch issues early

set -e

echo "🚀 Pre-Deployment Validation"
echo "=============================="

ERRORS=0

# 1. Check for uncommitted changes
echo "📝 Checking git status..."
if [ -n "$(git status --porcelain)" ]; then
    echo "   ⚠️  Warning: Uncommitted changes detected"
    git status --short
else
    echo "   ✓ Working tree clean"
fi

# 2. Verify all traces have Solana anchors
echo "🔗 Verifying Solana anchors..."
TOTAL_TRACES=$(find .agent-trace -name "*.json" 2>/dev/null | wc -l)
ANCHORED_TRACES=$(grep -l "solana_anchor" .agent-trace/*.json 2>/dev/null | wc -l)

if [ "$TOTAL_TRACES" -eq 0 ]; then
    echo "   ⚠️  No trace files found"
else
    UNANCHORED=$((TOTAL_TRACES - ANCHORED_TRACES))
    if [ "$UNANCHORED" -gt 0 ]; then
        echo "   ⚠️  $UNANCHORED traces missing Solana anchors"
        ERRORS=$((ERRORS + 1))
    else
        echo "   ✓ All $TOTAL_TRACES traces have Solana anchors"
    fi
fi

# 3. Validate trace schema compliance
echo "🔍 Validating trace schemas..."
INVALID_TRACES=0
for trace_file in .agent-trace/*.json; do
    if [ -f "$trace_file" ]; then
        if ! node -e "
            const t = require('./$trace_file');
            if (!t.version || !t.id || !t.timestamp || !t.vcs || !t.tool || !t.files) {
                console.error('Invalid trace: $trace_file');
                process.exit(1);
            }
        " 2>/dev/null; then
            INVALID_TRACES=$((INVALID_TRACES + 1))
        fi
    fi
done

if [ "$INVALID_TRACES" -gt 0 ]; then
    echo "   ⚠️  $INVALID_TRACES traces have schema issues"
    ERRORS=$((ERRORS + 1))
else
    echo "   ✓ All traces pass RFC 0.1.0 schema validation"
fi

# 4. Check Next.js configuration
echo "⚙️  Checking Next.js configuration..."
if [ ! -f "web/next.config.mjs" ] && [ ! -f "web/next.config.js" ]; then
    echo "   ❌ Missing Next.js config"
    ERRORS=$((ERRORS + 1))
else
    echo "   ✓ Next.js config found"
fi

# 5. Verify package.json scripts
echo "📦 Verifying package.json scripts..."
cd web
if ! node -e "const p=require('./package.json'); if(!p.scripts.build||!p.scripts.dev) process.exit(1)" 2>/dev/null; then
    echo "   ❌ Missing required scripts in package.json"
    ERRORS=$((ERRORS + 1))
else
    echo "   ✓ Required scripts present"
fi
cd ..

# 6. Check for large files
echo "📂 Checking for large files..."
LARGE_FILES=$(find . -type f -size +5M -not -path "*/node_modules/*" -not -path "*/.next/*" -not -path "*/.git/*" 2>/dev/null)
if [ -n "$LARGE_FILES" ]; then
    echo "   ⚠️  Large files detected (>5MB):"
    echo "$LARGE_FILES" | while read file; do
        SIZE=$(du -h "$file" | cut -f1)
        echo "      - $file ($SIZE)"
    done
else
    echo "   ✓ No large files detected"
fi

# 7. Verify critical documentation
echo "📚 Checking documentation..."
for doc in README.md TRACE_SCHEMA.md AGENT_MISSION.md; do
    if [ ! -f "$doc" ]; then
        echo "   ⚠️  Missing $doc"
    else
        echo "   ✓ $doc present"
    fi
done

# Summary
echo ""
echo "=============================="
if [ "$ERRORS" -eq 0 ]; then
    echo "✅ Pre-deployment validation passed!"
    echo "=============================="
    exit 0
else
    echo "❌ Pre-deployment validation failed!"
    echo "   Errors: $ERRORS"
    echo "=============================="
    exit 1
fi
