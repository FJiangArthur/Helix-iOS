# Dependency Management Quick Reference

> **Quick commands and workflows for day-to-day dependency management**

---

## 🚀 Quick Start

```bash
# Install all dependencies
make deps-install

# Check dependency health
make deps-check

# Run security audit
make deps-audit

# Check for updates
make deps-outdated
```

---

## 📦 Common Tasks

### Installing Dependencies

```bash
# All platforms
make deps-install

# Flutter only
flutter pub get

# iOS only
cd ios && pod install

# macOS only
cd macos && pod install
```

### Updating Dependencies

```bash
# Update minor/patch versions (safe)
make deps-update TYPE=minor

# Update to latest major versions (careful!)
make deps-update TYPE=major

# Update specific Flutter package
flutter pub upgrade package_name

# Update specific iOS pod
cd ios && pod update PodName
```

### Checking Dependency Health

```bash
# Full dependency check
make deps-check

# Security audit
make deps-audit

# Check outdated packages
make deps-outdated

# Flutter specific
flutter pub outdated
dart pub audit
```

---

## 🔒 Security

### Running Security Audits

```bash
# Comprehensive security audit
./scripts/deps-audit.sh

# Quick security check
dart pub audit

# Generate security report
make security-report
```

### Handling Vulnerabilities

```bash
# 1. Identify vulnerabilities
dart pub audit

# 2. Update affected packages
flutter pub upgrade package_name

# 3. Verify fix
dart pub audit

# 4. Commit lockfile
git add pubspec.lock
git commit -m "security: update package_name to fix vulnerability"
```

---

## 🔍 Troubleshooting

### Lockfile Issues

```bash
# Lockfile out of sync
flutter pub get
git add pubspec.lock
git commit -m "deps: update lockfile"

# Verify lockfile integrity
./scripts/deps-check.sh
```

### CocoaPods Issues

```bash
# Update repos
pod repo update

# Clear cache
pod cache clean --all

# Reinstall
cd ios
rm -rf Pods Podfile.lock
pod install
```

### Dependency Conflicts

```bash
# View dependency tree
flutter pub deps

# Check for conflicts
flutter pub deps --no-dev

# Force resolution (use sparingly)
# Add to pubspec.yaml:
dependency_overrides:
  conflicting_package: ^2.0.0
```

### Clean Slate

```bash
# Clean all caches
make deps-clean

# Reinstall everything
make deps-install
```

---

## 📋 Makefile Commands

| Command | Description |
|---------|-------------|
| `make deps-install` | Install all dependencies |
| `make deps-check` | Verify dependencies and lockfiles |
| `make deps-update` | Update dependencies safely |
| `make deps-audit` | Run security audit |
| `make deps-outdated` | Check for outdated packages |
| `make deps-clean` | Clean dependency caches |

---

## 🔄 CI/CD

### Pre-commit Checks

```bash
# Run before committing
./scripts/deps-check.sh

# If lockfile changed
git add pubspec.lock ios/Podfile.lock macos/Podfile.lock
git commit -m "deps: update lockfiles"
```

### Automated Updates

- **Dependabot**: Creates PRs weekly
- **Security updates**: Immediate
- **Review and merge**: After CI passes

---

## 📝 File Locations

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Flutter/Dart dependencies |
| `pubspec.lock` | Flutter/Dart lockfile (commit this!) |
| `ios/Podfile` | iOS dependencies |
| `ios/Podfile.lock` | iOS lockfile (commit this!) |
| `macos/Podfile` | macOS dependencies |
| `macos/Podfile.lock` | macOS lockfile (commit this!) |

---

## ⚡ Pro Tips

1. **Always commit lockfiles** - Ensures reproducible builds
2. **Run security audits regularly** - Catch vulnerabilities early
3. **Update incrementally** - Easier to identify issues
4. **Read changelogs** - Understand what's changing
5. **Test after updates** - Prevent breaking changes

---

## 📖 Full Documentation

For comprehensive information, see:
- [Dependency Management Guide](./DEPENDENCY_MANAGEMENT.md)
- [Security Guide](../SECURITY.md)
- [CI/CD Documentation](../CI_CD_INTEGRATION.md)

---

**Last updated:** 2025-11-16
