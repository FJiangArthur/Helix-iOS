# iOS Build and Deploy Workflow

**Last Updated**: 2025-11-13
**Flutter Version**: 3.35.1
**Xcode Version**: 26.1.1
**Target Platform**: iOS 15.0+

---

## Quick Reference

### Build and Deploy to Physical Device
```bash
cd ios
flutter run -d <DEVICE_ID> --release
```

### Get Device ID
```bash
flutter devices
```

---

## Complete Workflow

### Prerequisites

1. **Development Environment**
   - macOS 15.7.2+
   - Xcode 26.1.1+ installed
   - Flutter 3.35.1+ installed
   - CocoaPods 1.16.2+ installed

2. **Device Requirements**
   - **Physical Device**:
     - iPhone running iOS 15.0+
     - Developer Mode enabled (Settings > Privacy & Security > Developer Mode)
     - Device unlocked during deployment
     - USB cable connection OR same WiFi network (for wireless debugging)

   - **Simulator**:
     - iOS Simulator installed via Xcode
     - Target iOS version 15.0+

3. **Apple Developer Account**
   - Active Apple Developer account
   - Development certificate configured in Xcode
   - Team ID configured in project (Current: 4SA9UFLZMT)

---

## Step-by-Step Build Process

### Step 1: Prepare iOS Dependencies

```bash
# Navigate to iOS directory
cd ios

# Install/Update CocoaPods dependencies
pod install
```

**Expected Output**:
```
Analyzing dependencies
Downloading dependencies
Generating Pods project
Integrating client project
Pod installation complete! There are 6 dependencies from the Podfile and 7 total pods installed.
```

**Note**: You may see a warning about base configuration - this is expected and won't prevent building.

---

### Step 2: Verify Device Connection

```bash
# Check available devices
flutter devices
```

**For Physical Device**, you should see:
```
Art's Secret Castle (wireless) (mobile) • 00008150-001514CC3C00401C • ios • iOS 26.0.1 23A355
```

**For Simulator**, you should see:
```
iPhone 16 Pro (26.1) (mobile) • 7A04E4BD-01D6-40D6-88F3-D1CA751924C6 • ios • com.apple.CoreSimulator.SimRuntime.iOS-26-1 (simulator)
```

---

### Step 3: Device Preparation (Physical Device Only)

**CRITICAL**: Before deployment, ensure:

1. **Unlock iPhone**
   - Keep screen awake during deployment
   - Enter passcode if needed

2. **Trust This Computer**
   - When prompted on iPhone, tap "Trust"
   - May need to enter device passcode again

3. **Enable Developer Mode** (iOS 16+)
   - Go to Settings > Privacy & Security > Developer Mode
   - Toggle ON
   - Restart device if prompted

4. **Connection Method**
   - **USB**: Most reliable for first-time deployment
   - **Wireless**: Requires device on same WiFi network and Developer Mode enabled

---

### Step 4: Build and Deploy

#### Option A: Run in Release Mode (Recommended)

```bash
flutter run -d <DEVICE_ID> --release
```

**Example**:
```bash
flutter run -d 00008150-001514CC3C00401C --release
```

**Build Process**:
1. Resolves Flutter dependencies (~5s)
2. Automatically signs app with Team ID
3. Runs Xcode build (~25-30s)
4. Installs to device (~2-3s)
5. Launches application

**Expected Output**:
```
Launching lib/main.dart on Art's Secret Castle (wireless) in release mode...
Automatically signing iOS for device deployment using specified development team in Xcode project: 4SA9UFLZMT
Running Xcode build...
Xcode build done.                                           26.1s
Installing and launching...                                 2,352ms

Flutter run key commands.
h List all available interactive commands.
c Clear the screen
q Quit (terminate the application on the device).
```

#### Option B: Run in Debug Mode

```bash
flutter run -d <DEVICE_ID>
```

Debug mode enables:
- Hot reload (`r`)
- Hot restart (`R`)
- DevTools debugging
- Slower performance

---

### Step 5: Verify Deployment

1. **Check Device Screen**
   - App icon should appear on iPhone home screen
   - App launches automatically
   - Main conversation UI should be visible

