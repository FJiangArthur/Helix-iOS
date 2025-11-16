# GitHub Actions Workflows

This directory contains GitHub Actions workflow definitions for CI/CD automation.

## Workflows

### `ci.yml` - Main CI/CD Pipeline

**Status**: ![CI/CD Pipeline](https://github.com/YOUR-USERNAME/Helix-iOS/workflows/CI/CD%20Pipeline/badge.svg)

**Purpose**: Main continuous integration pipeline that runs on all pushes and pull requests.

**Triggers**:
- Push to `main` or `develop` branches
- Pull requests targeting `main` or `develop` branches

**Jobs**:
1. **Code Analysis & Linting** (`analyze`)
   - Platform: Ubuntu
   - Duration: ~5-10 minutes
   - Checks: Static analysis, formatting, import validation

2. **Unit Tests** (`test`)
   - Platform: Ubuntu
   - Duration: ~10-15 minutes
   - Checks: All tests, coverage threshold (60%+)

3. **Build iOS** (`build-ios`)
   - Platform: macOS
   - Duration: ~15-25 minutes
   - Checks: iOS build verification

4. **Build Android** (`build-android`)
   - Platform: Ubuntu
   - Duration: ~15-25 minutes
   - Checks: APK and App Bundle builds

5. **Security Scanning** (`security`)
   - Platform: Ubuntu
   - Duration: ~5-10 minutes
   - Checks: Vulnerabilities, secrets, security scorecard

6. **License Compliance** (`license-check`)
   - Platform: Ubuntu
   - Duration: ~3-5 minutes
   - Checks: Dependency licenses

7. **CI Success** (`ci-success`)
   - Platform: Ubuntu
   - Duration: <1 minute
   - Status: Final gate for branch protection

**Artifacts**:
- Coverage reports (30 days retention)
- iOS builds (7 days retention)
- Android APK (7 days retention)
- Android App Bundle (7 days retention)
- License reports (30 days retention)

**Dependencies**:
- Flutter 3.35.0
- Java 17 (for Android builds)
- Ubuntu latest / macOS latest

### `objective-c-xcode.yml` - Legacy Xcode Build

**Status**: ![Xcode Build](https://github.com/YOUR-USERNAME/Helix-iOS/workflows/Xcode%20-%20Build%20and%20Analyze/badge.svg)

**Purpose**: Legacy workflow for Xcode-specific builds. Maintained for compatibility.

**Note**: The main CI/CD pipeline (`ci.yml`) should be used for all quality gates. This workflow may be deprecated in favor of the comprehensive Flutter CI/CD pipeline.

## Adding Status Badges to README

Add these badges to your README.md to show build status:

```markdown
# Project Name

![CI/CD Pipeline](https://github.com/YOUR-USERNAME/Helix-iOS/workflows/CI/CD%20Pipeline/badge.svg)
![Code Coverage](https://img.shields.io/badge/coverage-60%25-yellow)

Your project description...
```

Replace `YOUR-USERNAME` with your GitHub username or organization name.

## Workflow Configuration

### Secrets Required

No secrets are required for basic CI/CD. However, for deployment you may need:

- `IOS_CERTIFICATE`: iOS signing certificate (for App Store deployment)
- `IOS_PROVISIONING_PROFILE`: iOS provisioning profile
- `ANDROID_KEYSTORE`: Android keystore file
- `ANDROID_KEYSTORE_PASSWORD`: Keystore password
- `ANDROID_KEY_ALIAS`: Key alias
- `ANDROID_KEY_PASSWORD`: Key password

### Variables

Set these in repository settings → Secrets and variables → Actions → Variables:

- `FLUTTER_VERSION`: Flutter version to use (default: 3.35.0)

## Modifying Workflows

When modifying workflows:

1. **Test locally first** using [act](https://github.com/nektos/act)
2. **Create a feature branch** for workflow changes
3. **Test on feature branch** before merging to main
4. **Update documentation** in this README and main docs
5. **Review caching strategies** to optimize build times

## Debugging Workflows

### View Logs
1. Go to Actions tab in GitHub
2. Click on the workflow run
3. Click on the specific job
4. Expand steps to view logs

### Download Artifacts
1. Go to completed workflow run
2. Scroll to "Artifacts" section
3. Download the artifact you need

### Re-run Failed Jobs
1. Go to failed workflow run
2. Click "Re-run jobs" → "Re-run failed jobs"

### Enable Debug Logging
Add these secrets for verbose logging:
- `ACTIONS_RUNNER_DEBUG`: `true`
- `ACTIONS_STEP_DEBUG`: `true`

## Best Practices

1. **Keep workflows fast**: Optimize caching, parallelize jobs
2. **Use matrix builds**: Test multiple versions/platforms
3. **Fail fast**: Use `fail-fast: true` in matrices when appropriate
4. **Cache dependencies**: Use actions/cache for pub, gradle
5. **Set timeouts**: Prevent hung jobs from wasting resources
6. **Use artifacts**: Share build outputs between jobs
7. **Monitor costs**: Be mindful of GitHub Actions minutes

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter CI/CD Guide](https://docs.flutter.dev/deployment/cd)
- [Actions Marketplace](https://github.com/marketplace?type=actions)
- [Workflow Syntax](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions)

## Support

For issues with workflows:
1. Check [CI/CD Pipeline Documentation](../../docs/CI_CD_PIPELINE.md)
2. Review workflow logs in GitHub Actions
3. Open an issue with workflow run link
4. Contact DevOps team
