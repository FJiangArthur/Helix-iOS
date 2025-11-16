# Security Quick Reference Guide

**Quick access to security commands, tools, and procedures for the Helix iOS application.**

---

## Quick Commands

### Run Security Scans

```bash
# Quick security check (recommended before commit)
make security-check

# Full security scan (recommended before PR)
make security-full

# Individual scans
make security-audit      # Check for vulnerable dependencies
make security-secrets    # Scan for hardcoded secrets
make security-sast      # Static application security testing
make security-licenses  # Check dependency licenses

# Generate security report
make security-report
```

### Install Security Tools

```bash
# Install pre-commit hooks (one-time setup)
pip install pre-commit
pre-commit install

# Test pre-commit hooks
pre-commit run --all-files
```

### Check Dependencies

```bash
# Audit for vulnerabilities
dart pub audit

# Check for outdated packages
dart pub outdated

# Update dependencies
flutter pub upgrade
```

---

## Security Checklist

### Before Every Commit

- [ ] Run `make security-check` or let pre-commit hooks run automatically
- [ ] No hardcoded secrets or credentials
- [ ] No debug/print statements in production code
- [ ] All HTTP URLs changed to HTTPS
- [ ] Input validation added for user inputs

### Before Every Pull Request

- [ ] Run `make security-full`
- [ ] All security tests passing
- [ ] Dependencies are up-to-date
- [ ] No high/critical security findings
- [ ] Security-related code reviewed

### Before Every Release

- [ ] Run full security scan: `make security-full`
- [ ] All dependencies audited and updated
- [ ] No known vulnerabilities
- [ ] Security configurations verified (iOS & Android)
- [ ] Code obfuscation enabled (Android)
- [ ] Certificate pinning configured
- [ ] Security review completed
- [ ] Penetration testing performed (if applicable)

---

## Common Security Issues & Fixes

### Issue: Hardcoded Secret Detected

**Problem**: `api_key = "sk_live_1234567890"`

**Fix**:
```dart
// ❌ BAD
const apiKey = "sk_live_1234567890";

// ✅ GOOD
final apiKey = await SecureStorage().read(key: 'api_key');
```

### Issue: Insecure HTTP Usage

**Problem**: `http://api.example.com`

**Fix**:
```dart
// ❌ BAD
final url = 'http://api.example.com/data';

// ✅ GOOD
final url = 'https://api.example.com/data';
```

### Issue: Sensitive Data in SharedPreferences

**Problem**: Storing tokens in SharedPreferences

**Fix**:
```dart
// ❌ BAD
await prefs.setString('auth_token', token);

// ✅ GOOD
const storage = FlutterSecureStorage();
await storage.write(key: 'auth_token', value: token);
```

### Issue: Debug Statements in Code

**Problem**: `print()` statements in production code

**Fix**:
```dart
// ❌ BAD
print('User data: $userData');

// ✅ GOOD
logger.debug('User data loaded', userData); // Use proper logger
// Or remove debug statements entirely
```

---

## Incident Response Quick Guide

### If You Discover a Security Issue

1. **DO NOT** commit or push the issue
2. **DO NOT** discuss publicly
3. **DO** notify security team immediately:
   - Email: security@helix-app.com
   - Emergency: incident-response@helix-app.com
4. **DO** document what you found
5. **DO** wait for security team guidance

### Severity Levels

| Level | Response Time | Examples |
|-------|---------------|----------|
| **P0 - Critical** | 1 hour | Active data breach, system compromise |
| **P1 - High** | 4 hours | Unauthorized access, critical vulnerability |
| **P2 - Medium** | 24 hours | Successful phishing, high severity bug |
| **P3 - Low** | 72 hours | Medium/low severity bug, policy violations |

### Incident Report Template

```markdown
**What**: [Brief description]
**When**: [Date/time discovered]
**Where**: [Affected systems/files]
**Impact**: [Data/users affected]
**Actions Taken**: [What you did]
**Next Steps**: [What needs to happen]
```

---

## Security Tools Overview

### Automated Tools (CI/CD)

| Tool | Purpose | Frequency |
|------|---------|-----------|
| dart pub audit | Dependency vulnerabilities | On push, PR, daily |
| TruffleHog | Secret scanning | On push, PR |
| GitLeaks | Secret detection | On push, PR |
| CodeQL | Advanced SAST | On push, PR |
| OSSF Scorecard | Supply chain security | On push (main) |

### Local Development Tools

| Tool | Command | Purpose |
|------|---------|---------|
| security-check.sh | `make security-check` | Comprehensive local scan |
| pre-commit hooks | Automatic on commit | Prevent security issues |
| Flutter analyze | `flutter analyze` | Static code analysis |

---

## Key Documentation

| Document | Purpose | Location |
|----------|---------|----------|
| Security Policy | Vulnerability disclosure | `/SECURITY.md` |
| Best Practices | Development guidelines | `/docs/SECURITY_BEST_PRACTICES.md` |
| Incident Response | Emergency procedures | `/docs/SECURITY_INCIDENT_RESPONSE.md` |
| Implementation Summary | Full security overview | `/SECURITY_IMPLEMENTATION_SUMMARY.md` |

---

## Security Contacts

- **Security Team**: security@helix-app.com
- **Incident Response**: incident-response@helix-app.com (24/7)
- **Questions**: security-questions@helix-app.com

---

## Common Patterns

### Secure Storage

```dart
// Use flutter_secure_storage for sensitive data
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const storage = FlutterSecureStorage();
await storage.write(key: 'token', value: token);
final token = await storage.read(key: 'token');
```

### Secure Network Calls

```dart
// Always use HTTPS with certificate pinning
import 'package:dio/dio.dart';

final dio = Dio(BaseOptions(
  baseUrl: 'https://api.helix-app.com', // Always HTTPS
  connectTimeout: Duration(seconds: 10),
));
```

### Input Validation

```dart
// Always validate and sanitize input
bool isValidEmail(String email) {
  final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  return regex.hasMatch(email);
}

String sanitizeInput(String input) {
  return input.replaceAll(RegExp(r'[<>"\']'), '').trim();
}
```

---

## Troubleshooting

### Pre-commit Hooks Not Running

```bash
# Reinstall hooks
pre-commit uninstall
pre-commit install

# Update hooks
pre-commit autoupdate
```

### Security Scan Failing

```bash
# Run with verbose output
./scripts/security-check.sh all

# Check specific issue
./scripts/security-check.sh secrets  # or audit, sast, etc.

# View detailed report
cat security-report.txt
```

### Dependabot PRs Not Appearing

1. Check `.github/dependabot.yml` configuration
2. Verify Dependabot is enabled in repository settings
3. Check for existing PRs (limit is 10 per ecosystem)
4. Review Dependabot logs in Security tab

---

## Additional Resources

- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Flutter Security Docs](https://docs.flutter.dev/security)
- [Dart Security Guidelines](https://dart.dev/guides/security)
- [NIST Mobile Guidelines](https://www.nist.gov/itl/applied-cybersecurity/mobile-security)

---

**Last Updated**: 2025-11-16
**Quick Help**: For immediate assistance, contact security@helix-app.com
