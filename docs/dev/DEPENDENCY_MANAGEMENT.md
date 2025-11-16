# Dependency Management Guide

> **Comprehensive guide for managing dependencies in the Helix iOS project**

---

## Table of Contents

1. [Overview](#overview)
2. [Package Managers](#package-managers)
3. [Lockfile Policy](#lockfile-policy)
4. [Version Pinning Strategy](#version-pinning-strategy)
5. [Security Policies](#security-policies)
6. [Automated Updates](#automated-updates)
7. [Maintenance Scripts](#maintenance-scripts)
8. [CI/CD Integration](#cicd-integration)
9. [Troubleshooting](#troubleshooting)
10. [Best Practices](#best-practices)

---

## Overview

The Helix iOS project uses multiple package managers to manage dependencies across different platforms:

- **Flutter/Dart**: `pubspec.yaml` + `pubspec.lock` managed by `pub`
- **iOS**: `Podfile` + `Podfile.lock` managed by CocoaPods
- **macOS**: `Podfile` + `Podfile.lock` managed by CocoaPods
- **Android**: `build.gradle.kts` managed by Gradle

This guide focuses on ensuring **secure**, **reproducible**, and **maintainable** dependency management.

---

## Package Managers

### 1. Flutter/Dart (pub)

**Primary configuration:** `pubspec.yaml`
**Lockfile:** `pubspec.lock`
**CLI tool:** `flutter pub` / `dart pub`

#### Configuration Files

- **`.pubrc.yaml`**: Pub package manager configuration
  - Lockfile enforcement
  - Security audit settings
  - Cache configuration

#### Common Commands

```bash
# Install dependencies
flutter pub get

# Update dependencies (minor/patch versions)
flutter pub upgrade --minor-versions

# Update to major versions
flutter pub upgrade --major-versions

# Check for outdated packages
flutter pub outdated

# Security audit
dart pub audit

# Generate dependency tree
flutter pub deps
```

### 2. CocoaPods (iOS/macOS)

**Primary configuration:** `ios/Podfile`, `macos/Podfile`
**Lockfiles:** `ios/Podfile.lock`, `macos/Podfile.lock`
**CLI tool:** `pod`

#### Configuration Files

- **`.cocoapods-config.yaml`**: CocoaPods policies and best practices

#### Common Commands

```bash
# Install dependencies
cd ios && pod install

# Update all pods
cd ios && pod update

# Update specific pod
cd ios && pod update PodName

# Update pod repos
pod repo update

# Check outdated pods
cd ios && pod outdated
```

### 3. Gradle (Android)

**Primary configuration:** `android/build.gradle.kts`
**Lockfile:** Gradle handles dependency resolution internally
**CLI tool:** `gradle` (via `gradlew`)

#### Common Commands

```bash
# Install/sync dependencies
cd android && ./gradlew dependencies

# Check for dependency updates
cd android && ./gradlew dependencyUpdates
```

---

## Lockfile Policy

### ✅ Lockfiles MUST Be Committed

All lockfiles must be committed to version control to ensure reproducible builds:

- ✅ `pubspec.lock`
- ✅ `ios/Podfile.lock`
- ✅ `macos/Podfile.lock`

### Why Commit Lockfiles?

1. **Reproducibility**: Same dependencies across all environments
2. **Security**: Known, tested versions
3. **Stability**: Prevents unexpected updates
4. **CI/CD**: Consistent builds in pipelines

### Lockfile Verification

Our CI/CD pipeline automatically verifies lockfile integrity:

```yaml
# Runs on every push/PR
- Verify lockfile exists
- Install dependencies
- Check lockfile hasn't changed
- Fail build if lockfile is out of sync
```

---

## Version Pinning Strategy

### Flutter/Dart Dependencies

We use **caret (`^`) constraints** for most dependencies:

```yaml
dependencies:
  # Allows: >=1.0.0 <2.0.0
  package_name: ^1.0.0
```

**Guidelines:**

- **Production dependencies**: Use caret (`^`) for flexibility within major version
- **Security-critical packages**: Consider exact versions
- **Development dependencies**: More permissive constraints acceptable
- **Avoid**: Git dependencies in production

### CocoaPods Dependencies

We use **pessimistic operator (`~>`)** for pods:

```ruby
# Allows: >=1.0.0 <1.1.0
pod 'PodName', '~> 1.0.0'
```

### When to Pin Exact Versions

Use exact versions (`=`) for:

- Packages with known stability issues
- Security-critical dependencies
- Packages with frequent breaking changes

---

## Security Policies

### 1. Automated Security Audits

**Frequency:** On every `flutter pub get` and in CI/CD

```bash
# Run security audit
dart pub audit

# With JSON output for parsing
dart pub audit --json
```

### 2. Severity Levels

Our policy for handling vulnerabilities:

| Severity | Action | Timeline |
|----------|--------|----------|
| **Critical** | ❌ **Block build** | Fix immediately |
| **High** | ❌ **Block build** | Fix within 24 hours |
| **Medium** | ⚠️ **Warn** | Fix within 1 week |
| **Low** | ℹ️ **Info** | Fix in next release |

### 3. Security Audit Script

```bash
# Comprehensive security audit
./scripts/deps-audit.sh

# Generates detailed report in security-reports/
```

### 4. Prohibited Dependency Patterns

❌ **Do NOT use:**

- **Git dependencies** in production (unstable, unversioned)
- **Path dependencies** in production (not portable)
- **Pre-release versions** in production (untested)
- **Unverified sources** (security risk)

✅ **Do use:**

- Official package repositories (pub.dev, CocoaPods CDN)
- Verified, well-maintained packages
- Packages with active security policies
- Packages with good test coverage

---

## Automated Updates

### 1. Dependabot Configuration

**Location:** `.github/dependabot.yml`

**Features:**
- Automated weekly dependency updates
- Security updates (immediate)
- Grouped updates by type
- Automatic PR creation

**Schedule:**
- **Pub/Dart**: Monday @ 9:00 UTC
- **GitHub Actions**: Monday @ 10:00 UTC
- **Docker**: Tuesday @ 9:00 UTC
- **Gradle**: Wednesday @ 9:00 UTC

### 2. Renovate Configuration

**Location:** `renovate.json`

**Advanced features:**
- More granular control
- Lockfile maintenance
- Digest pinning for Docker
- Custom update schedules

### 3. Handling Automated PRs

1. **Review the PR**
   - Check changelog/release notes
   - Identify breaking changes
   - Review security advisories

2. **Verify CI passes**
   - All tests pass
   - Security audit passes
   - Builds succeed

3. **Test locally** (for major updates)
   ```bash
   git checkout <dependabot-branch>
   flutter pub get
   flutter test
   flutter build ios --no-codesign
   ```

4. **Merge if safe**
   - Minor/patch updates: Generally safe
   - Major updates: Requires thorough testing

---

## Maintenance Scripts

We provide scripts for common dependency management tasks:

### 1. Dependency Check

**Script:** `./scripts/deps-check.sh`

**Purpose:** Comprehensive dependency validation

```bash
./scripts/deps-check.sh
```

**Checks:**
- ✅ Lockfiles exist
- ✅ Dependencies install cleanly
- ✅ Lockfiles are in sync
- 🔒 Security vulnerabilities
- 📦 Outdated packages
- 🌳 Dependency tree analysis
- ⚠️ Problematic patterns (git/path deps)

### 2. Dependency Update

**Script:** `./scripts/deps-update.sh`

**Purpose:** Safe dependency updates with rollback

```bash
# Update minor/patch versions (recommended)
./scripts/deps-update.sh minor

# Update to latest major versions (careful!)
./scripts/deps-update.sh major

# Dry run (no changes)
./scripts/deps-update.sh minor true
```

**Process:**
1. Creates lockfile backups
2. Updates dependencies
3. Runs security audit
4. Runs tests
5. Shows changes
6. Rolls back on failure

### 3. Security Audit

**Script:** `./scripts/deps-audit.sh`

**Purpose:** Comprehensive security scanning

```bash
./scripts/deps-audit.sh
```

**Output:**
- Detailed security report (Markdown)
- Vulnerability counts by severity
- Dependency tree analysis
- License compliance report
- Recommendations

**Report location:** `security-reports/`

---

## CI/CD Integration

### GitHub Actions Workflow

**File:** `.github/workflows/ci.yml`

#### Dependency Verification Steps

```yaml
1. Verify lockfile exists
   ├─ pubspec.lock
   ├─ ios/Podfile.lock
   └─ macos/Podfile.lock

2. Install dependencies
   ├─ flutter pub get
   ├─ pod install (iOS)
   └─ pod install (macOS)

3. Verify lockfile integrity
   └─ Check no changes after install

4. Security audit
   ├─ dart pub audit
   ├─ Parse vulnerability counts
   └─ Fail on CRITICAL/HIGH

5. Check outdated packages
   └─ flutter pub outdated (informational)
```

#### Caching Strategy

```yaml
# Cache pub dependencies
key: ${{ runner.os }}-pub-${{ hashFiles('**/pubspec.lock') }}

# Cache CocoaPods
key: ${{ runner.os }}-pods-${{ hashFiles('**/Podfile.lock') }}

# Cache Gradle
key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*') }}
```

---

## Troubleshooting

### Common Issues

#### 1. "pubspec.lock is out of sync"

**Cause:** Lockfile doesn't match pubspec.yaml

**Solution:**
```bash
flutter pub get
git add pubspec.lock
git commit -m "deps: update lockfile"
```

#### 2. "Pod install fails"

**Cause:** CocoaPods repo out of date or cache issues

**Solution:**
```bash
# Update CocoaPods repos
pod repo update

# Clear cache
pod cache clean --all

# Reinstall
cd ios
rm -rf Pods Podfile.lock
pod install
```

#### 3. "Dependency conflict"

**Cause:** Multiple packages require incompatible versions

**Solution:**
```bash
# Check dependency tree
flutter pub deps

# Use dependency_overrides (temporary)
# In pubspec.yaml:
dependency_overrides:
  conflicting_package: ^2.0.0
```

#### 4. "Security vulnerabilities found"

**Cause:** Known vulnerabilities in dependencies

**Solution:**
```bash
# Update to patched versions
flutter pub upgrade --major-versions

# Check specific package
dart pub audit
```

#### 5. "CI fails on lockfile integrity"

**Cause:** Lockfile changed during `pub get`

**Solution:**
```bash
# Run locally and commit changes
flutter pub get
git diff pubspec.lock  # Review changes
git add pubspec.lock
git commit -m "deps: update lockfile after dependency changes"
```

---

## Best Practices

### ✅ Do

1. **Always commit lockfiles**
   - Ensures reproducible builds
   - Required for CI/CD

2. **Run security audits regularly**
   ```bash
   ./scripts/deps-audit.sh
   ```

3. **Review dependency updates**
   - Read changelogs
   - Check for breaking changes
   - Test before merging

4. **Use version constraints wisely**
   - Caret (`^`) for most deps
   - Exact for security-critical
   - Avoid overly permissive (`*`)

5. **Keep dependencies updated**
   - Weekly automated checks
   - Monthly manual reviews
   - Quarterly major version updates

6. **Document custom dependencies**
   - Why it's needed
   - Alternatives considered
   - Update strategy

7. **Test after updates**
   ```bash
   flutter test
   flutter build ios --no-codesign
   flutter build apk
   ```

### ❌ Don't

1. **Don't ignore lockfile changes**
   - Review all changes
   - Understand what updated
   - Test thoroughly

2. **Don't use git dependencies in production**
   - Unpredictable versions
   - No security audits
   - Can disappear

3. **Don't skip security audits**
   - Always run before releases
   - Act on findings
   - Document exceptions

4. **Don't update everything at once**
   - Update incrementally
   - Test between updates
   - Easier to identify issues

5. **Don't ignore CI warnings**
   - Lockfile integrity failures
   - Security warnings
   - Outdated dependency notices

6. **Don't hardcode dependencies**
   - Use package manager
   - Version in lockfiles
   - Document in pubspec.yaml

---

## Maintenance Schedule

### Daily
- ✅ Automated Dependabot PRs created
- ✅ Security scans in CI/CD

### Weekly
- 📅 Review Dependabot PRs
- 📅 Merge safe updates
- 🔍 Check for outdated packages

### Monthly
- 📅 Manual security audit
- 📅 Review major version updates
- 📅 Lockfile maintenance
- 📋 Update this documentation

### Quarterly
- 📅 Comprehensive dependency review
- 📅 Evaluate alternative packages
- 📅 Major version migration planning
- 📊 Dependency health report

---

## Quick Reference

### Essential Commands

```bash
# Install dependencies
flutter pub get

# Update dependencies
./scripts/deps-update.sh minor

# Security audit
./scripts/deps-audit.sh

# Dependency check
./scripts/deps-check.sh

# Check outdated
flutter pub outdated

# iOS pods
cd ios && pod install
```

### File Locations

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Dart/Flutter dependencies |
| `pubspec.lock` | Dart/Flutter lockfile |
| `ios/Podfile` | iOS CocoaPods config |
| `ios/Podfile.lock` | iOS lockfile |
| `macos/Podfile` | macOS CocoaPods config |
| `macos/Podfile.lock` | macOS lockfile |
| `.pubrc.yaml` | Pub configuration |
| `.cocoapods-config.yaml` | CocoaPods policies |
| `.github/dependabot.yml` | Dependabot config |
| `renovate.json` | Renovate config |
| `scripts/deps-*.sh` | Maintenance scripts |

---

## Support

For questions or issues:

1. Check this documentation
2. Review [Flutter dependencies guide](https://dart.dev/tools/pub/dependencies)
3. Review [CocoaPods guide](https://guides.cocoapods.org)
4. Open an issue on GitHub
5. Contact the security team for vulnerabilities

---

**Last updated:** 2025-11-16
**Maintained by:** Helix Security Team
**Version:** 1.0
