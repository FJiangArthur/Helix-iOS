# CI/CD Pipeline Documentation

This document provides comprehensive documentation for the Helix-iOS CI/CD pipeline, including workflow details, quality gates, and troubleshooting guides.

## Table of Contents
- [Overview](#overview)
- [Pipeline Architecture](#pipeline-architecture)
- [Quality Gates](#quality-gates)
- [Workflow Jobs](#workflow-jobs)
- [Local Development](#local-development)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

The Helix-iOS project uses GitHub Actions for continuous integration and continuous deployment. The pipeline enforces strict quality gates to ensure code quality, security, and reliability.

### Pipeline Triggers

The CI/CD pipeline runs on:
- **Push to `main` or `develop` branches**
- **Pull requests targeting `main` or `develop` branches**

### Pipeline Goals

1. ✅ Ensure code quality through static analysis
2. ✅ Verify all tests pass
3. ✅ Confirm builds succeed on all platforms
4. ✅ Detect security vulnerabilities
5. ✅ Check license compliance
6. ✅ Provide fast feedback to developers

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     CI/CD Pipeline                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐                                          │
│  │  Trigger:    │                                          │
│  │  Push/PR     │                                          │
│  └──────┬───────┘                                          │
│         │                                                   │
│         v                                                   │
│  ┌──────────────────────────────────────────┐             │
│  │     Job 1: Code Analysis & Linting       │             │
│  │     - Flutter analyze                     │             │
│  │     - Format check                        │             │
│  │     - Custom import validation            │             │
│  └──────┬───────────────────────────────────┘             │
│         │                                                   │
│         v                                                   │
│  ┌──────────────────────────────────────────┐             │
│  │     Job 2: Unit Tests                     │             │
│  │     - Run all tests                       │             │
│  │     - Generate coverage                   │             │
│  │     - Verify coverage threshold (60%)     │             │
│  └──────┬───────────────────────────────────┘             │
│         │                                                   │
│    ┌────┴────┬───────────┬──────────────┐                 │
│    v         v           v              v                  │
│  ┌─────┐  ┌─────┐  ┌────────┐  ┌──────────┐              │
│  │Build│  │Build│  │Security│  │ License  │              │
│  │ iOS │  │ And │  │  Scan  │  │  Check   │              │
│  └─────┘  └─────┘  └────────┘  └──────────┘              │
│    │         │           │              │                  │
│    └────┬────┴───────────┴──────────────┘                 │
│         │                                                   │
│         v                                                   │
│  ┌──────────────────────────────────────────┐             │
│  │     Job 7: CI Success                     │             │
│  │     - Verify all checks passed            │             │
│  └───────────────────────────────────────────┘             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Quality Gates

All jobs must pass for the pipeline to succeed. This section details each quality gate.

### Gate 1: Code Analysis & Linting

**Purpose**: Ensure code meets quality standards and follows conventions.

**Checks**:
- ✅ Flutter static analysis (`flutter analyze`)
  - No errors allowed
  - No warnings allowed
  - No info messages allowed (using `--fatal-infos`)
- ✅ Code formatting (`dart format`)
  - All files must be properly formatted
  - Consistent style across the codebase
- ✅ Custom import validation
  - No circular dependencies
  - Proper import organization

**Failure Criteria**:
- Any analysis error, warning, or info
- Any formatting issue
- Custom validation failures

**Fix**:
```bash
# Format code
dart format .

# Fix analysis issues
flutter analyze

# Run custom checks
./check_imports.sh
```

### Gate 2: Unit Tests

**Purpose**: Ensure code functionality and prevent regressions.

**Checks**:
- ✅ All unit tests pass
- ✅ Test coverage ≥ 60%
- ✅ No flaky tests

**Failure Criteria**:
- Any test failure
- Coverage below 60%

**Fix**:
```bash
# Run tests locally
flutter test

# Run tests with coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Gate 3: Build Verification (iOS)

**Purpose**: Ensure iOS build succeeds.

**Checks**:
- ✅ iOS build completes without errors
- ✅ No compilation issues
- ✅ Dependencies resolve correctly

**Platform**: macOS (required for iOS builds)

**Failure Criteria**:
- Build errors
- Missing dependencies
- Configuration issues

**Fix**:
```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build iOS
flutter build ios --release --no-codesign
```

### Gate 4: Build Verification (Android)

**Purpose**: Ensure Android build succeeds.

**Checks**:
- ✅ Android APK build completes
- ✅ Android App Bundle build completes
- ✅ No compilation issues

**Platform**: Ubuntu with Java 17

**Failure Criteria**:
- Build errors
- Gradle issues
- Missing dependencies

**Fix**:
```bash
# Clean build
flutter clean

# Get dependencies
flutter pub get

# Build APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

### Gate 5: Security Scanning

**Purpose**: Detect vulnerabilities and secrets in code.

**Checks**:
- ✅ Dependency vulnerability scan (`dart pub audit`)
- ✅ Secret detection (TruffleHog)
- ✅ OSSF Scorecard analysis

**Failure Criteria**:
- Critical vulnerabilities in dependencies
- Secrets detected in code
- Poor security scorecard

**Fix**:
```bash
# Audit dependencies
dart pub audit

# Update vulnerable dependencies
flutter pub upgrade

# Check for secrets
# Remove any API keys, passwords, tokens from code
# Use environment variables or secure storage
```

### Gate 6: License Compliance

**Purpose**: Ensure all dependencies have acceptable licenses.

**Checks**:
- ✅ All dependencies have valid licenses
- ✅ License compatibility check

**Failure Criteria**:
- Incompatible licenses
- Missing license information

**Fix**:
```bash
# Check dependency licenses
flutter pub deps --json

# Review and replace incompatible dependencies
```

## Workflow Jobs

### Job 1: Code Analysis & Linting

```yaml
Name: analyze
Platform: ubuntu-latest
Timeout: 15 minutes
Dependencies: None
```

**Steps**:
1. Checkout code
2. Setup Flutter 3.35.0
3. Cache pub dependencies
4. Install dependencies
5. Verify Flutter installation
6. Run static analysis
7. Check code formatting
8. Run custom import validation

**Outputs**: None

**Artifacts**: None

### Job 2: Unit Tests

```yaml
Name: test
Platform: ubuntu-latest
Timeout: 20 minutes
Dependencies: analyze
```

**Steps**:
1. Checkout code
2. Setup Flutter
3. Cache dependencies
4. Install dependencies
5. Run tests with coverage
6. Verify coverage threshold
7. Upload coverage report

**Outputs**: Coverage percentage

**Artifacts**:
- `coverage-report` (30 days retention)

### Job 3: Build iOS

```yaml
Name: build-ios
Platform: macos-latest
Timeout: 30 minutes
Dependencies: analyze, test
```

**Steps**:
1. Checkout code
2. Setup Flutter
3. Cache dependencies
4. Install dependencies
5. Build iOS app (no codesign)
6. Archive build artifacts

**Outputs**: None

**Artifacts**:
- `ios-build` (7 days retention)

### Job 4: Build Android

```yaml
Name: build-android
Platform: ubuntu-latest
Timeout: 30 minutes
Dependencies: analyze, test
```

**Steps**:
1. Checkout code
2. Setup Java 17
3. Setup Flutter
4. Cache pub dependencies
5. Cache Gradle
6. Install dependencies
7. Build APK
8. Build App Bundle
9. Archive artifacts

**Outputs**: None

**Artifacts**:
- `android-apk` (7 days retention)
- `android-bundle` (7 days retention)

### Job 5: Security Scanning

```yaml
Name: security
Platform: ubuntu-latest
Timeout: 15 minutes
Dependencies: analyze
```

**Steps**:
1. Checkout code
2. Setup Flutter
3. Install dependencies
4. Run dependency audit
5. Scan for secrets
6. Run OSSF Scorecard
7. Upload SARIF results

**Outputs**: Security findings

**Artifacts**: SARIF report

### Job 6: License Compliance

```yaml
Name: license-check
Platform: ubuntu-latest
Timeout: 10 minutes
Dependencies: None
```

**Steps**:
1. Checkout code
2. Setup Flutter
3. Install dependencies
4. Generate license report
5. Upload license report

**Outputs**: None

**Artifacts**:
- `license-report` (30 days retention)

### Job 7: CI Success

```yaml
Name: ci-success
Platform: ubuntu-latest
Dependencies: All previous jobs
Condition: success()
```

**Steps**:
1. Print success message
2. Summarize passed checks

**Purpose**: Provides a single status check for branch protection

## Local Development

### Pre-commit Checks

Before committing code, ensure local checks pass:

```bash
# 1. Format code
dart format .

# 2. Run analysis
flutter analyze --fatal-infos --fatal-warnings

# 3. Run tests
flutter test

# 4. Run custom checks
./check_imports.sh
```

### Setup Git Hooks

Automate pre-commit checks:

```bash
# Run setup script
./scripts/setup-git-hooks.sh

# This installs:
# - pre-commit: formatting, analysis, tests
# - pre-push: comprehensive checks
# - commit-msg: conventional commit format
```

### Using Pre-commit Framework

For advanced hooks:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

## Troubleshooting

### Common Issues

#### Issue: "Flutter analyze failed"

**Symptoms**:
```
error • The method 'xyz' isn't defined for the type 'ABC'
```

**Solution**:
1. Run `flutter pub get` to ensure dependencies are installed
2. Check for typos in method names
3. Ensure proper imports
4. Fix the code and run `flutter analyze` locally

#### Issue: "Code formatting check failed"

**Symptoms**:
```
❌ Code formatting check failed
💡 Run: dart format .
```

**Solution**:
```bash
# Format all files
dart format .

# Commit the changes
git add .
git commit -m "style: format code"
```

#### Issue: "Tests failed"

**Symptoms**:
```
Some tests failed.
```

**Solution**:
1. Run tests locally: `flutter test`
2. Check test output for failures
3. Fix the failing tests
4. Verify tests pass locally before pushing

#### Issue: "Coverage below threshold"

**Symptoms**:
```
❌ Coverage 45% is below threshold 60%
```

**Solution**:
1. Add more unit tests
2. Focus on untested code paths
3. Run `flutter test --coverage` to see coverage report
4. Use `lcov` to generate HTML report:
   ```bash
   genhtml coverage/lcov.info -o coverage/html
   open coverage/html/index.html
   ```

#### Issue: "iOS build failed"

**Symptoms**:
```
Build failed with error: ...
```

**Solution**:
1. Clean build: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Update CocoaPods: `cd ios && pod install`
4. Build locally: `flutter build ios --release --no-codesign`
5. Check for platform-specific issues in `ios/` directory

#### Issue: "Android build failed"

**Symptoms**:
```
Gradle build failed
```

**Solution**:
1. Clean build: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Check Gradle version compatibility
4. Clear Gradle cache: `cd android && ./gradlew clean`
5. Build locally: `flutter build apk --release`

#### Issue: "Security scan found secrets"

**Symptoms**:
```
⚠️ Warning: Potential secrets detected
```

**Solution**:
1. Review detected secrets
2. Remove sensitive data from code
3. Use environment variables
4. Add secrets to `.gitignore`
5. If accidentally committed, rotate the secrets

### Getting Help

If you encounter issues:

1. **Check logs**: View detailed logs in GitHub Actions
2. **Run locally**: Reproduce the issue on your machine
3. **Ask team**: Contact team members in Slack/Teams
4. **Documentation**: Review Flutter and GitHub Actions docs
5. **Open issue**: Create a GitHub issue if it's a bug

## Best Practices

### For Developers

1. **Run checks locally before pushing**
   ```bash
   ./scripts/setup-git-hooks.sh  # One-time setup
   # Hooks will run automatically on commit/push
   ```

2. **Write tests for new features**
   - Aim for >80% coverage on new code
   - Include unit, widget, and integration tests

3. **Keep builds green**
   - Fix failing builds immediately
   - Don't push if local checks fail

4. **Use conventional commits**
   ```
   feat(audio): add recording functionality
   fix(ble): resolve connection timeout issue
   docs(readme): update installation instructions
   ```

5. **Review CI feedback**
   - Check GitHub Actions results
   - Address issues promptly

### For Reviewers

1. **Verify CI passes before reviewing**
   - Don't review if CI is failing
   - Request fixes first

2. **Check coverage reports**
   - Ensure new code is tested
   - Download coverage artifact if needed

3. **Review security findings**
   - Check security scan results
   - Ensure no critical issues

4. **Test builds**
   - Download build artifacts if needed
   - Verify on physical devices when necessary

### For Maintainers

1. **Monitor pipeline health**
   - Track build success rates
   - Identify flaky tests

2. **Update dependencies**
   - Keep Flutter version current
   - Update GitHub Actions regularly

3. **Review and improve**
   - Optimize slow jobs
   - Add new quality checks as needed

4. **Document changes**
   - Update this document
   - Communicate pipeline changes

## Pipeline Metrics

### Success Criteria

- **Build Success Rate**: >95%
- **Average Build Time**: <15 minutes
- **Test Coverage**: >60% (target: >80%)
- **Security Issues**: 0 critical
- **Flaky Test Rate**: <1%

### Monitoring

Check pipeline health:
- GitHub Actions dashboard
- Insights → Actions
- Track build times and success rates

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter CI/CD Best Practices](https://docs.flutter.dev/deployment/cd)
- [Branch Protection Rules](./BRANCH_PROTECTION.md)
- [Contributing Guidelines](../README.md)

## Changelog

| Version | Date       | Changes                          |
|---------|------------|----------------------------------|
| 1.0.0   | 2025-11-16 | Initial CI/CD pipeline setup     |

---

**Last Updated**: 2025-11-16
**Maintained By**: DevOps Team
**Contact**: See repository maintainers

For questions or suggestions about the CI/CD pipeline, please open an issue or contact the DevOps team.
