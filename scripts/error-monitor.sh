#!/usr/bin/env bash
# Error monitoring and alerting setup for agent-audit-log
# Integrates with deployment pipeline for build failure detection and reporting

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
ERROR_LOG="$PROJECT_ROOT/.deployment-errors.json"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
DISCORD_WEBHOOK="${DISCORD_WEBHOOK_URL:-}"
EMAIL_TO="${ERROR_EMAIL_TO:-}"
DRY_RUN=false
CHECK_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --slack)
            SLACK_WEBHOOK="$2"
            shift 2
            ;;
        --discord)
            DISCORD_WEBHOOK="$2"
            shift 2
            ;;
        --email)
            EMAIL_TO="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --check              Check for recent errors only"
            echo "  --dry-run            Show what would be sent without sending"
            echo "  --slack WEBHOOK      Slack webhook URL for alerts"
            echo "  --discord WEBHOOK    Discord webhook URL for alerts"
            echo "  --email ADDRESS      Email address for alerts"
            echo "  -h, --help           Show this help"
            echo ""
            echo "Environment Variables:"
            echo "  SLACK_WEBHOOK_URL    Default Slack webhook"
            echo "  DISCORD_WEBHOOK_URL  Default Discord webhook"
            echo "  ERROR_EMAIL_TO       Default email address"
            echo ""
            echo "Examples:"
            echo "  $0 --check"
            echo "  $0 --slack https://hooks.slack.com/..."
            echo "  $0 --dry-run --discord https://discord.com/api/webhooks/..."
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Helper functions
log_error() {
    echo -e "${RED}✗${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Initialize error log if it doesn't exist
if [[ ! -f "$ERROR_LOG" ]]; then
    echo '{"errors":[]}' > "$ERROR_LOG"
fi

# Log an error
log_deployment_error() {
    local error_type="$1"
    local error_message="$2"
    local context="$3"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    local error_entry=$(jq -n \
        --arg ts "$timestamp" \
        --arg type "$error_type" \
        --arg msg "$error_message" \
        --arg ctx "$context" \
        '{
            timestamp: $ts,
            type: $type,
            message: $msg,
            context: $ctx
        }')
    
    # Append to error log
    jq --argjson entry "$error_entry" '.errors += [$entry]' "$ERROR_LOG" > "$ERROR_LOG.tmp"
    mv "$ERROR_LOG.tmp" "$ERROR_LOG"
    
    # Keep only last 100 errors
    jq '.errors |= .[-100:]' "$ERROR_LOG" > "$ERROR_LOG.tmp"
    mv "$ERROR_LOG.tmp" "$ERROR_LOG"
}

# Send alert via Slack
send_slack_alert() {
    local message="$1"
    
    if [[ -z "$SLACK_WEBHOOK" ]]; then
        log_warning "Slack webhook not configured, skipping"
        return
    fi
    
    local payload=$(jq -n \
        --arg msg "$message" \
        '{
            text: "🚨 Agent Audit Log Deployment Error",
            blocks: [
                {
                    type: "section",
                    text: {
                        type: "mrkdwn",
                        text: $msg
                    }
                }
            ]
        }')
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would send to Slack: $message"
        return
    fi
    
    if curl -s -X POST "$SLACK_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "$payload" > /dev/null; then
        log_success "Slack alert sent"
    else
        log_error "Failed to send Slack alert"
    fi
}

# Send alert via Discord
send_discord_alert() {
    local message="$1"
    
    if [[ -z "$DISCORD_WEBHOOK" ]]; then
        log_warning "Discord webhook not configured, skipping"
        return
    fi
    
    local payload=$(jq -n \
        --arg msg "$message" \
        '{
            content: "🚨 **Agent Audit Log Deployment Error**\n\n" + $msg,
            username: "Deployment Monitor"
        }')
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would send to Discord: $message"
        return
    fi
    
    if curl -s -X POST "$DISCORD_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "$payload" > /dev/null; then
        log_success "Discord alert sent"
    else
        log_error "Failed to send Discord alert"
    fi
}

# Send alert via email
send_email_alert() {
    local message="$1"
    
    if [[ -z "$EMAIL_TO" ]]; then
        log_warning "Email address not configured, skipping"
        return
    fi
    
    if ! command -v mail &> /dev/null; then
        log_warning "mail command not found, skipping email"
        return
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "Would send email to: $EMAIL_TO"
        log_info "Message: $message"
        return
    fi
    
    echo "$message" | mail -s "Agent Audit Log Deployment Error" "$EMAIL_TO"
    log_success "Email alert sent to $EMAIL_TO"
}

# Check for recent errors
check_recent_errors() {
    local error_count=$(jq '.errors | length' "$ERROR_LOG")
    log_info "Total errors logged: $error_count"
    
    if [[ "$error_count" -eq 0 ]]; then
        log_success "No errors found"
        return 0
    fi
    
    # Show last 5 errors
    echo ""
    echo -e "${CYAN}Recent Errors (last 5):${NC}"
    jq -r '.errors[-5:] | .[] | "[\(.timestamp)] \(.type): \(.message)"' "$ERROR_LOG"
    
    # Count errors in last 24 hours
    local cutoff=$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)
    local recent_count=$(jq --arg cutoff "$cutoff" '[.errors[] | select(.timestamp > $cutoff)] | length' "$ERROR_LOG")
    
    echo ""
    log_warning "Errors in last 24h: $recent_count"
    
    return "$recent_count"
}

# Main error monitoring logic
if [[ "$CHECK_ONLY" == true ]]; then
    check_recent_errors
    exit $?
fi

# Example: Monitor a build
monitor_build() {
    log_info "Monitoring build process..."
    
    cd "$WEB_DIR"
    
    if npm run build 2>&1 | tee /tmp/build.log; then
        log_success "Build succeeded"
        return 0
    else
        BUILD_ERROR=$(tail -20 /tmp/build.log)
        
        log_error "Build failed"
        log_deployment_error "build_failure" "npm run build failed" "$BUILD_ERROR"
        
        # Send alerts
        ALERT_MSG="*Build Failed*\n\nCommit: $(git rev-parse --short HEAD)\nBranch: $(git rev-parse --abbrev-ref HEAD)\n\nError:\n\`\`\`\n${BUILD_ERROR:0:500}\n\`\`\`"
        
        send_slack_alert "$ALERT_MSG"
        send_discord_alert "$ALERT_MSG"
        send_email_alert "$ALERT_MSG"
        
        return 1
    fi
}

# Script execution
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${CYAN}Error Monitoring Setup${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"

log_info "Error log: $ERROR_LOG"
log_info "Slack: $([ -n "$SLACK_WEBHOOK" ] && echo "configured" || echo "not configured")"
log_info "Discord: $([ -n "$DISCORD_WEBHOOK" ] && echo "configured" || echo "not configured")"
log_info "Email: $([ -n "$EMAIL_TO" ] && echo "$EMAIL_TO" || echo "not configured")"

echo ""
check_recent_errors

echo ""
log_success "Error monitoring configured"
log_info "Use this script in CI/CD or as a post-deploy hook"
log_info "Example: scripts/error-monitor.sh --slack https://hooks.slack.com/..."
