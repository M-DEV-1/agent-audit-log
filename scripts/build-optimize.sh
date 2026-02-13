#!/usr/bin/env bash
# Build optimization utilities for agent-audit-log
# Analyzes bundles, checks for dead code, validates optimizations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WEB_DIR="$PROJECT_ROOT/web"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
CHECK_BUNDLE=false
CHECK_UNUSED=false
CHECK_IMAGES=false
CHECK_CSS=false
CHECK_ALL=false
REPORT_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --bundle)
            CHECK_BUNDLE=true
            shift
            ;;
        --unused)
            CHECK_UNUSED=true
            shift
            ;;
        --images)
            CHECK_IMAGES=true
            shift
            ;;
        --css)
            CHECK_CSS=true
            shift
            ;;
        --all)
            CHECK_ALL=true
            CHECK_BUNDLE=true
            CHECK_UNUSED=true
            CHECK_IMAGES=true
            CHECK_CSS=true
            shift
            ;;
        --report)
            REPORT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --bundle        Analyze bundle size and composition"
            echo "  --unused        Check for unused dependencies"
            echo "  --images        Validate image optimizations"
            echo "  --css          Check CSS purging and optimization"
            echo "  --all          Run all checks"
            echo "  --report FILE  Save report to JSON file"
            echo "  -h, --help     Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --all"
            echo "  $0 --bundle --css"
            echo "  $0 --all --report optimization-report.json"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# If no checks specified, default to --all
if [[ "$CHECK_BUNDLE" == false && "$CHECK_UNUSED" == false && "$CHECK_IMAGES" == false && "$CHECK_CSS" == false ]]; then
    CHECK_ALL=true
    CHECK_BUNDLE=true
    CHECK_UNUSED=true
    CHECK_IMAGES=true
    CHECK_CSS=true
fi

# Helper functions
log_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
}

log_check() {
    echo -e "${BLUE}▶${NC} $1"
}

log_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_info() {
    echo -e "${MAGENTA}ℹ${NC} $1"
}

# Initialize report
REPORT='{}'
WARNINGS=0
ERRORS=0

# Bundle analysis
if [[ "$CHECK_BUNDLE" == true ]]; then
    log_section "Bundle Analysis"
    
    cd "$WEB_DIR"
    
    if [[ ! -d ".next" ]]; then
        log_error ".next directory not found. Run 'npm run build' first."
        ERRORS=$((ERRORS + 1))
    else
        log_check "Analyzing bundle sizes..."
        
        # Total bundle size
        TOTAL_SIZE=$(du -sk .next | cut -f1)
        TOTAL_SIZE_MB=$(echo "scale=2; $TOTAL_SIZE / 1024" | bc)
        
        if (( $(echo "$TOTAL_SIZE_MB > 10" | bc -l) )); then
            log_warning "Large bundle size: ${TOTAL_SIZE_MB}MB (consider optimization)"
            WARNINGS=$((WARNINGS + 1))
        else
            log_pass "Bundle size: ${TOTAL_SIZE_MB}MB (acceptable)"
        fi
        
        REPORT=$(echo "$REPORT" | jq --arg size "$TOTAL_SIZE_MB" '.bundle.total_mb = ($size | tonumber)')
        
        # Analyze chunks
        if [[ -d ".next/static/chunks" ]]; then
            CHUNK_COUNT=$(find .next/static/chunks -name "*.js" | wc -l)
            log_info "JavaScript chunks: $CHUNK_COUNT"
            
            # Find largest chunks
            echo ""
            log_check "Largest chunks:"
            find .next/static/chunks -name "*.js" -exec du -h {} + | sort -rh | head -5 | while read size file; do
                echo "  $size  $(basename $file)"
                
                # Warn about chunks > 500KB
                SIZE_KB=$(echo "$size" | grep -oP '^\d+' || echo "0")
                if [[ "$SIZE_KB" -gt 500 ]]; then
                    log_warning "Large chunk detected: $(basename $file) ($size)"
                    WARNINGS=$((WARNINGS + 1))
                fi
            done
            
            REPORT=$(echo "$REPORT" | jq --arg count "$CHUNK_COUNT" '.bundle.chunk_count = ($count | tonumber)')
        fi
    fi
fi

# Unused dependencies check
if [[ "$CHECK_UNUSED" == true ]]; then
    log_section "Unused Dependencies"
    
    cd "$WEB_DIR"
    
    if ! command -v npx &> /dev/null; then
        log_warning "npx not found, skipping dependency check"
        WARNINGS=$((WARNINGS + 1))
    else
        log_check "Checking for unused dependencies..."
        
        # Use depcheck if available
        if npx --version &> /dev/null; then
            DEPCHECK_OUTPUT=$(npx depcheck --json 2>/dev/null || echo '{"dependencies":[],"devDependencies":[]}')
            
            UNUSED_DEPS=$(echo "$DEPCHECK_OUTPUT" | jq -r '.dependencies[]?' 2>/dev/null || echo "")
            UNUSED_DEV=$(echo "$DEPCHECK_OUTPUT" | jq -r '.devDependencies[]?' 2>/dev/null || echo "")
            
            if [[ -n "$UNUSED_DEPS" ]]; then
                log_warning "Unused dependencies found:"
                echo "$UNUSED_DEPS" | while read dep; do
                    [[ -n "$dep" ]] && echo "  - $dep"
                done
                WARNINGS=$((WARNINGS + 1))
            else
                log_pass "No unused dependencies"
            fi
            
            if [[ -n "$UNUSED_DEV" ]]; then
                log_info "Unused devDependencies (consider removing):"
                echo "$UNUSED_DEV" | while read dep; do
                    [[ -n "$dep" ]] && echo "  - $dep"
                done
            fi
        else
            log_warning "depcheck not available"
        fi
    fi
