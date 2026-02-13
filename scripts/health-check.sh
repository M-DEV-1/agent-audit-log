#!/bin/bash
# Deployment health check for agent-audit-log viewer
# Validates build, trace schema, and deployment readiness

set -e

echo "🔍 Agent Audit Log - Deployment Health Check"
echo "=============================================="

# Check Node.js version
echo "📦 Checking Node.js version..."
NODE_VERSION=$(node --version)
echo "   ✓ Node.js: $NODE_VERSION"

# Check if in web directory
if [ ! -f "package.json" ]; then
    echo "   ❌ Error: Must run from web/ directory"
    exit 1
fi

# Validate package.json
echo "📋 Validating package.json..."
if ! node -e "require('./package.json')" 2>/dev/null; then
    echo "   ❌ Invalid package.json"
    exit 1
fi
echo "   ✓ package.json is valid"

# Check dependencies
echo "📦 Checking dependencies..."
if [ ! -d "node_modules" ]; then
    echo "   ⚠️  node_modules not found, installing..."
    npm install
fi
echo "   ✓ Dependencies installed"

# Run TypeScript check
echo "🔍 Running TypeScript validation..."
npx tsc --noEmit || {
    echo "   ❌ TypeScript errors detected"
    exit 1
}
echo "   ✓ TypeScript validation passed"

# Run build
echo "🏗️  Building Next.js application..."
BUILD_OUTPUT=$(npm run build 2>&1)
if [ $? -ne 0 ]; then
    echo "   ❌ Build failed"
    echo "$BUILD_OUTPUT"
    exit 1
fi
echo "   ✓ Build completed successfully"

# Check trace files
echo "🔍 Validating trace files..."
TRACE_COUNT=$(find ../.agent-trace -name "*.json" 2>/dev/null | wc -l)
if [ "$TRACE_COUNT" -eq 0 ]; then
    echo "   ⚠️  No trace files found in .agent-trace/"
else
    echo "   ✓ Found $TRACE_COUNT trace files"
fi

# Validate trace schema (sample first trace)
if [ "$TRACE_COUNT" -gt 0 ]; then
    echo "🔍 Validating trace schema..."
    FIRST_TRACE=$(find ../.agent-trace -name "*.json" 2>/dev/null | head -1)
    if node -e "const t=require('$FIRST_TRACE'); if(!t.version||!t.id||!t.timestamp||!t.vcs) process.exit(1)" 2>/dev/null; then
        echo "   ✓ Trace schema validation passed"
    else
        echo "   ⚠️  Trace schema may be incomplete"
    fi
fi

# Check environment
echo "🌍 Checking deployment environment..."
if [ -n "$VERCEL" ]; then
    echo "   ✓ Running in Vercel environment"
    echo "   ✓ VERCEL_ENV: ${VERCEL_ENV:-not set}"
    echo "   ✓ VERCEL_URL: ${VERCEL_URL:-not set}"
else
    echo "   ℹ️  Not in Vercel environment (local build)"
fi

# Summary
echo ""
echo "=============================================="
echo "✅ Health check passed!"
echo "=============================================="
echo "📊 Build metrics:"
echo "   - Node.js: $NODE_VERSION"
echo "   - Traces: $TRACE_COUNT files"
echo "   - Status: Ready for deployment"
echo ""
