# CI/CD Setup Guide

This guide explains how to set up automated builds for iOS, Android, and macOS using GitHub Actions.

## 📋 Table of Contents

1. [Overview](#overview)
2. [Workflows](#workflows)
3. [Initial Setup](#initial-setup)
4. [Platform-Specific Configuration](#platform-specific-configuration)
5. [GitHub Secrets Configuration](#github-secrets-configuration)
6. [Testing the Workflows](#testing-the-workflows)
7. [Troubleshooting](#troubleshooting)

---

## Overview

The repository includes four GitHub Actions workflows:

- **`cross-platform-ci.yml`** - Master workflow that orchestrates all platform builds
- **`ios-build.yml`** - iOS-specific build workflow
- **`android-build.yml`** - Android-specific build workflow
- **`macos-build.yml`** - macOS-specific build workflow

### Workflow Triggers

All workflows trigger on:
- Push to `main`, `develop`, or `claude/**` branches
- Pull requests to `main` or `develop`
- Manual dispatch via GitHub UI

---

## Workflows

### Cross-Platform CI (Master Workflow)

**File:** `.github/workflows/cross-platform-ci.yml`

**Jobs:**
1. **Code Quality** - Linting and formatting checks
2. **Test** - Unit tests with coverage reporting
3. **Build iOS** - Calls iOS workflow
4. **Build Android** - Calls Android workflow
5. **Build macOS** - Calls macOS workflow
6. **Build Summary** - Aggregates results

**Features:**
- Runs quality checks before any builds
- Executes platform builds in parallel
- Uploads test coverage to Codecov
- Provides unified build status

### iOS Build Workflow

**File:** `.github/workflows/ios-build.yml`

**Capabilities:**
- ✅ Debug builds (all branches)
- ✅ Release builds without signing (main/develop)
- 🔒 Signed release builds (commented, requires setup)
- 🔒 TestFlight uploads (commented, requires setup)

**Artifacts:**
- iOS build outputs
- Test results

### Android Build Workflow

**File:** `.github/workflows/android-build.yml`

**Capabilities:**
- ✅ Debug APK builds (all branches)
- ✅ Unsigned release APK/AAB (main/develop)
- 🔒 Signed release builds (commented, requires setup)
- 🔒 Play Store uploads (commented, requires setup)

**Artifacts:**
- APK files
- AAB (App Bundle) files
- Test results

### macOS Build Workflow

**File:** `.github/workflows/macos-build.yml`

**Capabilities:**
- ✅ Debug builds (all branches)
- ✅ Release builds (main/develop)
- 🔒 Signed builds (commented, requires setup)
- 🔒 DMG creation (commented, requires setup)
- 🔒 Notarization (commented, requires setup)

**Artifacts:**
- macOS .app bundles
- DMG installers (when created)
- Test results

---

## Initial Setup

### 1. No Configuration Required for Basic Builds

The workflows are ready to run immediately for:
- Debug builds on all platforms
- Unsigned release builds
- Automated testing
- Code quality checks

Simply push to your repository and the workflows will run!

### 2. Enable macOS Desktop Support (Local Development)

```bash
flutter config --enable-macos-desktop
```

### 3. Verify Platform Support

```bash
# Check Flutter setup
flutter doctor -v

# Test builds locally before pushing
flutter build ios --debug --no-codesign
flutter build apk --debug
flutter build macos --debug
```

---

## Platform-Specific Configuration

### iOS Configuration

#### For Unsigned Builds (Current Setup)
✅ **No additional configuration needed!**

#### For Signed Builds & App Store Distribution

1. **Export Certificates**

```bash
# From Keychain Access, export your distribution certificate as .p12
# Convert to base64
base64 -i Certificates.p12 | pbcopy
```

2. **Export Provisioning Profile**

```bash
# From ~/Library/MobileDevice/Provisioning Profiles/
base64 -i YourProfile.mobileprovision | pbcopy
```

3. **Create ExportOptions.plist**

Create `ios/ExportOptions.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>com.evenrealities.flutter_helix</key>
        <string>YOUR_PROVISIONING_PROFILE_NAME</string>
    </dict>
</dict>
</plist>
```

4. **Get App Store Connect API Keys**

- Log in to [App Store Connect](https://appstoreconnect.apple.com)
- Go to Users and Access > Keys
- Create a new API Key with App Manager role
- Download the .p8 file

5. **Uncomment iOS signing steps in** `.github/workflows/ios-build.yml`

---

### Android Configuration

#### For Unsigned Builds (Current Setup)
✅ **No additional configuration needed!**

#### For Signed Builds & Play Store Distribution

1. **Create Release Keystore**

```bash
cd android/app
keytool -genkey -v -keystore release-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias release
```

**⚠️ IMPORTANT:** Store the keystore file securely and **never commit it to git!**

2. **Convert Keystore to Base64**

```bash
base64 -i android/app/release-keystore.jks | pbcopy
```

3. **Update android/app/build.gradle**

Add before `android {` block:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

Add inside `android { buildTypes {` block:

```gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}
release {
    signingConfig signingConfigs.release
    // ... existing release config
}
```

4. **Create Play Store Service Account**

- Go to [Google Cloud Console](https://console.cloud.google.com)
- Create a service account
- Grant "Release Manager" role in Play Console
- Download JSON key

5. **Uncomment Android signing steps in** `.github/workflows/android-build.yml`

---

### macOS Configuration

#### For Unsigned Builds (Current Setup)
✅ **No additional configuration needed!**

#### For Signed Builds & Notarization

1. **Export Certificates (same as iOS)**

```bash
base64 -i Certificates.p12 | pbcopy
```

2. **Get Signing Identity**

```bash
security find-identity -v -p codesigning
# Copy the identity string (e.g., "Developer ID Application: Your Name (TEAM_ID)")
```

3. **Create App-Specific Password**

- Go to [appleid.apple.com](https://appleid.apple.com)
- Sign in > Security > App-Specific Passwords
- Generate new password for "Helix Notarization"

4. **Uncomment macOS signing steps in** `.github/workflows/macos-build.yml`

---

## GitHub Secrets Configuration

Navigate to: **Repository Settings → Secrets and variables → Actions → New repository secret**

### Required for iOS Signing

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `IOS_P12_BASE64` | Base64-encoded .p12 certificate | `base64 -i cert.p12 \| pbcopy` |
| `IOS_P12_PASSWORD` | Password for .p12 file | Password you set when exporting |
| `IOS_PROVISION_PROFILE_BASE64` | Base64-encoded provisioning profile | `base64 -i profile.mobileprovision \| pbcopy` |
| `APPSTORE_ISSUER_ID` | App Store Connect Issuer ID | App Store Connect → Users & Access → Keys |
| `APPSTORE_API_KEY_ID` | App Store Connect API Key ID | From API key creation |
| `APPSTORE_API_PRIVATE_KEY` | App Store Connect .p8 private key | Content of downloaded .p8 file |

### Required for Android Signing

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded keystore file | `base64 -i release-keystore.jks \| pbcopy` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password | Password you set when creating keystore |
| `ANDROID_KEY_PASSWORD` | Key password | Password you set for the key alias |
| `ANDROID_KEY_ALIAS` | Key alias name | Alias you used (e.g., "release") |
| `PLAY_STORE_SERVICE_ACCOUNT_JSON` | Play Store service account JSON | Content of downloaded JSON file |

### Required for macOS Signing

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `MACOS_P12_BASE64` | Base64-encoded .p12 certificate | `base64 -i cert.p12 \| pbcopy` |
| `MACOS_P12_PASSWORD` | Password for .p12 file | Password you set when exporting |
| `MACOS_SIGNING_IDENTITY` | Signing identity string | `security find-identity -v -p codesigning` |
| `APPLE_ID` | Apple ID email | Your Apple developer email |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password | Generated at appleid.apple.com |
| `APPLE_TEAM_ID` | Apple Developer Team ID | From developer.apple.com |

### Optional for Code Coverage

| Secret Name | Description | How to Get |
|-------------|-------------|------------|
| `CODECOV_TOKEN` | Codecov upload token | codecov.io after linking repo |

---

## Testing the Workflows

### 1. Test Without Signing (Current State)

```bash
# Push any branch with "claude/" prefix
git checkout -b claude/test-ci
git push -u origin claude/test-ci
```

All builds will run but won't be signed.

### 2. Test Locally Before CI

```bash
# iOS
flutter build ios --debug --no-codesign

# Android
flutter build apk --debug

# macOS
flutter build macos --debug

# Run tests
flutter test

# Run analysis
flutter analyze

# Check formatting
dart format --set-exit-if-changed .
```

### 3. Monitor Workflow Execution

1. Go to **Actions** tab in GitHub
2. Click on the running workflow
3. View real-time logs for each job
4. Download artifacts after completion

### 4. Validate Artifacts

```bash
# Download artifacts from GitHub Actions
# iOS: Check .app bundle
# Android: Install APK on device/emulator
# macOS: Open .app bundle
```

---

## Troubleshooting

### Common Issues

#### ❌ "Flutter not found"
**Solution:** Workflows use `subosito/flutter-action@v2` which auto-installs Flutter.

#### ❌ "CocoaPods install failed" (iOS)
**Solution:** Ensure `ios/Podfile.lock` is committed. Run `cd ios && pod install` locally first.

#### ❌ "Gradle build failed" (Android)
**Solution:** Check Java version (workflow uses Java 17). Verify `android/gradle.properties`.

#### ❌ "Code signing failed"
**Solution:**
- Verify secrets are correctly set
- Check certificate validity
- Ensure provisioning profile matches bundle ID

#### ❌ "Tests failing in CI but pass locally"
**Solution:**
- Check for environment-specific dependencies
- Review test output in workflow logs
- Ensure all test files are committed

#### ❌ "Workflow timeout"
**Solution:**
- Default timeout is 45-60 minutes
- Check for hanging tests
- Review dependency installation steps

### Debug Mode

Add this step to any workflow for debugging:

```yaml
- name: Debug Information
  run: |
    echo "Flutter version:"
    flutter --version
    echo "Environment:"
    env
    echo "Working directory contents:"
    ls -la
```

### Getting Help

1. Check workflow logs in GitHub Actions tab
2. Review this documentation
3. Check Flutter's CI/CD guides: https://docs.flutter.dev/deployment/cd
4. Search GitHub Actions marketplace for updated actions

---

## Next Steps

### Phase 1: Basic CI ✅ (Current)
- Automated builds on push
- Test execution
- Code quality checks
- Build artifact uploads

### Phase 2: Code Signing 🔒 (Setup Required)
- Configure signing secrets
- Uncomment signing steps
- Test signed builds

### Phase 3: Store Distribution 🚀 (Future)
- Automated TestFlight uploads
- Automated Play Store uploads
- Beta testing workflows
- Release automation

### Phase 4: Advanced Features 🎯 (Future)
- Performance monitoring
- Automated screenshot testing
- Version bump automation
- Changelog generation
- Release notes automation

---

## Workflow Status Badges

Add these to your README.md:

```markdown
![Cross-Platform CI](https://github.com/YOUR_USERNAME/Helix-iOS/workflows/Cross-Platform%20CI/badge.svg)
![iOS Build](https://github.com/YOUR_USERNAME/Helix-iOS/workflows/iOS%20Build/badge.svg)
![Android Build](https://github.com/YOUR_USERNAME/Helix-iOS/workflows/Android%20Build/badge.svg)
![macOS Build](https://github.com/YOUR_USERNAME/Helix-iOS/workflows/macOS%20Build/badge.svg)
```

---

## Summary

Your repository now has:
- ✅ Automated builds for iOS, Android, and macOS
- ✅ Continuous testing and code quality checks
- ✅ Artifact generation and storage
- 🔒 Code signing support (ready to enable)
- 🚀 Store deployment support (ready to configure)

**Current Status:** All workflows run successfully with unsigned builds. Configure secrets to enable signed builds and store distribution.
