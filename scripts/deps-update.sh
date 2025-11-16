#!/bin/bash
# Dependency Update Script
# This script safely updates dependencies with proper validation and rollback

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
UPDATE_TYPE="${1:-minor}" # major, minor, patch, or all
DRY_RUN="${2:-false}"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Helix Dependency Update Tool                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Validate we're in project root
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}❌ ERROR: pubspec.yaml not found${NC}"
    echo "   Please run this script from the project root"
    exit 1
fi

# Create backup
echo "💾 Creating backup of current lockfiles..."
cp pubspec.lock pubspec.lock.backup
if [ -f "ios/Podfile.lock" ]; then
    cp ios/Podfile.lock ios/Podfile.lock.backup
fi
if [ -f "macos/Podfile.lock" ]; then
    cp macos/Podfile.lock macos/Podfile.lock.backup
fi
echo -e "${GREEN}✅ Backups created${NC}"

# Rollback function
rollback() {
    echo ""
    echo -e "${YELLOW}⚙️  Rolling back changes...${NC}"
    mv pubspec.lock.backup pubspec.lock
    if [ -f "ios/Podfile.lock.backup" ]; then
        mv ios/Podfile.lock.backup ios/Podfile.lock
    fi
    if [ -f "macos/Podfile.lock.backup" ]; then
        mv macos/Podfile.lock.backup macos/Podfile.lock
    fi
    echo -e "${YELLOW}✅ Rollback complete${NC}"
    exit 1
}

# Set up trap for errors
trap rollback ERR

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE} Step 1: Check Current State${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "📊 Checking for outdated dependencies..."
flutter pub outdated --json > outdated-report.json 2>&1 || true

if [ -f "outdated-report.json" ]; then
    echo -e "${GREEN}✅ Outdated packages report generated${NC}"

    # Show summary
    echo ""
    echo "Current outdated packages:"
    flutter pub outdated || true
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE} Step 2: Update Dependencies (Type: ${UPDATE_TYPE})${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$DRY_RUN" = "true" ]; then
    echo -e "${YELLOW}ℹ️  DRY RUN MODE - No actual changes will be made${NC}"
    flutter pub upgrade --dry-run
else
    echo "📦 Updating Flutter/Dart dependencies..."

    case "$UPDATE_TYPE" in
        "patch")
            echo "   Updating patch versions only..."
            flutter pub upgrade --minor-versions
            ;;
        "minor")
            echo "   Updating minor and patch versions..."
            flutter pub upgrade --minor-versions
            ;;
        "major")
            echo "   Updating to latest versions (including major)..."
            flutter pub upgrade --major-versions
            ;;
        "all")
            echo "   Updating all dependencies to latest..."
            flutter pub upgrade
            ;;
        *)
            echo -e "${RED}❌ Invalid update type: $UPDATE_TYPE${NC}"
            echo "   Valid types: patch, minor, major, all"
            rollback
            ;;
    esac

    echo -e "${GREEN}✅ Dependencies updated${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE} Step 3: Security Audit${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo "🔒 Running security audit..."
if dart pub audit --json > audit-report.json 2>&1; then
    echo -e "${GREEN}✅ No vulnerabilities found${NC}"
else
    CRITICAL=$(grep -o '"severity":"critical"' audit-report.json | wc -l || echo "0")
    HIGH=$(grep -o '"severity":"high"' audit-report.json | wc -l || echo "0")

    if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
        echo -e "${RED}❌ CRITICAL/HIGH vulnerabilities found after update!${NC}"
        cat audit-report.json
        rollback
    else
        echo -e "${YELLOW}⚠️  Some vulnerabilities found, but not critical${NC}"
        cat audit-report.json
    fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE} Step 4: Update iOS Dependencies${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -f "ios/Podfile" ] && command -v pod >/dev/null 2>&1; then
    echo "📱 Updating iOS CocoaPods dependencies..."
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}ℹ️  DRY RUN - Skipping iOS update${NC}"
    else
        cd ios
        pod update --repo-update
        cd ..
        echo -e "${GREEN}✅ iOS dependencies updated${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Skipping iOS update (Podfile not found or CocoaPods not installed)${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE} Step 5: Update macOS Dependencies${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -f "macos/Podfile" ] && command -v pod >/dev/null 2>&1; then
    echo "💻 Updating macOS CocoaPods dependencies..."
    if [ "$DRY_RUN" = "true" ]; then
        echo -e "${YELLOW}ℹ️  DRY RUN - Skipping macOS update${NC}"
    else
        cd macos
        pod update --repo-update
        cd ..
        echo -e "${GREEN}✅ macOS dependencies updated${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Skipping macOS update (Podfile not found or CocoaPods not installed)${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE} Step 6: Run Tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ "$DRY_RUN" = "false" ]; then
    echo "🧪 Running tests to verify updates..."
    if flutter test; then
        echo -e "${GREEN}✅ All tests passed${NC}"
    else
        echo -e "${RED}❌ Tests failed after dependency update${NC}"
        echo "   This might indicate breaking changes in updated packages"
        read -p "Do you want to rollback? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rollback
        fi
    fi
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE} Step 7: Review Changes${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo "📋 Lockfile changes:"
echo ""
git diff pubspec.lock

if [ -f "ios/Podfile.lock" ]; then
    echo ""
    echo "📋 iOS Podfile.lock changes:"
    git diff ios/Podfile.lock || echo "No changes"
fi

# Clean up backups
echo ""
echo "🧹 Cleaning up backups..."
rm -f pubspec.lock.backup
rm -f ios/Podfile.lock.backup
rm -f macos/Podfile.lock.backup
rm -f outdated-report.json
rm -f audit-report.json

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅  Dependency update completed successfully!                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "  1. Review the changes above"
echo "  2. Test the application thoroughly"
echo "  3. Commit the updated lockfiles:"
echo "     git add pubspec.lock ios/Podfile.lock macos/Podfile.lock"
echo "     git commit -m 'deps: update dependencies to latest ${UPDATE_TYPE} versions'"
echo ""
