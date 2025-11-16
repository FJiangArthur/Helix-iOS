# TestFlight Deployment SOP - Helix iOS App

**Last Updated**: 2025-11-15  
**Version**: 1.0  
**Document Owner**: Development Team

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Pre-Deployment Checklist](#pre-deployment-checklist)
4. [Deployment Process](#deployment-process)
5. [Post-Deployment Verification](#post-deployment-verification)
6. [Troubleshooting](#troubleshooting)
7. [Rollback Procedure](#rollback-procedure)
8. [Beta Testing Guidelines](#beta-testing-guidelines)

---

## Overview

This Standard Operating Procedure (SOP) outlines the complete process for deploying the Helix iOS app to TestFlight for beta testing.

### Purpose
- Distribute beta builds to internal and external testers
- Gather feedback before App Store release
- Validate features in real-world conditions
- Identify bugs on diverse devices

### Scope
- Internal testing (up to 100 users)
- External testing (up to 10,000 users)
- Crash reporting and analytics
- Iterative release cycles

### Roles & Responsibilities

| Role | Responsibilities |
|------|------------------|
| **Developer** | Build and upload to TestFlight |
| **QA Lead** | Run pre-deployment tests, verify builds |
| **Project Manager** | Approve releases, manage tester groups |
| **Beta Testers** | Test features, report bugs |

---

## Prerequisites

### 1. Apple Developer Account

**Required**:
- Active Apple Developer Program membership ($99/year)
- Admin or App Manager role
- Two-factor authentication enabled

**Setup**:
1. Visit https://developer.apple.com
2. Sign in with Apple ID
3. Enroll in Apple Developer Program (if not already)
4. Verify account is active

### 2. App Store Connect Access

**Required**:
- Access to App Store Connect (https://appstoreconnect.apple.com)
- App created in App Store Connect
- Bundle ID registered

**Verify Access**:
1. Log into App Store Connect
2. Navigate to "My Apps"
3. Confirm "Helix" app exists
4. Note Bundle ID: `com.helix.ios` (or your custom ID)

### 3. Development Environment

**Software**:
- Xcode 15.0+ (latest stable)
- Flutter 3.24.0+
- fastlane (optional but recommended)

**Certificates & Profiles**:
- iOS Distribution Certificate
- App Store Provisioning Profile
- Push Notification Certificate (if using)

**Install fastlane** (recommended):
```bash
sudo gem install fastlane
cd ios
fastlane init
```

### 4. Code Signing Configuration

**Automatic Signing** (Recommended):
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Go to Signing & Capabilities
4. Enable "Automatically manage signing"
5. Select your Team
6. Xcode will handle certificates and profiles

**Manual Signing** (Advanced):
1. Download certificates from developer.apple.com
2. Install in Keychain
3. Download provisioning profiles
4. Configure in Xcode manually

---

## Pre-Deployment Checklist

### ☐ Code Readiness

- [ ] All critical bugs fixed
- [ ] Code reviewed and approved
- [ ] Merged to `main` or `release` branch
- [ ] No compilation errors or warnings
- [ ] `flutter analyze` passes with no critical issues

### ☐ Testing Complete

- [ ] Local testing completed (see [LOCAL_TESTING_PLAN.md](./LOCAL_TESTING_PLAN.md))
- [ ] All critical test cases passed
- [ ] Performance benchmarks met
- [ ] Tested on ≥3 different device models
- [ ] Tested on iOS 14.0+ (minimum supported version)

### ☐ Version & Build Number

- [ ] Version number incremented in `pubspec.yaml`
  ```yaml
  version: 1.0.1+2  # format: VERSION+BUILD
  ```
- [ ] Version follows semantic versioning (MAJOR.MINOR.PATCH)
- [ ] Build number auto-increments or manually set

### ☐ Configuration

- [ ] API endpoints set to production (or staging)
- [ ] Debug flags disabled
- [ ] Logging level appropriate for release
- [ ] API keys valid and not expired
- [ ] `llm_config.local.json` not included in build (gitignored)

### ☐ Assets & Resources

- [ ] App icon set (all sizes)
- [ ] Launch screen configured
- [ ] Splash screen optimized
- [ ] All images optimized (compressed)
- [ ] Localization files updated (if multi-language)

### ☐ App Store Connect Setup

- [ ] App listing information complete
- [ ] Privacy policy URL provided
- [ ] Support URL provided
- [ ] App screenshots prepared (required for public release)
- [ ] Beta App Description written

### ☐ Legal & Compliance

- [ ] Terms of Service reviewed
- [ ] Privacy Policy updated
- [ ] Third-party licenses acknowledged
- [ ] Export compliance reviewed (if applicable)

---

## Deployment Process

### Method 1: Using Xcode (Standard)

#### Step 1: Prepare Build

```bash
# Navigate to project root
cd /path/to/Helix-iOS

# Ensure on correct branch
git checkout main
git pull origin main

# Clean previous builds
flutter clean
flutter pub get

# Build iOS release
flutter build ios --release
```

#### Step 2: Open in Xcode

```bash
# Open workspace (not .xcodeproj!)
open ios/Runner.xcworkspace
```

#### Step 3: Configure Release Settings

1. **Select Target**:
   - Click "Runner" in project navigator
   - Select "Runner" target

2. **Verify Version**:
   - Go to "General" tab
   - Check Version: `1.0.1` (matches pubspec.yaml)
   - Check Build: `2` (incremented from last build)

3. **Select Destination**:
   - Top toolbar: Select "Any iOS Device (arm64)"
   - Do NOT select a simulator

4. **Verify Signing**:
   - Go to "Signing & Capabilities"
   - Ensure "Automatically manage signing" is checked
   - Team: Your Apple Developer Team
   - Provisioning Profile: Should say "Xcode Managed Profile"

#### Step 4: Archive Build

1. **Create Archive**:
   - Menu: Product → Archive
   - Wait for build to complete (5-10 minutes)
   - If successful, Organizer window opens

2. **Verify Archive**:
   - Archives tab should show your build
   - Check version and build number are correct
   - Verify architecture includes arm64

#### Step 5: Upload to App Store Connect

1. **Distribute App**:
   - Click "Distribute App" button
   - Select "App Store Connect"
   - Click "Next"

2. **Upload Options**:
   - Upload symbols: ✅ Checked (for crash reports)
   - Manage Version and Build Number: ✅ Checked
   - Click "Next"

3. **Re-sign** (if needed):
   - Select "Automatically manage signing"
   - Click "Next"

4. **Review**:
   - Review all settings
   - Click "Upload"

5. **Wait for Processing**:
   - Upload takes 5-15 minutes
   - You'll receive email when processing complete
   - Can close Xcode during upload

#### Step 6: Monitor Processing

1. **Check Email**:
   - Subject: "App Store Connect: Build processed"
   - Check for any warnings or errors

2. **Check App Store Connect**:
   - Login to https://appstoreconnect.apple.com
   - Go to My Apps → Helix
   - Click "TestFlight" tab
   - Check "iOS" section
   - Your build should appear (may take 5-30 minutes)

---

### Method 2: Using fastlane (Advanced/Automated)

#### Step 1: Setup fastlane

```bash
cd ios

# Initialize fastlane (if not already done)
fastlane init

# Select option: 4 (Manual setup)
```

#### Step 2: Configure Fastfile

Edit `ios/fastlane/Fastfile`:

```ruby
default_platform(:ios)

platform :ios do
  desc "Push a new beta build to TestFlight"
  lane :beta do
    # Increment build number
    increment_build_number(xcodeproj: "Runner.xcodeproj")
    
    # Build app
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      export_method: "app-store",
      configuration: "Release"
    )
    
    # Upload to TestFlight
    upload_to_testflight(
      skip_waiting_for_build_processing: true,
      changelog: "Bug fixes and performance improvements"
    )
  end
end
```

#### Step 3: Deploy

```bash
# From ios/ directory
fastlane beta

# Or with custom message
fastlane beta --env beta changelog:"New AI features added"
```

#### Step 4: Authenticate

First time only:
```bash
# Login to App Store Connect
fastlane spaceauth -u your.email@example.com

# Store credentials
export FASTLANE_SESSION='<token from previous command>'
```

---

### Method 3: Using GitHub Actions (CI/CD)

#### Step 1: Setup Secrets

In GitHub repository settings, add secrets:
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY`
- `MATCH_PASSWORD` (for certificate management)

#### Step 2: Create Workflow

Create `.github/workflows/testflight.yml`:

```yaml
name: Deploy to TestFlight

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  deploy:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.24.0'
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Build iOS
      run: flutter build ios --release --no-codesign
    
    - name: Deploy to TestFlight
      run: |
        cd ios
        fastlane beta
      env:
        APP_STORE_CONNECT_API_KEY_ID: ${{ secrets.APP_STORE_CONNECT_API_KEY_ID }}
        APP_STORE_CONNECT_ISSUER_ID: ${{ secrets.APP_STORE_CONNECT_ISSUER_ID }}
        APP_STORE_CONNECT_API_KEY: ${{ secrets.APP_STORE_CONNECT_API_KEY }}
```

#### Step 3: Trigger Deployment

```bash
# Create and push tag
git tag v1.0.1
git push origin v1.0.1

# GitHub Actions will automatically deploy
```

---

## Post-Deployment Verification

### 1. Verify Build in App Store Connect

**Timeline**: Within 30 minutes of upload

1. Login to App Store Connect
2. Go to My Apps → Helix → TestFlight
3. Under "iOS" section, verify:
   - Build number matches uploaded version
   - Status is "Ready to Submit" or "Testing"
   - No warnings or errors

### 2. Configure Build

1. **Add Beta App Description**:
   - Click on build number
   - Add "What to Test" notes for testers
   - Example:
     ```
     ## What's New in This Build
     - Fixed audio recording state management
     - Added LLM API integration
     - Improved transcription accuracy
     
     ## Known Issues
     - First recording may have 4-5 second delay in debug mode
     
     ## What to Test
     - Try recording multiple audio clips
     - Test AI analysis features
     - Report any crashes or UI glitches
     ```

2. **Add Build Information** (optional):
   - Version: Auto-filled
   - Build: Auto-filled
   - Export Compliance: Answer questions

### 3. Add Testers

#### Internal Testing (Immediate Access)

1. Go to "TestFlight" tab
2. Click "Internal Testing" section
3. Click "+" to add internal group
4. Select testers from your App Store Connect team
5. Testers receive email invitation immediately

#### External Testing (Requires Review)

1. Go to "TestFlight" tab
2. Click "External Testing" section
3. Click "+" to add external group
4. Name the group (e.g., "Beta Testers Wave 1")
5. Add testers by email
6. Submit for Beta App Review (usually 24-48 hours)

**Note**: External testing requires first build to pass beta review

### 4. Verify Installation

**As a Tester**:

1. **Receive Invitation**:
   - Check email for TestFlight invitation
   - Subject: "You're invited to test Helix"

2. **Install TestFlight App**:
   - Download from App Store if not installed
   - Open invitation link

3. **Accept Invitation**:
   - Open TestFlight app
   - Tap "Accept" on Helix invitation
   - Tap "Install"

4. **Launch App**:
   - Open Helix from TestFlight
   - Verify version number in settings
   - Complete initial setup

### 5. Monitor Feedback

**Crash Reports**:
- App Store Connect → TestFlight → Builds → [Your Build] → Crashes
- Review crash logs and symbolicate

**Beta Feedback**:
- TestFlight → Feedback
- Testers can submit screenshots and comments

**Analytics** (if configured):
- Monitor usage metrics
- Track feature adoption
- Identify problem areas

---

## Troubleshooting

### Issue: Archive Fails

**Symptoms**: Build fails during archiving in Xcode

**Possible Causes**:
- Code signing issues
- Missing dependencies
- Compilation errors

**Solutions**:
1. Clean build folder: Product → Clean Build Folder
2. Check code signing:
   - Verify certificate is valid (not expired)
   - Check provisioning profile is correct
3. Resolve compilation errors
4. Update CocoaPods: `cd ios && pod update`

### Issue: Upload to App Store Connect Fails

**Symptoms**: Upload button succeeds but build never appears

**Possible Causes**:
- Invalid bundle identifier
- Missing app icon
- Invalid version/build number
- Code signing mismatch

**Solutions**:
1. Check email for rejection reasons
2. Verify bundle ID matches App Store Connect
3. Ensure all icon sizes included
4. Increment build number if duplicate
5. Check Xcode Organizer → Archives → Show in Finder → Right-click → Show Package Contents → Products → Applications → Validate

### Issue: Build Stuck in "Processing"

**Symptoms**: Build uploaded but stuck processing for >2 hours

**Possible Causes**:
- Apple server issues
- Large binary size
- Invalid binary

**Solutions**:
1. Wait 24 hours (sometimes takes this long)
2. Check Apple System Status: https://www.apple.com/support/systemstatus/
3. Try uploading again with new build number
4. Contact Apple Developer Support

### Issue: Testers Can't Install

**Symptoms**: Testers receive invitation but can't install

**Possible Causes**:
- Incompatible iOS version
- UDID not registered (external testing)
- TestFlight app not installed
- Build expired (90 days)

**Solutions**:
1. Verify tester's iOS version ≥ your minimum (14.0)
2. For external testing, ensure build passed beta review
3. Have tester install TestFlight app
4. Upload new build if expired

### Issue: App Crashes on Launch

**Symptoms**: App installed but crashes immediately

**Possible Causes**:
- Missing API configuration
- Code signing mismatch
- Incompatible device

**Solutions**:
1. Check crash logs in App Store Connect
2. Verify `llm_config.local.json` template included
3. Test on same device model locally
4. Review symbolicated crash report

---

## Rollback Procedure

If critical bug discovered post-deployment:

### Step 1: Stop Distribution

1. Login to App Store Connect
2. Go to TestFlight → Builds
3. Select problematic build
4. Click "Expire Build"

**Effect**: New testers cannot install, existing installations continue working

### Step 2: Notify Testers

Send notification via TestFlight:
1. Go to build details
2. Click "Notify Testers"
3. Message:
   ```
   Critical bug found in build [X].
   Please do not use this version.
   New build incoming shortly.
   ```

### Step 3: Deploy Hotfix

1. Create hotfix branch from main
2. Fix critical bug
3. Increment build number
4. Follow deployment process
5. Upload new build

### Step 4: Re-Enable Testing

1. New build appears in TestFlight
2. Notify testers of fix
3. Monitor for issues

---

## Beta Testing Guidelines

### For Testers

**What to Test**:
1. Core Features:
   - Audio recording
   - Transcription
   - AI analysis
   - Smart glasses integration

2. Edge Cases:
   - Network loss during recording
   - Background/foreground switching
   - Low battery conditions
   - Low storage space

3. Usability:
   - Navigation flow
   - Button responsiveness
   - Error messages clarity
   - Loading states

**How to Report Bugs**:

**Via TestFlight**:
1. Shake device while bug occurs
2. TestFlight prompts for feedback
3. Add screenshot and description
4. Submit

**Via Email/Slack** (if configured):
- Include device model
- Include iOS version
- Include build number
- Describe steps to reproduce
- Attach screenshot/video

**Feedback Format**:
```
Device: iPhone 15 Pro
iOS: 17.5
Build: 1.0.1 (2)

Issue: Recording button doesn't respond after 3 recordings

Steps:
1. Record 3 audio clips successfully
2. Try to start 4th recording
3. Button tap has no effect

Expected: Recording should start
Actual: Button unresponsive
```

### For Development Team

**Review Cadence**:
- Daily: Check crash reports
- Daily: Review feedback submissions
- Weekly: Analyze usage metrics
- Weekly: Plan fixes for next build

**Release Frequency**:
- Internal builds: As needed (daily if bugs found)
- External builds: Weekly or bi-weekly
- Hot fixes: Within 24 hours of critical bug

**Build Versioning**:
- Increment build number for every upload
- Increment minor version for feature additions
- Increment patch version for bug fixes

---

## TestFlight Limits & Best Practices

### Limits

| Limit Type | Internal Testing | External Testing |
|------------|------------------|------------------|
| Max Testers | 100 | 10,000 |
| Max Groups | Unlimited | 100 |
| Build Expiration | 90 days | 90 days |
| Beta Review Time | N/A | 24-48 hours |
| Max Builds Active | 100 | 100 |

### Best Practices

1. **Version Strategy**:
   - Use semantic versioning (MAJOR.MINOR.PATCH)
   - Auto-increment build numbers
   - Tag releases in Git

2. **Tester Management**:
   - Segment testers by group (QA, Beta, Internal)
   - Gradually roll out to larger groups
   - Start with internal, then limited external, then full external

3. **Communication**:
   - Write clear "What to Test" notes
   - Respond to feedback within 24 hours
   - Send weekly status updates

4. **Quality Control**:
   - Never skip local testing
   - Run all test cases before upload
   - Review crash reports daily

5. **Documentation**:
   - Maintain changelog
   - Document known issues
   - Provide testing guidelines

---

## Quick Reference Commands

```bash
# Build and archive (from project root)
flutter build ios --release
open ios/Runner.xcworkspace

# Fastlane deploy (from ios/ directory)
fastlane beta

# Increment build number
agvtool next-version -all

# Check current version
agvtool what-version

# Clean build
flutter clean && flutter pub get && cd ios && pod install

# View fastlane available actions
fastlane actions

# Update certificates
fastlane match development
fastlane match appstore
```

---

## Appendix

### A. Useful Links

- **App Store Connect**: https://appstoreconnect.apple.com
- **Apple Developer**: https://developer.apple.com
- **TestFlight**: https://testflight.apple.com
- **App Store Guidelines**: https://developer.apple.com/app-store/review/guidelines/
- **TestFlight Beta Testing**: https://developer.apple.com/testflight/
- **fastlane Docs**: https://docs.fastlane.tools

### B. Support Contacts

- **Apple Developer Support**: https://developer.apple.com/contact/
- **App Store Connect Support**: Via App Store Connect → Help

### C. Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-11-15 | Initial SOP created |

---

**Document Status**: Active  
**Next Review Date**: 2025-12-15  
**Owner**: Development Team
