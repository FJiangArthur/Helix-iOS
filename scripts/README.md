# Scripts Directory

This directory contains utility scripts for the Helix-iOS project.

## Available Scripts

### Code Quality Scripts

#### `format.sh`

Formats all Dart code in the project using `dart format`.

**Usage**:
```bash
# Format all Dart files
./scripts/format.sh

# Check formatting without making changes (useful for CI)
./scripts/format.sh --check
```

**Features**:
- Formats all `.dart` files in `lib/` and `test/`
- Uses 120 character line length
- Provides clear success/failure messages
- Exit code 0 on success, 1 on failure

---

#### `lint.sh`

Runs Flutter analyzer to check for linting errors and warnings.

**Usage**:
```bash
# Run analyzer with standard output
./scripts/lint.sh

# Run in strict mode (treats warnings as errors - for CI)
./scripts/lint.sh --strict
```

**Features**:
- Runs `flutter analyze` on entire codebase
- Strict mode treats warnings as errors
- Color-coded output for better readability
- Exit code 0 on success, 1 on failure

---

#### `fix.sh`

Automatically fixes formatting and linting issues where possible.

**Usage**:
```bash
./scripts/fix.sh
```

**Features**:
- Formats all code
- Applies automated fixes with `dart fix --apply`
- Organizes imports
- Runs analyzer to check for remaining issues
- Provides summary of fixes applied

**What it fixes**:
- Code formatting issues
- Import organization
- Simple lint violations
- Unnecessary code

---

#### `validate.sh`

Comprehensive validation script for CI/CD pipelines.

**Usage**:
```bash
./scripts/validate.sh
```

**Features**:
- Runs all quality checks in sequence
- Checks code formatting (without modifying)
- Runs linter in strict mode
- Checks for outdated dependencies
- Runs all tests
- Provides detailed summary
- Exit code 0 if all checks pass, 1 otherwise

**Checks performed**:
1. Code formatting verification
2. Static analysis (strict mode)
3. Dependency status check
4. Unit tests
5. Overall validation summary

---

### Development Scripts

#### `setup-git-hooks.sh`

Sets up Git hooks for local development quality checks.

**Purpose**: Automates quality checks before commits and pushes to ensure code meets standards before it reaches CI/CD.

**Hooks Installed**:
1. **pre-commit**: Runs before each commit
   - Code formatting check
   - Static analysis
   - Import validation
   - Unit tests

2. **pre-push**: Runs before pushing to remote
   - Static analysis
   - Tests with coverage
   - Secret detection

3. **commit-msg**: Validates commit message format
   - Enforces conventional commit format
   - Examples: `feat(audio): add feature`, `fix(ble): resolve bug`

**Usage**:
```bash
# Run from project root
./scripts/setup-git-hooks.sh

# To bypass hooks (not recommended)
git commit --no-verify
git push --no-verify
```

**Requirements**:
- Flutter SDK installed
- Git repository initialized
- Bash shell

**First-time Setup**:
```bash
# Make script executable
chmod +x scripts/setup-git-hooks.sh

# Run setup
./scripts/setup-git-hooks.sh
```

**Output**:
```
🔧 Setting up Git hooks for Helix-iOS...
📝 Creating pre-commit hook...
✅ Pre-commit hook created
📝 Creating pre-push hook...
✅ Pre-push hook created
📝 Creating commit-msg hook...
✅ Commit-msg hook created

✅ Git hooks setup complete!

Installed hooks:
  • pre-commit: Runs formatting, analysis, and tests
  • pre-push: Runs comprehensive checks before push
  • commit-msg: Enforces conventional commit format
```

## Adding New Scripts

When adding new scripts to this directory:

1. **Make executable**: `chmod +x scripts/your-script.sh`
2. **Add shebang**: Start with `#!/bin/bash`
3. **Add documentation**: Update this README
4. **Error handling**: Use `set -e` for safety
5. **Help output**: Support `--help` flag
6. **Exit codes**: Return appropriate exit codes

## Script Best Practices

- Use meaningful names
- Add comments for complex logic
- Validate inputs
- Provide clear error messages
- Support dry-run mode when applicable
- Log important actions
