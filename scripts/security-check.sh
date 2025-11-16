#!/bin/bash

# Security Check Script for Helix iOS Application
# This script performs various security checks on the codebase

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters for issues
CRITICAL_ISSUES=0
HIGH_ISSUES=0
MEDIUM_ISSUES=0
LOW_ISSUES=0

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Output file for report
REPORT_FILE="$PROJECT_ROOT/security-report.txt"
REPORT_JSON="$PROJECT_ROOT/security-report.json"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
    ((MEDIUM_ISSUES++))
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
    ((HIGH_ISSUES++))
}

log_critical() {
    echo -e "${RED}[!!!]${NC} $1"
    ((CRITICAL_ISSUES++))
}

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Check if required tools are installed
check_dependencies() {
    log_info "Checking required dependencies..."

    local missing_tools=()

    if ! command -v dart &> /dev/null; then
        missing_tools+=("dart")
    fi

    if ! command -v flutter &> /dev/null; then
        missing_tools+=("flutter")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install Flutter SDK: https://flutter.dev/docs/get-started/install"
        exit 1
    fi

    log_success "All required dependencies are installed"
}

# Audit dependencies for vulnerabilities
audit_dependencies() {
    print_header "DEPENDENCY VULNERABILITY AUDIT"

    log_info "Running dart pub audit..."

    cd "$PROJECT_ROOT"

    # Run pub audit and capture output
    if dart pub audit > /tmp/pub-audit.txt 2>&1; then
        log_success "No vulnerabilities found in dependencies"
    else
        local exit_code=$?
        if [ $exit_code -eq 1 ]; then
            log_error "Vulnerabilities found in dependencies!"
            cat /tmp/pub-audit.txt
            ((HIGH_ISSUES+=5))  # Weight dependency vulnerabilities heavily
        else
            log_warning "Could not complete dependency audit (this may be expected)"
        fi
    fi

    # Check for outdated packages
    log_info "Checking for outdated packages..."
    dart pub outdated | tee /tmp/pub-outdated.txt

    # Count outdated packages
    local outdated_count=$(grep -c "^  " /tmp/pub-outdated.txt || true)
    if [ "$outdated_count" -gt 0 ]; then
        log_warning "$outdated_count packages are outdated"
    else
        log_success "All packages are up to date"
    fi

    rm -f /tmp/pub-audit.txt /tmp/pub-outdated.txt
}

# Scan for hardcoded secrets
scan_secrets() {
    print_header "SECRET SCANNING"

    log_info "Scanning for hardcoded secrets..."

    local secrets_found=0

    # Patterns to search for
    declare -A secret_patterns=(
        ["API Keys"]='api[_-]?key\s*=\s*["\047][a-zA-Z0-9_\-]{20,}["\047]'
        ["Passwords"]='password\s*=\s*["\047][^"\047]{8,}["\047]'
        ["Tokens"]='token\s*=\s*["\047][a-zA-Z0-9_\-]{20,}["\047]'
        ["AWS Keys"]='AKIA[0-9A-Z]{16}'
        ["Private Keys"]='-----BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY-----'
        ["JWT Tokens"]='eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*'
    )

    for pattern_name in "${!secret_patterns[@]}"; do
        local pattern="${secret_patterns[$pattern_name]}"
        log_info "Checking for: $pattern_name"

        local results=$(grep -rEi "$pattern" "$PROJECT_ROOT/lib" --include="*.dart" 2>/dev/null || true)

        if [ -n "$results" ]; then
            log_critical "Found potential $pattern_name:"
            echo "$results" | while IFS= read -r line; do
                echo "  $line"
            done
            ((secrets_found++))
        fi
    done

    # Check for hardcoded URLs with credentials
    log_info "Checking for URLs with embedded credentials..."
    local url_creds=$(grep -rEi 'https?://[^:]+:[^@]+@' "$PROJECT_ROOT/lib" --include="*.dart" 2>/dev/null || true)
    if [ -n "$url_creds" ]; then
        log_critical "Found URLs with embedded credentials:"
        echo "$url_creds"
        ((secrets_found++))
    fi

    # Check for common secret file names
    log_info "Checking for secret files that shouldn't be committed..."
    local secret_files=(
        ".env"
        ".env.local"
        "credentials.json"
        "google-services.json"
        "GoogleService-Info.plist"
        "*.key"
        "*.pem"
    )

    for file_pattern in "${secret_files[@]}"; do
        local found_files=$(find "$PROJECT_ROOT" -name "$file_pattern" -not -path "*/\.*" 2>/dev/null || true)
        if [ -n "$found_files" ]; then
            # Check if file is in .gitignore
            while IFS= read -r file; do
                if git check-ignore -q "$file" 2>/dev/null; then
                    log_success "$(basename "$file") is properly ignored by git"
                else
                    log_error "$(basename "$file") is NOT in .gitignore and may be committed!"
                    ((secrets_found++))
                fi
            done <<< "$found_files"
        fi
    done

    if [ $secrets_found -eq 0 ]; then
        log_success "No hardcoded secrets detected"
    else
        log_error "Found $secrets_found potential secret(s) - please review"
    fi
}

