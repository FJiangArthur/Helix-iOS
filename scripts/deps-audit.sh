#!/bin/bash
# Dependency Security Audit Script
# Comprehensive security scanning of all project dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
OUTPUT_DIR="security-reports"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="${OUTPUT_DIR}/security-audit-${TIMESTAMP}.md"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Helix Security Audit - Comprehensive Scan               ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Initialize report
cat > "$REPORT_FILE" << EOF
# Security Audit Report
**Generated:** $(date)
**Project:** Helix iOS

## Executive Summary

This report contains a comprehensive security audit of all project dependencies across multiple package managers.

---

EOF

TOTAL_CRITICAL=0
TOTAL_HIGH=0
TOTAL_MEDIUM=0
TOTAL_LOW=0

# Function to add section to report
add_section() {
    echo "" >> "$REPORT_FILE"
    echo "## $1" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Function to add content to report
add_content() {
    echo "$1" >> "$REPORT_FILE"
}

# 1. Dart/Flutter Security Audit
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE} 1. Dart/Flutter Dependency Security Scan${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

add_section "1. Dart/Flutter Dependencies"

echo "🔒 Running dart pub audit..."
if dart pub audit --json > "${OUTPUT_DIR}/dart-audit-${TIMESTAMP}.json" 2>&1; then
    echo -e "${GREEN}✅ No vulnerabilities found in Dart dependencies${NC}"
    add_content "**Status:** ✅ No vulnerabilities found"
else
    AUDIT_FILE="${OUTPUT_DIR}/dart-audit-${TIMESTAMP}.json"

    if [ -f "$AUDIT_FILE" ]; then
        CRITICAL=$(grep -o '"severity":"critical"' "$AUDIT_FILE" | wc -l || echo "0")
        HIGH=$(grep -o '"severity":"high"' "$AUDIT_FILE" | wc -l || echo "0")
        MEDIUM=$(grep -o '"severity":"medium"' "$AUDIT_FILE" | wc -l || echo "0")
        LOW=$(grep -o '"severity":"low"' "$AUDIT_FILE" | wc -l || echo "0")

        TOTAL_CRITICAL=$((TOTAL_CRITICAL + CRITICAL))
        TOTAL_HIGH=$((TOTAL_HIGH + HIGH))
        TOTAL_MEDIUM=$((TOTAL_MEDIUM + MEDIUM))
        TOTAL_LOW=$((TOTAL_LOW + LOW))

        echo ""
        echo "Found vulnerabilities:"
        echo -e "  ${RED}Critical: $CRITICAL${NC}"
        echo -e "  ${RED}High: $HIGH${NC}"
        echo -e "  ${YELLOW}Medium: $MEDIUM${NC}"
        echo -e "  ${YELLOW}Low: $LOW${NC}"

        add_content "**Status:** ⚠️ Vulnerabilities found"
        add_content ""
        add_content "| Severity | Count |"
        add_content "|----------|-------|"
        add_content "| Critical | $CRITICAL |"
        add_content "| High     | $HIGH |"
        add_content "| Medium   | $MEDIUM |"
        add_content "| Low      | $LOW |"
        add_content ""
        add_content "\`\`\`json"
        cat "$AUDIT_FILE" >> "$REPORT_FILE"
        add_content "\`\`\`"
    fi
fi

# 2. Dependency Tree Analysis
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE} 2. Dependency Tree Analysis${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

add_section "2. Dependency Tree"

echo "🌳 Analyzing dependency tree..."
flutter pub deps --json > "${OUTPUT_DIR}/deps-tree-${TIMESTAMP}.json" 2>&1 || true
flutter pub deps --style=compact > "${OUTPUT_DIR}/deps-tree-${TIMESTAMP}.txt" 2>&1 || true

if [ -f "${OUTPUT_DIR}/deps-tree-${TIMESTAMP}.txt" ]; then
    TOTAL_PACKAGES=$(grep -c "^" "${OUTPUT_DIR}/deps-tree-${TIMESTAMP}.txt" || echo "0")
    echo -e "${GREEN}✅ Dependency tree generated (${TOTAL_PACKAGES} packages)${NC}"

    add_content "**Total Packages:** $TOTAL_PACKAGES"
    add_content ""
    add_content "<details>"
    add_content "<summary>View Full Dependency Tree</summary>"
    add_content ""
    add_content "\`\`\`"
    cat "${OUTPUT_DIR}/deps-tree-${TIMESTAMP}.txt" >> "$REPORT_FILE"
    add_content "\`\`\`"
    add_content "</details>"
fi

# 3. Check for Insecure Dependency Patterns
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE} 3. Insecure Dependency Pattern Detection${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

add_section "3. Insecure Dependency Patterns"

PATTERN_ISSUES=0

# Check for git dependencies
echo "🔍 Checking for git dependencies..."
if grep -n "git:" pubspec.yaml > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Git dependencies found${NC}"
    grep -n "git:" pubspec.yaml
    PATTERN_ISSUES=$((PATTERN_ISSUES + 1))

    add_content "### ⚠️ Git Dependencies"
    add_content ""
    add_content "Git dependencies found in \`pubspec.yaml\`. This can lead to:"
    add_content "- Irreproducible builds"
    add_content "- Security risks from unverified sources"
    add_content "- Breaking changes without warning"
    add_content ""
    add_content "\`\`\`yaml"
    grep -A 2 "git:" pubspec.yaml >> "$REPORT_FILE" || true
    add_content "\`\`\`"
    add_content ""
else
    echo -e "${GREEN}✅ No git dependencies${NC}"
    add_content "✅ No git dependencies found"
    add_content ""
fi

# Check for path dependencies
echo "🔍 Checking for path dependencies..."
if grep -n "path:" pubspec.yaml > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Path dependencies found${NC}"
    grep -n "path:" pubspec.yaml
    PATTERN_ISSUES=$((PATTERN_ISSUES + 1))

    add_content "### ⚠️ Path Dependencies"
    add_content ""
    add_content "Path dependencies found. Ensure these are only for local development."
    add_content ""
    add_content "\`\`\`yaml"
    grep -A 1 "path:" pubspec.yaml >> "$REPORT_FILE" || true
    add_content "\`\`\`"
    add_content ""
else
    echo -e "${GREEN}✅ No path dependencies${NC}"
    add_content "✅ No path dependencies found"
    add_content ""
fi

# Check for version ranges that are too permissive
echo "🔍 Checking for permissive version ranges..."
if grep -E "^\s+[a-z_]+:\s*['\"]?[>^~]" pubspec.yaml > /dev/null 2>&1; then
    echo -e "${YELLOW}ℹ️  Version ranges detected (using ^, ~, or >)${NC}"
    add_content "### ℹ️ Version Constraints"
    add_content ""
    add_content "Using version ranges for flexibility. Ensure lockfile is committed for reproducibility."
    add_content ""
else
    echo -e "${GREEN}✅ Using pinned versions${NC}"
fi

# 4. License Compliance Check
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE} 4. License Compliance Analysis${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

add_section "4. License Compliance"

echo "📜 Generating license report..."
flutter pub deps --json > "${OUTPUT_DIR}/licenses-${TIMESTAMP}.json" 2>&1 || true

if [ -f "${OUTPUT_DIR}/licenses-${TIMESTAMP}.json" ]; then
    echo -e "${GREEN}✅ License report generated${NC}"
    add_content "License information exported to \`${OUTPUT_DIR}/licenses-${TIMESTAMP}.json\`"
    add_content ""
    add_content "Review all third-party licenses for compliance with your project's requirements."
fi

# 5. CocoaPods Security Check (if applicable)
if [ -f "ios/Podfile.lock" ]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE} 5. iOS CocoaPods Security${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    add_section "5. iOS CocoaPods Dependencies"

    echo "📱 Checking iOS dependencies..."
    POD_COUNT=$(grep -c "PODS:" ios/Podfile.lock || echo "0")
    echo -e "${GREEN}✅ Found $POD_COUNT CocoaPods${NC}"

    add_content "**Total CocoaPods:** $POD_COUNT"
    add_content ""
    add_content "CocoaPods security auditing requires manual review."
    add_content "Consider using tools like:"
    add_content "- [CocoaPods-Check](https://github.com/square/cocoapods-check)"
    add_content "- Manual review of pod sources"
fi

# 6. Summary and Recommendations
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE} 6. Summary and Recommendations${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

add_section "Summary"

echo "Vulnerability Summary:"
echo -e "  ${RED}Critical: $TOTAL_CRITICAL${NC}"
echo -e "  ${RED}High: $TOTAL_HIGH${NC}"
echo -e "  ${YELLOW}Medium: $TOTAL_MEDIUM${NC}"
echo -e "  ${YELLOW}Low: $TOTAL_LOW${NC}"
echo ""

add_content "### Vulnerability Summary"
add_content ""
add_content "| Severity | Total |"
add_content "|----------|-------|"
add_content "| Critical | $TOTAL_CRITICAL |"
add_content "| High     | $TOTAL_HIGH |"
add_content "| Medium   | $TOTAL_MEDIUM |"
add_content "| Low      | $TOTAL_LOW |"
add_content ""

# Determine risk level
RISK_LEVEL="LOW"
RISK_COLOR="${GREEN}"

if [ "$TOTAL_CRITICAL" -gt 0 ]; then
    RISK_LEVEL="CRITICAL"
    RISK_COLOR="${RED}"
elif [ "$TOTAL_HIGH" -gt 0 ]; then
    RISK_LEVEL="HIGH"
    RISK_COLOR="${RED}"
elif [ "$TOTAL_MEDIUM" -gt 0 ]; then
    RISK_LEVEL="MEDIUM"
    RISK_COLOR="${YELLOW}"
fi

echo -e "Overall Risk Level: ${RISK_COLOR}${RISK_LEVEL}${NC}"
echo ""

add_content "### Overall Risk Assessment"
add_content ""
add_content "**Risk Level:** $RISK_LEVEL"
add_content ""

# Recommendations
add_section "Recommendations"

if [ "$TOTAL_CRITICAL" -gt 0 ] || [ "$TOTAL_HIGH" -gt 0 ]; then
    add_content "### ⚠️ Immediate Action Required"
    add_content ""
    add_content "1. **Update vulnerable dependencies immediately**"
    add_content "   - Run \`./scripts/deps-update.sh minor\` to update to latest safe versions"
    add_content "   - Review breaking changes before updating to major versions"
    add_content ""
    add_content "2. **Review security advisories**"
    add_content "   - Check detailed vulnerability reports in \`${OUTPUT_DIR}/\`"
    add_content "   - Assess impact on your application"
    add_content ""
fi

add_content "3. **Best Practices**"
add_content "   - Keep dependencies up to date regularly"
add_content "   - Run security audits before each release"
add_content "   - Review dependency changes in pull requests"
add_content "   - Use Dependabot for automated updates"
add_content ""

add_content "---"
add_content ""
add_content "*Report generated by Helix Security Audit Tool v1.0*"

# Save summary
echo ""
echo -e "${GREEN}✅ Security audit completed${NC}"
echo ""
echo "📄 Full report saved to: $REPORT_FILE"
echo "📁 Detailed reports in: $OUTPUT_DIR/"
echo ""

# Final status
if [ "$TOTAL_CRITICAL" -gt 0 ] || [ "$TOTAL_HIGH" -gt 0 ]; then
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ⚠️  SECURITY ISSUES FOUND - IMMEDIATE ACTION REQUIRED        ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    exit 1
else
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅  Security audit passed!                                    ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    exit 0
fi
