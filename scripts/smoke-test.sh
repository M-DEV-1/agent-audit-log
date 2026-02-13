#!/bin/bash
# Smoke test suite for post-deployment validation
# Runs quick checks against deployed site to verify functionality

set -e

# Configuration
TARGET_URL="${1:-http://localhost:3000}"
TIMEOUT=10

echo "🔥 Smoke Test Suite"
echo "==================="
echo "Target: $TARGET_URL"
echo ""

PASSED=0
FAILED=0

# Helper function for tests
run_test() {
    local name="$1"
    local command="$2"
    
    echo -n "Testing: $name... "
    if eval "$command" > /dev/null 2>&1; then
        echo "✓ PASS"
        PASSED=$((PASSED + 1))
    else
        echo "✗ FAIL"
        FAILED=$((FAILED + 1))
    fi
}

# 1. Homepage availability
run_test "Homepage responds" \
    "curl -f -s -m $TIMEOUT '$TARGET_URL' > /dev/null"

# 2. Homepage contains expected content
run_test "Homepage contains 'Agent Audit Log'" \
    "curl -s -m $TIMEOUT '$TARGET_URL' | grep -q 'Agent Audit Log'"

# 3. Check for Next.js markers
run_test "Next.js static markers present" \
    "curl -s -m $TIMEOUT '$TARGET_URL' | grep -q 'next'"

# 4. Response time check (should respond within timeout)
run_test "Homepage responds within ${TIMEOUT}s" \
    "time timeout $TIMEOUT curl -s '$TARGET_URL' > /dev/null"

# 5. Check HTTP status code
run_test "Homepage returns 200 OK" \
    "curl -s -o /dev/null -w '%{http_code}' '$TARGET_URL' | grep -q '^200$'"

# 6. Check for critical text: "RFC 0.1.0"
run_test "RFC 0.1.0 compliance mentioned" \
    "curl -s -m $TIMEOUT '$TARGET_URL' | grep -q 'RFC'"

# 7. Check for trace-related content
run_test "Trace content visible" \
    "curl -s -m $TIMEOUT '$TARGET_URL' | grep -iq 'trace'"

# 8. Check for Solana-related content
run_test "Solana integration mentioned" \
    "curl -s -m $TIMEOUT '$TARGET_URL' | grep -iq 'solana'"

# 9. Check for basic rendering (presence of key content)
run_test "Dashboard content renders" \
    "curl -s -m $TIMEOUT '$TARGET_URL' | grep -q 'Trace Intelligence Dashboard'"

# 10. Check Content-Type header
run_test "Content-Type is HTML" \
    "curl -s -I -m $TIMEOUT '$TARGET_URL' | grep -q 'text/html'"

# Summary
echo ""
echo "==================="
echo "📊 Test Results"
echo "==================="
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo "Total:  $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✅ All smoke tests passed!"
    exit 0
else
    echo "❌ $FAILED test(s) failed!"
    exit 1
fi
