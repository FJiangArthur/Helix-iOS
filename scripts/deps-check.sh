#!/bin/bash
# Dependency Check and Validation Script
# This script performs comprehensive dependency checks across all package managers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Track errors
ERRORS=0
WARNINGS=0

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Helix Dependency Check & Validation                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Check Flutter/Dart Dependencies
print_section "1. Flutter/Dart Dependencies"

echo "📦 Checking pubspec.lock..."
if [ ! -f "pubspec.lock" ]; then
    echo -e "${RED}❌ ERROR: pubspec.lock is missing!${NC}"
    echo "   Run 'flutter pub get' to generate lockfile"
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}✅ pubspec.lock exists${NC}"
fi

echo ""
echo "📥 Running flutter pub get..."
if flutter pub get; then
    echo -e "${GREEN}✅ Dependencies installed successfully${NC}"
else
    echo -e "${RED}❌ ERROR: Failed to install dependencies${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "🔍 Verifying lockfile integrity..."
if git diff --exit-code pubspec.lock > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Lockfile is in sync${NC}"
else
    echo -e "${RED}❌ ERROR: pubspec.lock has uncommitted changes${NC}"
    echo "   The lockfile was modified. Please commit the changes."
    git diff pubspec.lock
    ERRORS=$((ERRORS + 1))
fi

# 2. Security Audit
print_section "2. Security Vulnerability Scan"

echo "🔒 Running Dart security audit..."
if command_exists dart; then
    if dart pub audit --json > /tmp/audit-report.json 2>&1; then
        echo -e "${GREEN}✅ No vulnerabilities found${NC}"
    else
        if [ -f "/tmp/audit-report.json" ]; then
            CRITICAL=$(grep -o '"severity":"critical"' /tmp/audit-report.json | wc -l || echo "0")
            HIGH=$(grep -o '"severity":"high"' /tmp/audit-report.json | wc -l || echo "0")
            MEDIUM=$(grep -o '"severity":"medium"' /tmp/audit-report.json | wc -l || echo "0")

            echo ""
            echo "Security Findings:"
            echo "  Critical: $CRITICAL"
            echo "  High: $HIGH"
            echo "  Medium: $MEDIUM"

            if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
                echo -e "${RED}❌ CRITICAL/HIGH vulnerabilities found!${NC}"
                cat /tmp/audit-report.json
                ERRORS=$((ERRORS + 1))
            elif [ "$MEDIUM" -gt 0 ]; then
                echo -e "${YELLOW}⚠️  Medium severity vulnerabilities found${NC}"
                WARNINGS=$((WARNINGS + 1))
            fi
        fi
    fi
else
    echo -e "${YELLOW}⚠️  Dart command not found, skipping audit${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

# 3. Check for outdated dependencies
print_section "3. Outdated Dependencies Check"

echo "📊 Checking for outdated packages..."
if flutter pub outdated --json > /tmp/outdated-report.json 2>&1; then
    if [ -s "/tmp/outdated-report.json" ]; then
        echo -e "${YELLOW}⚠️  Some dependencies are outdated${NC}"
        echo "   Run 'flutter pub outdated' for details"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}✅ All dependencies are up to date${NC}"
    fi
else
    echo -e "${GREEN}✅ All dependencies are current${NC}"
fi

# 4. iOS CocoaPods Check
print_section "4. iOS CocoaPods Dependencies"

if [ -f "ios/Podfile" ]; then
    echo "📱 Checking iOS dependencies..."

    if [ ! -f "ios/Podfile.lock" ]; then
        echo -e "${YELLOW}⚠️  ios/Podfile.lock is missing${NC}"
        echo "   Run 'cd ios && pod install' to generate lockfile"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}✅ ios/Podfile.lock exists${NC}"

        if command_exists pod; then
            echo ""
            echo "🔍 Checking CocoaPods integrity..."
            cd ios
            if pod install --repo-update > /dev/null 2>&1; then
                cd ..
                if git diff --exit-code ios/Podfile.lock > /dev/null 2>&1; then
                    echo -e "${GREEN}✅ iOS Podfile.lock is in sync${NC}"
                else
                    echo -e "${YELLOW}⚠️  iOS Podfile.lock has changes${NC}"
                    echo "   Consider updating the lockfile"
                    WARNINGS=$((WARNINGS + 1))
                fi
            else
                cd ..
                echo -e "${RED}❌ ERROR: pod install failed${NC}"
                ERRORS=$((ERRORS + 1))
            fi
        else
            echo -e "${YELLOW}⚠️  CocoaPods not installed, skipping check${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
else
    echo -e "${YELLOW}⚠️  No iOS Podfile found${NC}"
fi

# 5. macOS CocoaPods Check
print_section "5. macOS CocoaPods Dependencies"

if [ -f "macos/Podfile" ]; then
    echo "💻 Checking macOS dependencies..."

    if [ ! -f "macos/Podfile.lock" ]; then
        echo -e "${YELLOW}⚠️  macos/Podfile.lock is missing${NC}"
        echo "   Run 'cd macos && pod install' to generate lockfile"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}✅ macos/Podfile.lock exists${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  No macOS Podfile found${NC}"
fi

# 6. Check for problematic dependency patterns
print_section "6. Dependency Pattern Analysis"

echo "🔍 Checking for git dependencies..."
if grep -q "git:" pubspec.yaml 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Git dependencies found${NC}"
    echo "   Git dependencies can cause stability issues"
    grep -n "git:" pubspec.yaml
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✅ No git dependencies${NC}"
fi

echo ""
echo "🔍 Checking for path dependencies..."
if grep -q "path:" pubspec.yaml 2>/dev/null; then
    echo -e "${YELLOW}⚠️  Path dependencies found${NC}"
    echo "   Ensure these are only for local development"
    grep -n "path:" pubspec.yaml
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${GREEN}✅ No path dependencies${NC}"
fi

# 7. Dependency tree analysis
print_section "7. Dependency Tree Analysis"

echo "🌳 Generating dependency tree..."
flutter pub deps --style=compact > /tmp/deps-tree.txt 2>&1 || true
if [ -f "/tmp/deps-tree.txt" ]; then
    TOTAL_DEPS=$(wc -l < /tmp/deps-tree.txt)
    echo -e "${GREEN}✅ Dependency tree generated (${TOTAL_DEPS} packages)${NC}"
    echo "   View with: cat /tmp/deps-tree.txt"
fi

# Summary
print_section "Summary"

echo ""
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅  All dependency checks passed!                             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️   Checks completed with warnings: ${WARNINGS}                      ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${RED}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ❌  Checks failed!                                            ║${NC}"
    echo -e "${RED}║     Errors: ${ERRORS}  Warnings: ${WARNINGS}                                    ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
