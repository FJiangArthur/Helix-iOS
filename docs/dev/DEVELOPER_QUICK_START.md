# Developer Quick Start Guide

This guide helps you quickly set up your development environment and understand the CI/CD quality gates.

## Table of Contents
- [Initial Setup](#initial-setup)
- [Daily Workflow](#daily-workflow)
- [Quality Checks](#quality-checks)
- [Common Tasks](#common-tasks)
- [Troubleshooting](#troubleshooting)

## Initial Setup

### 1. Clone Repository

```bash
git clone https://github.com/YOUR-USERNAME/Helix-iOS.git
cd Helix-iOS
```

### 2. Install Dependencies

```bash
# Get Flutter dependencies
flutter pub get

# Verify Flutter installation
flutter doctor -v
```

### 3. Setup Git Hooks (Recommended)

```bash
# Setup pre-commit hooks
./scripts/setup-git-hooks.sh
```

This installs hooks that automatically run quality checks before commits and pushes.

### 4. Verify Setup

```bash
# Run all quality checks
flutter analyze
dart format .
flutter test
```

If all checks pass, you're ready to develop!

## Daily Workflow

### Starting a New Feature

```bash
# 1. Sync with develop
git checkout develop
git pull origin develop

# 2. Create feature branch
git checkout -b feature/your-feature-name

# 3. Make changes and test locally
# (develop your feature)

# 4. Run quality checks
flutter analyze
flutter test

# 5. Commit with conventional commit format
git add .
git commit -m "feat(scope): add new feature"
# Git hooks will run automatically

# 6. Push to remote
git push origin feature/your-feature-name

# 7. Create Pull Request on GitHub
```

### Conventional Commit Format

Use this format for all commits:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `perf`: Performance improvements
- `ci`: CI/CD changes

**Examples**:
```bash
git commit -m "feat(audio): add recording functionality"
git commit -m "fix(ble): resolve connection timeout"
git commit -m "docs(readme): update installation steps"
git commit -m "test(audio): add buffer manager tests"
```

## Quality Checks

All PRs must pass these checks:

### ✅ 1. Code Analysis

```bash
# Run static analysis
flutter analyze --fatal-infos --fatal-warnings

# Should show:
# Analyzing helix_ios...
# No issues found!
```

**Fix issues**:
- Follow analyzer suggestions
- Fix all errors, warnings, and infos

### ✅ 2. Code Formatting

```bash
# Check formatting
dart format --set-exit-if-changed .

# Or auto-format
dart format .
```

**Fix issues**:
- Run `dart format .` to auto-format
- Commit formatting changes

### ✅ 3. Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# View coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

**Requirements**:
- All tests must pass
- Coverage must be ≥60%

### ✅ 4. Builds

```bash
# iOS build
flutter build ios --release --no-codesign

# Android build
flutter build apk --release
```

**Requirements**:
- No build errors
- No warnings

### ✅ 5. Security

```bash
# Check for vulnerable dependencies
dart pub audit

# Check for secrets (if you have TruffleHog installed)
trufflehog filesystem .
```

## Common Tasks

### Update Dependencies

```bash
# Update all dependencies
flutter pub upgrade

# Update specific package
flutter pub upgrade package_name

# Check for outdated packages
flutter pub outdated
```

### Generate Code (Freezed, JSON Serialization)

```bash
# One-time generation
flutter pub run build_runner build

# Watch mode (auto-regenerate)
flutter pub run build_runner watch

# Clean and rebuild
flutter pub run build_runner build --delete-conflicting-outputs
```

### Run on Device/Simulator

```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run in debug mode
flutter run

# Run in release mode
flutter run --release
```

### Clean Build

```bash
# Clean Flutter build
flutter clean

# Get dependencies again
flutter pub get

# Rebuild
flutter build ios # or flutter build apk
```

## CI/CD Pipeline

When you push code or create a PR, the CI/CD pipeline automatically runs:

```
1. Code Analysis (5-10 min)
   ↓
2. Unit Tests (10-15 min)
   ↓
3. Builds (iOS & Android in parallel, 15-25 min)
   ↓
4. Security Scan (5-10 min)
   ↓
5. License Check (3-5 min)
   ↓
6. ✅ CI Success
```

### View Pipeline Status

1. Go to your PR on GitHub
2. Scroll to bottom to see checks
3. Click "Details" to view logs
4. Download artifacts if needed

### If CI Fails

1. **Check the logs**: Click "Details" on failed check
2. **Reproduce locally**: Run the same commands locally
3. **Fix the issue**: Make necessary changes
4. **Push fix**: Git hooks will verify before push
5. **Verify CI**: Watch the new pipeline run

## Troubleshooting

### "Git hooks failing"

```bash
# Re-run setup
./scripts/setup-git-hooks.sh

# Or bypass (not recommended)
git commit --no-verify
```

### "Tests failing locally"

```bash
# Clean and retry
flutter clean
flutter pub get
flutter test

# Run specific test
flutter test test/path/to/test_file.dart
```

### "Build failing"

```bash
# iOS
cd ios
pod install
cd ..
flutter clean
flutter build ios

# Android
cd android
./gradlew clean
cd ..
flutter clean
flutter build apk
```

### "Merge conflicts"

```bash
# Update your branch with latest develop
git checkout develop
git pull origin develop
git checkout your-feature-branch
git rebase develop

# Resolve conflicts in your editor
git add .
git rebase --continue

# Force push (after rebase)
git push --force-with-lease
```

## Code Review Checklist

Before requesting review, ensure:

- [ ] All CI checks pass
- [ ] Code is properly formatted
- [ ] Tests are added/updated
- [ ] Documentation is updated
- [ ] No console warnings
- [ ] Tested on device/simulator
- [ ] Conventional commit format used
- [ ] No sensitive data in code

## Resources

- [CI/CD Pipeline Documentation](./CI_CD_PIPELINE.md)
- [Branch Protection Rules](./BRANCH_PROTECTION.md)
- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)

## Getting Help

1. Check documentation in `docs/` folder
2. Ask in team chat
3. Open GitHub issue
4. Contact maintainers

---

**Happy coding!** 🚀
