# Branch Protection Rules

This document outlines the recommended branch protection rules for the Helix-iOS repository to ensure code quality and prevent breaking changes.

## Table of Contents
- [Overview](#overview)
- [Protected Branches](#protected-branches)
- [Protection Rules](#protection-rules)
- [GitHub Settings Configuration](#github-settings-configuration)
- [Enforcement](#enforcement)

## Overview

Branch protection rules enforce quality gates and collaboration standards. These rules ensure that all code merged into critical branches meets quality standards and has been properly reviewed.

## Protected Branches

The following branches should be protected:

### 1. `main` (Primary Production Branch)
- **Purpose**: Production-ready code
- **Strictest protection level**
- **Direct pushes**: Disabled
- **Deletions**: Disabled

### 2. `develop` (Development Integration Branch)
- **Purpose**: Integration branch for features
- **High protection level**
- **Direct pushes**: Disabled for most users
- **Deletions**: Disabled

### 3. `release/*` (Release Branches)
- **Purpose**: Release preparation
- **High protection level**
- **Direct pushes**: Limited to release managers
- **Deletions**: Disabled

## Protection Rules

### Required Status Checks

All protected branches must pass the following CI checks before merging:

#### ✅ Required Checks (Must Pass)
1. **Code Analysis & Linting**
   - `analyze` job must pass
   - Ensures code meets static analysis standards
   - Verifies proper formatting

2. **Unit Tests**
   - `test` job must pass
   - All unit tests must succeed
   - Coverage threshold must be met (60%+)

3. **Build Verification - iOS**
   - `build-ios` job must pass
   - Ensures iOS build is not broken

4. **Build Verification - Android**
   - `build-android` job must pass
   - Ensures Android build is not broken

5. **Security Scanning**
   - `security` job must pass
   - No critical vulnerabilities detected
   - No secrets in code

6. **License Compliance**
   - `license-check` job must pass
   - All dependencies have acceptable licenses

#### 📋 Configuration
```yaml
Required status checks:
  ☑ Require branches to be up to date before merging
  ☑ CI/CD Pipeline / analyze
  ☑ CI/CD Pipeline / test
  ☑ CI/CD Pipeline / build-ios
  ☑ CI/CD Pipeline / build-android
  ☑ CI/CD Pipeline / security
  ☑ CI/CD Pipeline / license-check
```

### Pull Request Requirements

#### For `main` branch:
- ✅ Require pull request before merging
- ✅ Require at least **2 approvals**
- ✅ Dismiss stale pull request approvals when new commits are pushed
- ✅ Require review from Code Owners (if CODEOWNERS file exists)
- ✅ Require approval from someone other than the last pusher
- ✅ Require conversation resolution before merging

#### For `develop` branch:
- ✅ Require pull request before merging
- ✅ Require at least **1 approval**
- ✅ Dismiss stale pull request approvals when new commits are pushed
- ✅ Require conversation resolution before merging

### Additional Restrictions

#### 1. **Restrict Force Pushes**
- ❌ Force pushes are **not allowed** on `main`
- ❌ Force pushes are **not allowed** on `develop`
- ❌ Force pushes are **not allowed** on `release/*`

#### 2. **Restrict Deletions**
- ❌ Branch deletions are **not allowed** for protected branches

#### 3. **Require Linear History**
- ✅ Enabled for `main` (enforces rebase or squash merge)
- ⚠️ Optional for `develop`

#### 4. **Require Signed Commits**
- ✅ Recommended for enhanced security
- 🔐 All commits must be signed with GPG/SSH key

#### 5. **Include Administrators**
- ✅ Apply rules to administrators
- Ensures everyone follows the same process

## GitHub Settings Configuration

### Step-by-Step Setup

1. **Navigate to Repository Settings**
   - Go to your repository on GitHub
   - Click on "Settings" tab
   - Select "Branches" from the left sidebar

2. **Add Branch Protection Rule for `main`**
   ```
   Branch name pattern: main

   [✓] Require a pull request before merging
       [✓] Require approvals: 2
       [✓] Dismiss stale pull request approvals when new commits are pushed
       [✓] Require review from Code Owners
       [✓] Require approval of the most recent reviewable push

   [✓] Require status checks to pass before merging
       [✓] Require branches to be up to date before merging
       Status checks that are required:
         - CI/CD Pipeline / analyze
         - CI/CD Pipeline / test
         - CI/CD Pipeline / build-ios
         - CI/CD Pipeline / build-android
         - CI/CD Pipeline / security
         - CI/CD Pipeline / license-check

   [✓] Require conversation resolution before merging
   [✓] Require signed commits
   [✓] Require linear history
   [✓] Do not allow bypassing the above settings
   [✓] Restrict who can push to matching branches
       (Optional: Specify users/teams who can push)

   Rules applied to everyone including administrators:
   [✓] Include administrators
   ```

3. **Add Branch Protection Rule for `develop`**
   ```
   Branch name pattern: develop

   [✓] Require a pull request before merging
       [✓] Require approvals: 1
       [✓] Dismiss stale pull request approvals when new commits are pushed

   [✓] Require status checks to pass before merging
       [✓] Require branches to be up to date before merging
       Status checks that are required:
         - CI/CD Pipeline / analyze
         - CI/CD Pipeline / test
         - CI/CD Pipeline / build-ios
         - CI/CD Pipeline / build-android
         - CI/CD Pipeline / security

   [✓] Require conversation resolution before merging
   [✓] Do not allow bypassing the above settings

   Rules applied to everyone including administrators:
   [✓] Include administrators
   ```

4. **Add Branch Protection Rule for `release/*`**
   ```
   Branch name pattern: release/*

   [✓] Require a pull request before merging
       [✓] Require approvals: 2

   [✓] Require status checks to pass before merging
       Status checks that are required:
         - CI/CD Pipeline / analyze
         - CI/CD Pipeline / test
         - CI/CD Pipeline / build-ios
         - CI/CD Pipeline / build-android
         - CI/CD Pipeline / security

   [✓] Restrict who can push to matching branches
       (Specify release managers only)
   ```

## Enforcement

### For Developers

1. **Create Feature Branch**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature-name
   ```

2. **Make Changes and Commit**
   ```bash
   # Make changes
   git add .
   git commit -m "feat(scope): description"
   # Pre-commit hooks will run automatically
   ```

3. **Push and Create PR**
   ```bash
   git push origin feature/your-feature-name
   # Create PR on GitHub targeting 'develop'
   ```

4. **Address Review Comments**
   - Make requested changes
   - Push new commits
   - Request re-review

5. **Merge**
   - Once approved and all checks pass
   - Merge using GitHub UI (squash or rebase)

### For Reviewers

1. **Code Review Checklist**
   - ✅ Code follows project conventions
   - ✅ Changes are well-tested
   - ✅ Documentation is updated
   - ✅ No security concerns
   - ✅ Performance is acceptable
   - ✅ All CI checks pass

2. **Approval Process**
   - Review code thoroughly
   - Request changes if needed
   - Approve when satisfied
   - Ensure conversations are resolved

### Emergency Procedures

In case of critical production issues:

1. **Contact Repository Administrator**
   - Explain the emergency
   - Get temporary bypass permission if absolutely necessary

2. **Create Hotfix Branch**
   ```bash
   git checkout main
   git checkout -b hotfix/critical-issue
   ```

3. **Fix, Test, and PR**
   - Make minimal changes
   - Ensure tests pass
   - Get expedited review
   - Merge to main and backport to develop

4. **Post-Incident**
   - Document the incident
   - Review why it happened
   - Update processes to prevent recurrence

## Monitoring and Compliance

### Regular Audits
- **Monthly**: Review branch protection settings
- **Quarterly**: Audit bypass instances
- **Annual**: Review and update policies

### Metrics to Track
- PR merge time
- Number of failed CI checks
- Number of bypass requests
- Code review participation

### Tools
- GitHub Insights for PR metrics
- CI/CD dashboard for build health
- Security scanning reports

## Additional Resources

- [GitHub Branch Protection Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Code Review Best Practices](https://google.github.io/eng-practices/review/)

## Questions or Issues?

If you have questions about these policies or need assistance:
1. Check the [CI/CD Pipeline Documentation](./CI_CD_PIPELINE.md)
2. Contact the development team lead
3. Open a discussion in the repository

---

**Last Updated**: 2025-11-16
**Version**: 1.0.0
**Owner**: DevOps Team