# Static Application Security Testing (SAST)
run_sast() {
    print_header "STATIC APPLICATION SECURITY TESTING (SAST)"

    cd "$PROJECT_ROOT"

    # Run Flutter analyze with strict mode
    log_info "Running flutter analyze..."
    if flutter analyze --fatal-infos 2>&1 | tee /tmp/flutter-analyze.txt; then
        log_success "Static analysis passed"
    else
        log_error "Static analysis found issues"
        ((HIGH_ISSUES+=2))
    fi

    # Check for insecure patterns
    log_info "Checking for insecure coding patterns..."

    # Check for HTTP usage (should use HTTPS)
    local http_usage=$(grep -rn "http://" "$PROJECT_ROOT/lib" --include="*.dart" | grep -v "localhost\|127.0.0.1\|///" || true)
    if [ -n "$http_usage" ]; then
        log_warning "Found insecure HTTP URLs (should use HTTPS):"
        echo "$http_usage"
    else
        log_success "No insecure HTTP usage found"
    fi

    # Check for print/debugPrint in production code
    local debug_statements=$(grep -rn "^\s*print(\|debugPrint(" "$PROJECT_ROOT/lib" --include="*.dart" --exclude-dir=test || true)
    if [ -n "$debug_statements" ]; then
        log_warning "Found debug print statements in code (should be removed for production):"
        echo "$debug_statements" | head -10
        local count=$(echo "$debug_statements" | wc -l)
        if [ "$count" -gt 10 ]; then
            echo "  ... and $((count - 10)) more"
        fi
    else
        log_success "No debug print statements found"
    fi

    # Check for TODO/FIXME with security keywords
    local security_todos=$(grep -rni "TODO.*security\|FIXME.*security\|TODO.*auth\|FIXME.*auth\|TODO.*password\|FIXME.*password" "$PROJECT_ROOT/lib" --include="*.dart" || true)
    if [ -n "$security_todos" ]; then
        log_warning "Found security-related TODOs/FIXMEs:"
        echo "$security_todos"
    else
        log_success "No security-related TODOs found"
    fi

    # Check for potentially insecure random number generation
    local weak_random=$(grep -rn "Random()" "$PROJECT_ROOT/lib" --include="*.dart" || true)
    if [ -n "$weak_random" ]; then
        log_warning "Found potentially weak random number generation (consider using Random.secure()):"
        echo "$weak_random"
    fi

    # Check for SQL injection vulnerabilities (basic check)
    local sql_concat=$(grep -rn 'SELECT.*\+\|INSERT.*\+\|UPDATE.*\+\|DELETE.*\+' "$PROJECT_ROOT/lib" --include="*.dart" || true)
    if [ -n "$sql_concat" ]; then
        log_warning "Found potential SQL injection risk (string concatenation in queries):"
        echo "$sql_concat"
    fi

    rm -f /tmp/flutter-analyze.txt
}

# Check for insecure storage usage
check_storage_security() {
    print_header "STORAGE SECURITY CHECK"

    log_info "Checking for insecure data storage patterns..."

    # Check for SharedPreferences/UserDefaults with sensitive data
    local insecure_storage=$(grep -rni "SharedPreferences\|UserDefaults" "$PROJECT_ROOT/lib" --include="*.dart" | grep -i "password\|token\|secret\|key\|credential" || true)
    if [ -n "$insecure_storage" ]; then
        log_error "Found potential insecure storage of sensitive data:"
        echo "$insecure_storage"
        log_info "Recommendation: Use flutter_secure_storage for sensitive data"
    else
        log_success "No obvious insecure storage patterns detected"
    fi

    # Check if flutter_secure_storage is being used
    if grep -q "flutter_secure_storage" "$PROJECT_ROOT/pubspec.yaml"; then
        log_success "flutter_secure_storage is included in dependencies"
    else
        log_warning "flutter_secure_storage not found - consider using it for sensitive data"
    fi
}

