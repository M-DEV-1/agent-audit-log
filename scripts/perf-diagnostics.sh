#!/usr/bin/env bash
# Performance diagnostics for agent-audit-log deployment
# Measures build times, bundle sizes, and runtime performance metrics

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
NC='\033[0m'

# Configuration
OUTPUT_FILE=""
RUN_BUILD=false
ANALYZE_BUNDLE=false
CHECK_LIGHTHOUSE=false
TARGET_URL="https://agent-audit.mdev1.me"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            RUN_BUILD=true
            shift
            ;;
        --bundle)
            ANALYZE_BUNDLE=true
            shift
            ;;
        --lighthouse)
            CHECK_LIGHTHOUSE=true
            shift
            ;;
        --url)
            TARGET_URL="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --build         Run build and measure timing"
            echo "  --bundle        Analyze bundle sizes"
            echo "  --lighthouse    Run Lighthouse performance audit"
            echo "  --url URL       Target URL for Lighthouse (default: production)"
            echo "  --output FILE   Save results to JSON file"
            echo "  -h, --help      Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --build --bundle"
            echo "  $0 --lighthouse --url https://preview.vercel.app"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Helper functions
log_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
}

log_metric() {
    local label="$1"
    local value="$2"
    local unit="${3:-}"
    printf "${BLUE}%-30s${NC} ${GREEN}%s${NC} %s\n" "$label:" "$value" "$unit"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Initialize results object
RESULTS='{"timestamp":"","build":{},"bundle":{},"lighthouse":{}}'
RESULTS=$(echo "$RESULTS" | jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.timestamp = $ts')

# Build timing
if [[ "$RUN_BUILD" == true ]]; then
    log_section "Build Performance"
    
    cd "$WEB_DIR"
    
    # Clean build
    log_metric "Cleaning" "rm -rf .next"
    rm -rf .next
    
    # Measure build time
    echo -e "${BLUE}Building...${NC}"
    BUILD_START=$(date +%s%N)
    BUILD_OUTPUT=$(npm run build 2>&1)
    BUILD_END=$(date +%s%N)
    
    BUILD_TIME_NS=$((BUILD_END - BUILD_START))
    BUILD_TIME_MS=$((BUILD_TIME_NS / 1000000))
    BUILD_TIME_S=$(echo "scale=2; $BUILD_TIME_MS / 1000" | bc)
    
    log_metric "Build time" "$BUILD_TIME_S" "seconds"
    log_metric "Build time (ms)" "$BUILD_TIME_MS" "ms"
    
    # Extract compile time from output
    if echo "$BUILD_OUTPUT" | grep -q "Compiled successfully"; then
        COMPILE_TIME=$(echo "$BUILD_OUTPUT" | grep -oP 'Compiled successfully in \K[\d.]+(?=s)')
        log_metric "Compile time" "$COMPILE_TIME" "seconds"
        
        RESULTS=$(echo "$RESULTS" | jq \
            --arg bt "$BUILD_TIME_S" \
            --arg ct "$COMPILE_TIME" \
            '.build.total_seconds = ($bt | tonumber) | .build.compile_seconds = ($ct | tonumber)')
    else
        log_warning "Build failed or output format changed"
    fi
    
    # Count generated pages
    PAGE_COUNT=$(echo "$BUILD_OUTPUT" | grep -c "^┌\|^├\|^└" || echo "0")
    log_metric "Pages generated" "$PAGE_COUNT"
    
    RESULTS=$(echo "$RESULTS" | jq --arg pc "$PAGE_COUNT" '.build.page_count = ($pc | tonumber)')
fi

# Bundle analysis
if [[ "$ANALYZE_BUNDLE" == true ]]; then
    log_section "Bundle Analysis"
    
    cd "$WEB_DIR"
    
    if [[ ! -d ".next" ]]; then
        log_warning ".next directory not found. Run with --build first."
    else
        # Analyze .next directory size
        NEXT_SIZE=$(du -sh .next | cut -f1)
        NEXT_SIZE_KB=$(du -sk .next | cut -f1)
        log_metric "Total .next size" "$NEXT_SIZE"
        
        RESULTS=$(echo "$RESULTS" | jq --arg ns "$NEXT_SIZE_KB" '.bundle.next_dir_kb = ($ns | tonumber)')
        
        # Static directory
        if [[ -d ".next/static" ]]; then
            STATIC_SIZE=$(du -sh .next/static | cut -f1)
            STATIC_SIZE_KB=$(du -sk .next/static | cut -f1)
            log_metric "Static assets" "$STATIC_SIZE"
            
            RESULTS=$(echo "$RESULTS" | jq --arg ss "$STATIC_SIZE_KB" '.bundle.static_kb = ($ss | tonumber)')
        fi
        
        # Server directory
        if [[ -d ".next/server" ]]; then
            SERVER_SIZE=$(du -sh .next/server | cut -f1)
            SERVER_SIZE_KB=$(du -sk .next/server | cut -f1)
            log_metric "Server bundle" "$SERVER_SIZE"
            
            RESULTS=$(echo "$RESULTS" | jq --arg ss "$SERVER_SIZE_KB" '.bundle.server_kb = ($ss | tonumber)')
        fi
        
        # Count chunks
        if [[ -d ".next/static/chunks" ]]; then
            CHUNK_COUNT=$(find .next/static/chunks -name "*.js" | wc -l)
            log_metric "JavaScript chunks" "$CHUNK_COUNT"
            
            RESULTS=$(echo "$RESULTS" | jq --arg cc "$CHUNK_COUNT" '.bundle.chunk_count = ($cc | tonumber)')
        fi
        
        # Find largest files
        echo ""
        echo -e "${BLUE}Top 5 largest files:${NC}"
        find .next -type f -name "*.js" -o -name "*.css" | xargs du -h | sort -rh | head -5 | while read size file; do
            echo "  $size  $(basename $file)"
        done
    fi
fi

# Lighthouse audit
if [[ "$CHECK_LIGHTHOUSE" == true ]]; then
    log_section "Lighthouse Performance Audit"
    
    if ! command -v lighthouse &> /dev/null; then
        log_warning "Lighthouse CLI not installed. Install: npm install -g lighthouse"
    else
        echo -e "${BLUE}Running Lighthouse on: $TARGET_URL${NC}"
        
        LIGHTHOUSE_OUTPUT=$(mktemp)
        
        if lighthouse "$TARGET_URL" \
            --only-categories=performance \
            --output=json \
            --output-path="$LIGHTHOUSE_OUTPUT" \
            --chrome-flags="--headless" \
            --quiet 2>/dev/null; then
            
            # Extract key metrics
            PERF_SCORE=$(jq -r '.categories.performance.score * 100 | floor' "$LIGHTHOUSE_OUTPUT")
            FCP=$(jq -r '.audits."first-contentful-paint".numericValue' "$LIGHTHOUSE_OUTPUT")
            LCP=$(jq -r '.audits."largest-contentful-paint".numericValue' "$LIGHTHOUSE_OUTPUT")
            TBT=$(jq -r '.audits."total-blocking-time".numericValue' "$LIGHTHOUSE_OUTPUT")
            CLS=$(jq -r '.audits."cumulative-layout-shift".numericValue' "$LIGHTHOUSE_OUTPUT")
            SI=$(jq -r '.audits."speed-index".numericValue' "$LIGHTHOUSE_OUTPUT")
            
            log_metric "Performance Score" "$PERF_SCORE" "/100"
            log_metric "First Contentful Paint" "$(echo "scale=0; $FCP / 1" | bc)" "ms"
            log_metric "Largest Contentful Paint" "$(echo "scale=0; $LCP / 1" | bc)" "ms"
            log_metric "Total Blocking Time" "$(echo "scale=0; $TBT / 1" | bc)" "ms"
            log_metric "Cumulative Layout Shift" "$CLS"
            log_metric "Speed Index" "$(echo "scale=0; $SI / 1" | bc)" "ms"
            
            RESULTS=$(echo "$RESULTS" | jq \
                --arg ps "$PERF_SCORE" \
                --arg fcp "$FCP" \
                --arg lcp "$LCP" \
                --arg tbt "$TBT" \
                --arg cls "$CLS" \
                --arg si "$SI" \
                '.lighthouse.performance_score = ($ps | tonumber) |
                 .lighthouse.fcp_ms = ($fcp | tonumber) |
                 .lighthouse.lcp_ms = ($lcp | tonumber) |
                 .lighthouse.tbt_ms = ($tbt | tonumber) |
                 .lighthouse.cls = ($cls | tonumber) |
                 .lighthouse.speed_index_ms = ($si | tonumber)')
            
            rm -f "$LIGHTHOUSE_OUTPUT"
        else
            log_warning "Lighthouse audit failed"
        fi
    fi
fi

# Save results to file
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$RESULTS" | jq '.' > "$OUTPUT_FILE"
    log_metric "Results saved to" "$OUTPUT_FILE"
fi

# Summary
log_section "Diagnostic Summary"

if [[ "$RUN_BUILD" == true ]]; then
    BUILD_TIME=$(echo "$RESULTS" | jq -r '.build.total_seconds // "N/A"')
    echo -e "${GREEN}✓${NC} Build completed in ${BUILD_TIME}s"
fi

if [[ "$ANALYZE_BUNDLE" == true ]]; then
    NEXT_SIZE=$(echo "$RESULTS" | jq -r '.bundle.next_dir_kb // "N/A"')
    echo -e "${GREEN}✓${NC} Bundle size: ${NEXT_SIZE}KB"
fi

if [[ "$CHECK_LIGHTHOUSE" == true ]]; then
    PERF_SCORE=$(echo "$RESULTS" | jq -r '.lighthouse.performance_score // "N/A"')
    echo -e "${GREEN}✓${NC} Lighthouse score: ${PERF_SCORE}/100"
fi

echo ""
echo -e "${GREEN}Performance diagnostics complete!${NC}"