2. **Test Core Features**
   - Recording button responds to tap
   - Waveform visualizer displays
   - Permission dialogs appear (microphone access)

---

## Build Artifacts

After successful build, you'll find:

```
build/ios/iphoneos/Runner.app          # Release build (code-signed)
build/ios/Debug-iphoneos/Runner.app    # Debug build (if built in debug mode)
```

**App Size**: ~24.6MB (release mode)

---

## Troubleshooting

### Issue 1: "Device is locked" Error

**Error**:
```
ERROR: The developer disk image could not be mounted on this device.
Error: kAMDMobileImageMounterDeviceLocked: The device is locked.
```

**Solution**:
1. Unlock iPhone
2. Keep screen on
3. Retry deployment

---

### Issue 2: "No code signature found"

**Error**:
```
Failed to verify code signature of Runner.app : No code signature found.
```

**Solution**:
Use `flutter run` instead of `flutter build ios --no-codesign`. The `flutter run` command automatically handles code signing.

---

### Issue 3: Trust Dialog Not Appearing

**Solution**:
1. Disconnect and reconnect USB cable
2. Check Finder > iPhone > Trust This Computer
3. Reset Location & Privacy: Settings > General > Transfer or Reset iPhone > Reset > Reset Location & Privacy

---

### Issue 4: Wireless Debugging Not Working

**Error**:
```
Error: Browsing on the local area network for [Device].
The device must be opted into Developer Mode to connect wirelessly.
```

**Solution**:
1. Ensure iPhone and Mac on same WiFi network
2. Enable Developer Mode on iPhone
3. Connect via USB first, then disconnect
4. Pair device: Xcode > Window > Devices and Simulators > Connect via Network

---

### Issue 5: Xcode Build Fails

**Check**:
1. Open project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. In Xcode:
   - Select Runner project
   - Go to Signing & Capabilities
   - Verify Team is selected
   - Check Bundle Identifier: `com.helix.hololens`
   - Build from Xcode: Product > Run

---

## Code Signing Configuration

### Automatic Signing (Current Setup)

The project uses **Automatic Code Signing**:
- Team ID: `4SA9UFLZMT`
- Bundle ID: `com.helix.hololens`
- Provisioning Profile: Managed by Xcode

### Manual Signing (If Needed)

If automatic signing fails:

1. Open Xcode project
2. Runner > Signing & Capabilities
3. Uncheck "Automatically manage signing"
4. Select:
   - **Provisioning Profile**: Your development profile
   - **Signing Certificate**: Apple Development certificate

---

## Performance Benchmarks

Based on successful deployment (2025-11-13):

| Phase | Duration |
|-------|----------|
| Dependency resolution | ~5s |
| Pod install | 1.2s |
| Xcode build (clean) | 26.1s |
| App installation | 2.4s |
| **Total** | **~35s** |

**Incremental builds**: ~10-15s (after code changes)

---

## CI/CD Considerations

### GitHub Actions Example

```yaml
name: iOS Build

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.1'

      - name: Install dependencies
        run: flutter pub get

      - name: Install CocoaPods
        run: |
          cd ios
          pod install

      - name: Build iOS (no codesign)
        run: flutter build ios --release --no-codesign
```

---

## Deployment Checklist

Before deploying to production or TestFlight:

- [ ] All tests passing (`flutter test`)
- [ ] Code reviewed and approved
- [ ] Version number incremented in `pubspec.yaml`
- [ ] Build number incremented in `ios/Runner/Info.plist`
- [ ] API keys configured in production environment
- [ ] Privacy permissions verified in Info.plist:
  - `NSMicrophoneUsageDescription`
  - `NSBluetoothAlwaysUsageDescription`
  - `NSBluetoothPeripheralUsageDescription`
- [ ] App Store assets prepared (screenshots, description)
- [ ] Release notes written

---

## Related Documentation

- [Quick Start Guide](QUICK_START.md)
- [Developer Guide](DEVELOPER_GUIDE.md)
- [Testing Strategy](TESTING_STRATEGY.md)
- [Architecture Overview](Architecture.md)

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2025-11-13 | 1.0 | Initial workflow documentation - successful physical device deployment |

---

**Project**: Helix Flutter Application
**Platform**: iOS Development