# Check iOS security configurations
check_ios_security() {
    print_header "iOS SECURITY CONFIGURATION CHECK"

    local ios_plist="$PROJECT_ROOT/ios/Runner/Info.plist"

    if [ ! -f "$ios_plist" ]; then
        log_warning "iOS Info.plist not found - skipping iOS checks"
        return
    fi

    log_info "Checking iOS security configurations..."

    # Check for App Transport Security
    if grep -q "NSAppTransportSecurity" "$ios_plist"; then
        log_success "App Transport Security is configured"

        # Check if arbitrary loads is enabled (bad)
        if grep -A 1 "NSAppTransportSecurity" "$ios_plist" | grep -q "<true/>"; then
            log_error "NSAllowsArbitraryLoads is enabled - this is insecure!"
        fi
    else
        log_warning "App Transport Security not explicitly configured"
    fi

    # Check for file protection
    if grep -q "NSFileProtectionComplete" "$ios_plist"; then
        log_success "File protection is configured"
    else
        log_warning "File protection not configured - consider enabling it"
    fi

    # Check Podfile for insecure sources
    local ios_podfile="$PROJECT_ROOT/ios/Podfile"
    if [ -f "$ios_podfile" ]; then
        local insecure_sources=$(grep "source.*http://" "$ios_podfile" || true)
        if [ -n "$insecure_sources" ]; then
            log_error "Found insecure HTTP sources in Podfile:"
            echo "$insecure_sources"
        else
            log_success "No insecure sources in Podfile"
        fi
    fi
}

# Check Android security configurations
check_android_security() {
    print_header "ANDROID SECURITY CONFIGURATION CHECK"

    local android_manifest="$PROJECT_ROOT/android/app/src/main/AndroidManifest.xml"

    if [ ! -f "$android_manifest" ]; then
        log_warning "Android Manifest not found - skipping Android checks"
        return
    fi

    log_info "Checking Android security configurations..."

    # Check for debuggable flag
    if grep -q 'android:debuggable="true"' "$android_manifest"; then
        log_critical "android:debuggable is set to true - MUST be false for production!"
    else
        log_success "Debuggable flag is not enabled"
    fi

    # Check for backup configuration
    if grep -q 'android:allowBackup="true"' "$android_manifest"; then
        log_warning "Backup is enabled - ensure sensitive data is excluded"
    else
        log_success "Backup is disabled or properly configured"
    fi

    # Check for cleartext traffic
    if grep -q 'android:usesCleartextTraffic="true"' "$android_manifest"; then
        log_error "Cleartext traffic is allowed - this is insecure!"
    else
        log_success "Cleartext traffic is not allowed"
    fi

    # Check for network security config
    if grep -q "networkSecurityConfig" "$android_manifest"; then
        log_success "Network security config is specified"
    else
        log_warning "Network security config not found - consider adding certificate pinning"
    fi

    # Check for ProGuard rules
    local proguard_file="$PROJECT_ROOT/android/app/proguard-rules.pro"
    if [ -f "$proguard_file" ]; then
        log_success "ProGuard rules file exists"
    else
        log_warning "No ProGuard rules found - consider adding code obfuscation"
    fi
}

# Check dependency licenses
check_licenses() {
    print_header "LICENSE COMPLIANCE CHECK"

    log_info "Checking dependency licenses..."

    cd "$PROJECT_ROOT"

    # Generate dependency report
    flutter pub deps --json > /tmp/deps.json 2>/dev/null || true

    # Prohibited licenses (customize as needed)
    local prohibited_licenses="GPL|AGPL|SSPL"

    log_info "Checking for prohibited licenses ($prohibited_licenses)..."

    # This is a basic check - consider using a dedicated tool for production
    if grep -Ei "$prohibited_licenses" /tmp/deps.json >/dev/null 2>&1; then
        log_warning "Potentially prohibited licenses found - manual review required"
    else
        log_success "No obviously prohibited licenses detected"
    fi

    # Generate human-readable license report
    log_info "Generating license report..."
    flutter pub deps > "$PROJECT_ROOT/licenses.txt" 2>/dev/null || true
    log_success "License report saved to licenses.txt"

    rm -f /tmp/deps.json
}