fi

# Image optimization check
if [[ "$CHECK_IMAGES" == true ]]; then
    log_section "Image Optimization"
    
    cd "$WEB_DIR"
    
    log_check "Checking for unoptimized images..."
    
    # Check public directory for images
    if [[ -d "public" ]]; then
        IMAGE_COUNT=$(find public -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" \) 2>/dev/null | wc -l)
        
        if [[ "$IMAGE_COUNT" -eq 0 ]]; then
            log_pass "No static images found (using Next.js Image optimization)"
        else
            log_info "Static images found: $IMAGE_COUNT"
            
            # Check for large images
            LARGE_IMAGES=$(find public -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -size +500k 2>/dev/null)
            
            if [[ -n "$LARGE_IMAGES" ]]; then
                log_warning "Large images detected (>500KB):"
                echo "$LARGE_IMAGES" | while read img; do
                    SIZE=$(du -h "$img" | cut -f1)
                    echo "  $SIZE  $img"
                done
                WARNINGS=$((WARNINGS + 1))
            else
                log_pass "All images under 500KB"
            fi
        fi
        
        REPORT=$(echo "$REPORT" | jq --arg count "$IMAGE_COUNT" '.images.static_count = ($count | tonumber)')
    else
        log_info "No public directory found"
    fi
    
    # Check if Next.js Image component is used
    IMAGE_IMPORTS=$(grep -r "from 'next/image'" app 2>/dev/null | wc -l)
    IMAGE_IMPORTS=${IMAGE_IMPORTS:-0}
    if [[ "$IMAGE_IMPORTS" -gt 0 ]]; then
        log_pass "Using Next.js Image component ($IMAGE_IMPORTS imports)"
    else
        log_info "No Next.js Image imports found"
    fi
fi

# CSS optimization check
if [[ "$CHECK_CSS" == true ]]; then
    log_section "CSS Optimization"
    
    cd "$WEB_DIR"
    
    log_check "Checking CSS configuration..."
    
    # Check Tailwind config
    if [[ -f "tailwind.config.ts" ]] || [[ -f "tailwind.config.js" ]]; then
        log_pass "Tailwind CSS configured"
        
        # Check for purge/content configuration
        if grep -q "content:" tailwind.config.* 2>/dev/null; then
            log_pass "Tailwind purge configured"
        else
            log_warning "Tailwind purge not configured (CSS may be bloated)"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        log_info "No Tailwind configuration found"
    fi
    
    # Check PostCSS config
    if [[ -f "postcss.config.js" ]] || [[ -f "postcss.config.mjs" ]]; then
        log_pass "PostCSS configured"
    else
        log_info "No PostCSS configuration found"
    fi
    
    # Check for CSS files in build
    if [[ -d ".next/static/css" ]]; then
        CSS_SIZE=$(du -sk .next/static/css 2>/dev/null | cut -f1 || echo "0")
        CSS_SIZE_KB=$CSS_SIZE
        
        if [[ "$CSS_SIZE_KB" -gt 100 ]]; then
            log_warning "CSS bundle size: ${CSS_SIZE_KB}KB (consider optimization)"
            WARNINGS=$((WARNINGS + 1))
        else
            log_pass "CSS bundle size: ${CSS_SIZE_KB}KB (optimized)"
        fi
        
        REPORT=$(echo "$REPORT" | jq --arg size "$CSS_SIZE_KB" '.css.bundle_kb = ($size | tonumber)')
    fi
fi

# Generate recommendations
log_section "Optimization Recommendations"

if [[ "$WARNINGS" -eq 0 && "$ERRORS" -eq 0 ]]; then
    log_pass "All checks passed! Build is well-optimized."
else
    if [[ "$ERRORS" -gt 0 ]]; then
        log_error "Found $ERRORS error(s) requiring attention"
    fi
    
    if [[ "$WARNINGS" -gt 0 ]]; then
        log_warning "Found $WARNINGS warning(s) - consider optimization"
    fi
    
    echo ""
    log_info "Recommended actions:"
    echo "  • Review large chunks and consider code splitting"
    echo "  • Remove unused dependencies to reduce bundle size"
    echo "  • Optimize images with next/image or compression"
    echo "  • Enable Tailwind CSS purging for smaller CSS"
    echo "  • Consider lazy loading for non-critical components"
fi

# Save report
if [[ -n "$REPORT_FILE" ]]; then
    REPORT=$(echo "$REPORT" | jq \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg w "$WARNINGS" \
        --arg e "$ERRORS" \
        '. + {timestamp: $ts, warnings: ($w | tonumber), errors: ($e | tonumber)}')
    
    echo "$REPORT" | jq '.' > "$REPORT_FILE"
    log_info "Report saved to: $REPORT_FILE"
fi

# Summary
log_section "Summary"
echo -e "${BLUE}Checks completed:${NC}"
[[ "$CHECK_BUNDLE" == true ]] && echo "  ✓ Bundle analysis"
[[ "$CHECK_UNUSED" == true ]] && echo "  ✓ Unused dependencies"
[[ "$CHECK_IMAGES" == true ]] && echo "  ✓ Image optimization"
[[ "$CHECK_CSS" == true ]] && echo "  ✓ CSS optimization"

echo ""
if [[ "$ERRORS" -eq 0 ]]; then
    log_pass "Build optimization check complete!"
    exit 0
else
    log_error "Build optimization check failed with $ERRORS error(s)"
    exit 1
fi
