# Security Policy

## Supported Versions

We release patches for security vulnerabilities. The following table shows which versions are currently being supported with security updates:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of Helix iOS application seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### Where to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to:
- **Security Team Email**: security@helix-app.com

If you prefer, you may also use GitHub's private vulnerability reporting feature:
1. Navigate to the repository
2. Click on "Security" tab
3. Click "Report a vulnerability"

### What to Include

Please include the following information in your report:

- **Type of vulnerability** (e.g., SQL injection, cross-site scripting, authentication bypass)
- **Full paths of source file(s)** related to the vulnerability
- **Location of the affected source code** (tag/branch/commit or direct URL)
- **Step-by-step instructions** to reproduce the issue
- **Proof-of-concept or exploit code** (if possible)
- **Impact of the vulnerability** and how an attacker might exploit it
- **Any potential mitigations** you've identified

### Our Commitment

- We will acknowledge receipt of your vulnerability report within **3 business days**
- We will send you a more detailed response within **7 business days** indicating the next steps
- We will keep you informed about our progress throughout the remediation process
- We will notify you when the vulnerability has been fixed

### Security Response Timeline

1. **Day 0**: Vulnerability reported
2. **Day 1-3**: Initial acknowledgment sent to reporter
3. **Day 1-7**: Vulnerability assessment and validation
4. **Day 7-14**: Fix development and testing
5. **Day 14-30**: Security advisory publication and patch release
6. **Day 30+**: Public disclosure (coordinated with reporter)

### Disclosure Policy

- We follow a **coordinated disclosure** process
- We request that you give us a reasonable amount of time (90 days) to address the issue before any public disclosure
- We will publicly acknowledge your responsible disclosure, unless you prefer to remain anonymous

## Security Best Practices for Contributors

### Code Review Requirements

All code changes must:
- Pass automated security scans (SAST, dependency checks)
- Be reviewed by at least one maintainer
- Follow secure coding guidelines documented in `/docs/SECURITY_BEST_PRACTICES.md`

### Dependency Management

- Keep dependencies up to date
- Review dependency security advisories regularly
- Use `dart pub audit` to check for vulnerabilities
- Prefer well-maintained packages with active security practices

### Authentication & Authorization

- Never hardcode credentials, API keys, or secrets
- Use environment variables or secure secret management
- Implement proper session management
- Follow the principle of least privilege

### Data Protection

- Encrypt sensitive data in transit (TLS 1.2+)
- Encrypt sensitive data at rest
- Implement proper input validation and sanitization
- Follow GDPR and data privacy regulations (see `/docs/GDPR_COMPLIANCE_GUIDE.md`)

### Mobile-Specific Security

- Use platform-specific secure storage (Keychain on iOS, KeyStore on Android)
- Implement certificate pinning for sensitive API calls
- Protect against reverse engineering with code obfuscation
- Implement jailbreak/root detection for sensitive features

## Security Tools & Automation

We use the following automated security tools:

### Continuous Security Scanning

- **Dependency Scanning**: `dart pub audit` for vulnerable dependencies
- **Secret Scanning**: TruffleHog for detecting hardcoded secrets
- **SAST**: Static analysis via `flutter analyze` with security linters
- **Supply Chain Security**: OSSF Scorecard for dependency health
- **License Compliance**: Automated license checking

### Pre-commit Hooks

Install pre-commit hooks to catch security issues early:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install
```

### Local Security Scanning

Run security checks locally before committing:

```bash
# Run all security checks
make security-check

# Check for secrets
make security-secrets

# Audit dependencies
make security-audit

# Full security scan
make security-full
```

## Security Contacts

- **Security Team**: security@helix-app.com
- **Security Incident Response**: incident-response@helix-app.com
- **General Security Questions**: security-questions@helix-app.com

## Security Hall of Fame

We maintain a hall of fame to recognize security researchers who have responsibly disclosed vulnerabilities:

<!-- Security researchers will be listed here after verified disclosures -->

## Additional Resources

- [OWASP Mobile Security Project](https://owasp.org/www-project-mobile-security/)
- [CWE Mobile Application Security Weaknesses](https://cwe.mitre.org/data/definitions/919.html)
- [Flutter Security Best Practices](https://docs.flutter.dev/security)
- [Dart Security Guidelines](https://dart.dev/guides/security)

## Security Checklist for Releases

Before each release, ensure:

- [ ] All dependencies are up to date and scanned for vulnerabilities
- [ ] Security scanning has been run and all high/critical issues resolved
- [ ] No secrets or credentials in the codebase
- [ ] Security-sensitive features have been penetration tested
- [ ] Privacy policy and data handling procedures are current
- [ ] Third-party SDK security has been reviewed
- [ ] Code obfuscation is enabled for production builds
- [ ] Certificate pinning is configured for production APIs
- [ ] Security advisories have been reviewed and addressed

## Version History

| Version | Date       | Changes                    |
|---------|------------|----------------------------|
| 1.0     | 2025-11-16 | Initial security policy    |

---

**Last Updated**: 2025-11-16
**Policy Version**: 1.0