# Generate security report
generate_report() {
    print_header "SECURITY SCAN SUMMARY"

    local total_issues=$((CRITICAL_ISSUES + HIGH_ISSUES + MEDIUM_ISSUES + LOW_ISSUES))

    # Console output
    echo ""
    echo -e "${BLUE}Security Scan Results:${NC}"
    echo -e "  ${RED}Critical: $CRITICAL_ISSUES${NC}"
    echo -e "  ${RED}High:     $HIGH_ISSUES${NC}"
    echo -e "  ${YELLOW}Medium:   $MEDIUM_ISSUES${NC}"
    echo -e "  ${GREEN}Low:      $LOW_ISSUES${NC}"
    echo -e "  ${BLUE}Total:    $total_issues${NC}"
    echo ""

    # Generate text report
    {
        echo "Helix iOS Security Scan Report"
        echo "=============================="
        echo ""
        echo "Scan Date: $(date)"
        echo "Project: Helix iOS Application"
        echo ""
        echo "Summary:"
        echo "--------"
        echo "Critical Issues: $CRITICAL_ISSUES"
        echo "High Issues:     $HIGH_ISSUES"
        echo "Medium Issues:   $MEDIUM_ISSUES"
        echo "Low Issues:      $LOW_ISSUES"
        echo "Total Issues:    $total_issues"
        echo ""
        echo "Recommendations:"
        echo "----------------"
        if [ $CRITICAL_ISSUES -gt 0 ]; then
            echo "- Address critical issues immediately before deployment"
        fi
        if [ $HIGH_ISSUES -gt 0 ]; then
            echo "- Review and fix high-severity issues as soon as possible"
        fi
        if [ $MEDIUM_ISSUES -gt 0 ]; then
            echo "- Plan to address medium-severity issues in next sprint"
        fi
        if [ $total_issues -eq 0 ]; then
            echo "- No significant security issues detected"
            echo "- Continue following security best practices"
        fi
        echo ""
        echo "Next Steps:"
        echo "-----------"
        echo "1. Review detailed findings above"
        echo "2. Prioritize fixes based on severity"
        echo "3. Update security documentation if needed"
        echo "4. Re-run security scan after fixes"
        echo ""
    } > "$REPORT_FILE"

    log_success "Security report saved to: $REPORT_FILE"

    # Generate JSON report
    {
        echo "{"
        echo "  \"scan_date\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
        echo "  \"project\": \"Helix iOS Application\","
        echo "  \"summary\": {"
        echo "    \"critical\": $CRITICAL_ISSUES,"
        echo "    \"high\": $HIGH_ISSUES,"
        echo "    \"medium\": $MEDIUM_ISSUES,"
        echo "    \"low\": $LOW_ISSUES,"
        echo "    \"total\": $total_issues"
        echo "  }"
        echo "}"
    } > "$REPORT_JSON"

    log_success "JSON report saved to: $REPORT_JSON"

    # Exit with error if critical or high issues found
    if [ $CRITICAL_ISSUES -gt 0 ] || [ $HIGH_ISSUES -gt 10 ]; then
        log_error "Security scan failed - critical issues must be addressed"
        return 1
    fi

    log_success "Security scan completed successfully"
    return 0
}

# Main execution
main() {
    local action="${1:-all}"

    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║  Helix iOS Security Scanner            ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"

    check_dependencies

    case "$action" in
        audit)
            audit_dependencies
            ;;
        secrets)
            scan_secrets
            ;;
        sast)
            run_sast
            ;;
        licenses)
            check_licenses
            ;;
        storage)
            check_storage_security
            ;;
        ios)
            check_ios_security
            ;;
        android)
            check_android_security
            ;;
        all)
            audit_dependencies
            scan_secrets
            run_sast
            check_storage_security
            check_ios_security
            check_android_security
            ;;
        full)
            audit_dependencies
            scan_secrets
            run_sast
            check_storage_security
            check_ios_security
            check_android_security
            check_licenses
            ;;
        report)
            # Just generate report with current counters
            generate_report
            return $?
            ;;
        *)
            echo "Usage: $0 {all|audit|secrets|sast|licenses|storage|ios|android|full|report}"
            echo ""
            echo "Commands:"
            echo "  all      - Run core security checks (default)"
            echo "  audit    - Audit dependencies for vulnerabilities"
            echo "  secrets  - Scan for hardcoded secrets"
            echo "  sast     - Run static application security testing"
            echo "  licenses - Check dependency licenses"
            echo "  storage  - Check storage security patterns"
            echo "  ios      - Check iOS security configurations"
            echo "  android  - Check Android security configurations"
            echo "  full     - Run all checks including licenses"
            echo "  report   - Generate summary report"
            exit 1
            ;;
    esac

    if [ "$action" != "report" ]; then
        generate_report
    fi
}

# Run main function with all arguments
main "$@"
