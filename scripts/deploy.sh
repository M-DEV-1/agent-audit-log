#!/usr/bin/env bash
# CLI deployment automation for agent-audit-log
# Handles build, validation, deployment to Vercel, and post-deploy verification

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_DIR="$PROJECT_ROOT/web"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=false
SKIP_TESTS=false
SKIP_SMOKE=false
TARGET_ENV="production"
VERCEL_PROJECT="agent-audit-log"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        --skip-smoke)
            SKIP_SMOKE=true
            shift
            ;;
        --env)
            TARGET_ENV="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run       Validate without deploying"
            echo "  --skip-tests    Skip pre-deployment tests"
            echo "  --skip-smoke    Skip post-deployment smoke tests"
            echo "  --env ENV       Target environment (production|preview)"
            echo "  -h, --help      Show this help"
            echo ""
            echo "Examples:"
            echo "  $0                    # Full deploy to production"
            echo "  $0 --dry-run          # Validate only"
            echo "  $0 --env preview      # Deploy to preview"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Step 1: Pre-flight checks
log_info "Running pre-flight checks..."

if ! command -v vercel &> /dev/null; then
    log_error "Vercel CLI not found. Install: npm install -g vercel"
    exit 1
fi

if ! command -v node &> /dev/null; then
    log_error "Node.js not found. Please install Node.js."
    exit 1
fi

if [[ ! -f "$WEB_DIR/package.json" ]]; then
    log_error "Web project not found at $WEB_DIR"
    exit 1
fi

log_success "Pre-flight checks passed"

# Step 2: Git status check
log_info "Checking git status..."
cd "$PROJECT_ROOT"

if [[ -n $(git status --porcelain) ]]; then
    log_warning "Uncommitted changes detected:"
    git status --short
    
    if [[ "$DRY_RUN" == false ]]; then
        read -p "Continue with deployment? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_error "Deployment cancelled"
            exit 1
        fi
    fi
fi

CURRENT_COMMIT=$(git rev-parse HEAD)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
log_success "Git: $CURRENT_BRANCH @ ${CURRENT_COMMIT:0:7}"

# Step 3: Run pre-deployment validation
if [[ "$SKIP_TESTS" == false ]]; then
    log_info "Running pre-deployment validation..."
    
    if [[ -x "$SCRIPT_DIR/pre-deploy.sh" ]]; then
        if ! bash "$SCRIPT_DIR/pre-deploy.sh"; then
            log_error "Pre-deployment validation failed"
            exit 1
        fi
        log_success "Pre-deployment validation passed"
    else
        log_warning "Pre-deploy script not found or not executable"
    fi
else
    log_warning "Skipping pre-deployment tests (--skip-tests)"
fi

# Step 4: Build the application
log_info "Building web application..."
cd "$WEB_DIR"

BUILD_START=$(date +%s)
if npm run build; then
    BUILD_END=$(date +%s)
    BUILD_TIME=$((BUILD_END - BUILD_START))
    log_success "Build completed in ${BUILD_TIME}s"
else
    log_error "Build failed"
    exit 1
fi

# Step 5: Deploy to Vercel
if [[ "$DRY_RUN" == true ]]; then
    log_warning "Dry run mode - skipping deployment"
    log_info "Would deploy to: $TARGET_ENV"
    exit 0
fi

log_info "Deploying to Vercel ($TARGET_ENV)..."

DEPLOY_ARGS=""
if [[ "$TARGET_ENV" == "production" ]]; then
    DEPLOY_ARGS="--prod"
fi

DEPLOY_OUTPUT=$(vercel $DEPLOY_ARGS --yes 2>&1) || {
    log_error "Deployment failed"
    echo "$DEPLOY_OUTPUT"
    exit 1
}

# Extract deployment URL
DEPLOY_URL=$(echo "$DEPLOY_OUTPUT" | grep -oP 'https://[^\s]+\.vercel\.app' | head -1)

if [[ -z "$DEPLOY_URL" ]]; then
    log_error "Could not extract deployment URL"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

log_success "Deployed to: $DEPLOY_URL"

# Step 6: Wait for deployment to be ready
log_info "Waiting for deployment to be ready..."
MAX_WAIT=120
WAIT_COUNT=0

while [[ $WAIT_COUNT -lt $MAX_WAIT ]]; do
    if curl -sf --max-time 5 "$DEPLOY_URL" > /dev/null 2>&1; then
        log_success "Deployment is live!"
        break
    fi
    
    sleep 2
    WAIT_COUNT=$((WAIT_COUNT + 2))
    
    if [[ $((WAIT_COUNT % 10)) -eq 0 ]]; then
        log_info "Still waiting... (${WAIT_COUNT}s/${MAX_WAIT}s)"
    fi
done

if [[ $WAIT_COUNT -ge $MAX_WAIT ]]; then
    log_error "Deployment did not become ready within ${MAX_WAIT}s"
    exit 1
fi

# Step 7: Run smoke tests
if [[ "$SKIP_SMOKE" == false ]]; then
    log_info "Running smoke tests against deployment..."
    
    if [[ -x "$SCRIPT_DIR/smoke-test.sh" ]]; then
        if bash "$SCRIPT_DIR/smoke-test.sh" "$DEPLOY_URL"; then
            log_success "Smoke tests passed"
        else
            log_error "Smoke tests failed"
            log_warning "Deployment completed but validation failed"
            exit 1
        fi
    else
        log_warning "Smoke test script not found or not executable"
    fi
else
    log_warning "Skipping smoke tests (--skip-smoke)"
fi

# Step 8: Summary
echo ""
echo "═══════════════════════════════════════"
log_success "Deployment Complete!"
echo "═══════════════════════════════════════"
echo ""
echo "Environment:    $TARGET_ENV"
echo "Commit:         ${CURRENT_COMMIT:0:7}"
echo "Branch:         $CURRENT_BRANCH"
echo "Build Time:     ${BUILD_TIME}s"
echo "Deployment URL: $DEPLOY_URL"
echo ""

# Production-specific aliases
if [[ "$TARGET_ENV" == "production" ]]; then
    log_info "Production aliases:"
    echo "  • https://agent-audit.mdev1.me"
    echo "  • https://web-1lcvrabsc-mahadevans-projects.vercel.app"
fi

echo ""
log_success "Ready for verification!"
