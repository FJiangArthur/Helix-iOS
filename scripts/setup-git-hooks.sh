#!/bin/bash
# Setup Git Hooks for Helix-iOS
# This script sets up pre-commit hooks for quality checks

set -e

echo "🔧 Setting up Git hooks for Helix-iOS..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in a git repository
if [ ! -d .git ]; then
    echo -e "${RED}❌ Error: Not in a git repository${NC}"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Pre-commit hook
echo "📝 Creating pre-commit hook..."
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook for Helix-iOS
# Runs quality checks before allowing commit

set -e

echo "🔍 Running pre-commit checks..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to check if flutter is installed
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}❌ Flutter is not installed${NC}"
        exit 1
    fi
}

# Check Flutter installation
check_flutter

# 1. Check formatting
echo -e "${YELLOW}⏳ Checking code formatting...${NC}"
if ! dart format --set-exit-if-changed .; then
    echo -e "${RED}❌ Code formatting check failed${NC}"
    echo -e "${YELLOW}💡 Run: dart format .${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Code formatting check passed${NC}"

# 2. Run analyze
echo -e "${YELLOW}⏳ Running static analysis...${NC}"
if ! flutter analyze --fatal-infos --fatal-warnings; then
    echo -e "${RED}❌ Static analysis failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Static analysis passed${NC}"

# 3. Run custom import checks (if script exists)
if [ -f "./check_imports.sh" ]; then
    echo -e "${YELLOW}⏳ Checking imports...${NC}"
    if ! ./check_imports.sh; then
        echo -e "${RED}❌ Import check failed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Import check passed${NC}"
fi

# 4. Run tests
echo -e "${YELLOW}⏳ Running tests...${NC}"
if ! flutter test; then
    echo -e "${RED}❌ Tests failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Tests passed${NC}"

echo -e "${GREEN}✅ All pre-commit checks passed!${NC}"
exit 0
EOF

# Make pre-commit hook executable
chmod +x .git/hooks/pre-commit
echo -e "${GREEN}✅ Pre-commit hook created${NC}"

# Pre-push hook
echo "📝 Creating pre-push hook..."
cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash
# Pre-push hook for Helix-iOS
# Runs comprehensive checks before pushing

set -e

echo "🚀 Running pre-push checks..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 1. Run analyze
echo -e "${YELLOW}⏳ Running static analysis...${NC}"
if ! flutter analyze --fatal-infos --fatal-warnings; then
    echo -e "${RED}❌ Static analysis failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Static analysis passed${NC}"

# 2. Run tests with coverage
echo -e "${YELLOW}⏳ Running tests with coverage...${NC}"
if ! flutter test --coverage; then
    echo -e "${RED}❌ Tests failed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Tests passed${NC}"

# 3. Check for secrets
echo -e "${YELLOW}⏳ Checking for secrets in code...${NC}"
# Check for common secret patterns
if git diff origin/main --name-only | xargs grep -rn "api_key\|password\|secret\|token" --include="*.dart" --include="*.yaml" 2>/dev/null; then
    echo -e "${RED}⚠️  Warning: Potential secrets detected in code${NC}"
    echo -e "${YELLOW}Please review and ensure no sensitive data is committed${NC}"
fi

echo -e "${GREEN}✅ All pre-push checks passed!${NC}"
exit 0
EOF

# Make pre-push hook executable
chmod +x .git/hooks/pre-push
echo -e "${GREEN}✅ Pre-push hook created${NC}"

# Commit-msg hook for conventional commits
echo "📝 Creating commit-msg hook..."
cat > .git/hooks/commit-msg << 'EOF'
#!/bin/bash
# Commit message hook for Helix-iOS
# Enforces conventional commit format

commit_msg_file=$1
commit_msg=$(cat "$commit_msg_file")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Conventional commit pattern
# Format: type(scope): subject
# Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert
pattern='^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\([a-zA-Z0-9_-]+\))?: .{1,100}$'

if [[ ! $commit_msg =~ $pattern ]]; then
    echo -e "${RED}❌ Invalid commit message format${NC}"
    echo -e "${YELLOW}Expected format: type(scope): subject${NC}"
    echo -e "${YELLOW}Types: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert${NC}"
    echo -e "${YELLOW}Example: feat(audio): add recording functionality${NC}"
    echo ""
    echo -e "Your commit message was:"
    echo -e "${RED}$commit_msg${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Commit message format is valid${NC}"
exit 0
EOF

# Make commit-msg hook executable
chmod +x .git/hooks/commit-msg
echo -e "${GREEN}✅ Commit-msg hook created${NC}"

echo ""
echo -e "${GREEN}✅ Git hooks setup complete!${NC}"
echo ""
echo "Installed hooks:"
echo "  • pre-commit: Runs formatting, analysis, and tests"
echo "  • pre-push: Runs comprehensive checks before push"
echo "  • commit-msg: Enforces conventional commit format"
echo ""
echo -e "${YELLOW}💡 To bypass hooks (not recommended): git commit --no-verify${NC}"
echo ""

# Check if pre-commit is installed
if command -v pre-commit &> /dev/null; then
    echo -e "${GREEN}✅ pre-commit is installed${NC}"
    echo -e "${YELLOW}💡 Run 'pre-commit install' for additional hooks${NC}"
else
    echo -e "${YELLOW}💡 Install pre-commit for additional hooks:${NC}"
    echo "  pip install pre-commit"
    echo "  pre-commit install"
fi
