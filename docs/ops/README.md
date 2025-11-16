# Operations & Deployment

This directory contains all operations documentation including deployment workflows, build processes, and service level agreements.

## What's Here

### Deployment & Build
- **[BUILD_DEPLOY_WORKFLOW.md](BUILD_DEPLOY_WORKFLOW.md)** - iOS deployment guide
  - Complete step-by-step deployment process
  - Device preparation and prerequisites
  - Build configuration and code signing
  - Deployment to physical devices and simulators
  - Troubleshooting common deployment issues
  - Performance benchmarks
  - CI/CD integration patterns
  - Use this when: Deploying to iOS devices or setting up builds

- **[BUILD_STATUS.md](BUILD_STATUS.md)** - Current build health
  - Latest build results and status
  - Platform-specific build information
  - Known build issues and blockers
  - Build history and trends
  - Use this when: Checking build health or investigating failures

### Service Operations
- **[SLA.md](SLA.md)** - Service level agreements
  - Performance targets and commitments
  - Availability requirements
  - Response time objectives
  - Uptime guarantees
  - Escalation procedures
  - Use this when: Understanding operational requirements

## How to Use This Documentation

### For DevOps Engineers
1. Study [BUILD_DEPLOY_WORKFLOW.md](BUILD_DEPLOY_WORKFLOW.md) for deployment process
2. Monitor [BUILD_STATUS.md](BUILD_STATUS.md) for build health
3. Reference [SLA.md](SLA.md) for performance targets
4. Set up CI/CD pipelines based on workflow docs

### For Mobile Developers
1. Follow [BUILD_DEPLOY_WORKFLOW.md](BUILD_DEPLOY_WORKFLOW.md) for device deployment
2. Check [BUILD_STATUS.md](BUILD_STATUS.md) before starting work
3. Reference troubleshooting sections for deployment issues
4. Understand signing and provisioning requirements

### For QA Engineers
1. Use [BUILD_DEPLOY_WORKFLOW.md](BUILD_DEPLOY_WORKFLOW.md) for test device setup
2. Monitor [BUILD_STATUS.md](BUILD_STATUS.md) for stable builds
3. Reference [SLA.md](SLA.md) for performance testing targets
4. Verify deployments meet SLA requirements

### For Product/Project Managers
1. Review [SLA.md](SLA.md) for commitments and targets
2. Check [BUILD_STATUS.md](BUILD_STATUS.md) for release readiness
3. Monitor deployment success rates
4. Track performance against SLA objectives

## Deployment Quick Reference

### iOS Physical Device Deployment
```bash
# 1. Check available devices
flutter devices

# 2. Deploy to device (release mode)
flutter run -d <DEVICE_ID> --release

# 3. Deploy to device (debug mode)
flutter run -d <DEVICE_ID>
```

### iOS Simulator Deployment
```bash
# 1. List available simulators
flutter devices

# 2. Deploy to simulator
flutter run -d <SIMULATOR_ID>
```

### Build Commands
```bash
# iOS build (no codesign - for CI)
flutter build ios --release --no-codesign

# iOS build (with codesign - for deployment)
flutter build ios --release

# Android APK build
flutter build apk --release

# Android App Bundle
flutter build appbundle --release
```

### Pre-Deployment Checklist
- [ ] All tests passing (`flutter test`)
- [ ] Code analysis clean (`flutter analyze`)
- [ ] Version number incremented
- [ ] Build number incremented
- [ ] API keys configured
- [ ] Platform permissions verified
- [ ] Release notes prepared
- [ ] Rollback plan documented

## Platform-Specific Deployment

### iOS Deployment Requirements
**Development Environment**
- macOS 15.7.2+
- Xcode 26.1.1+
- Flutter 3.35.1+
- CocoaPods 1.16.2+

**Device Requirements**
- iOS 15.0+ on physical device
- Developer Mode enabled (iOS 16+)
- Device unlocked during deployment
- Valid development certificate

**See**: [BUILD_DEPLOY_WORKFLOW.md](BUILD_DEPLOY_WORKFLOW.md) for complete guide

### Android Deployment Requirements
**Development Environment**
- Android Studio or VS Code
- Android SDK 33+
- Flutter 3.35.1+
- Java 11+

**Device Requirements**
- Android 8.0+ (API level 26+)
- USB debugging enabled
- Valid signing key for release builds

## Performance Targets (from SLA)

### Application Performance
- **Audio Latency**: <100ms capture to processing
- **Transcription Latency**: <200ms speech to text
- **AI Analysis**: <2 seconds comprehensive analysis
- **UI Responsiveness**: 60fps smooth rendering
- **Memory Usage**: <200MB sustained operation

### Build Performance
- **Dependency Resolution**: ~5 seconds
- **Clean Build**: ~26 seconds (iOS)
- **Incremental Build**: ~10-15 seconds
- **App Installation**: ~2-3 seconds
- **Total Deployment**: ~35 seconds

### Availability Targets
- **System Uptime**: 99.9% excluding maintenance
- **Connection Stability**: <1% dropout rate
- **Data Integrity**: 100% conversation preservation
- **Error Recovery**: Automatic retry with backoff

## Monitoring & Health Checks

### Build Health Indicators
- ✅ **Healthy**: All tests pass, builds successful
- ⚠️ **Warning**: Tests pass but build issues on some platforms
- ❌ **Critical**: Tests failing or builds broken

### Service Health Monitoring
- AI service availability and response times
- Bluetooth connection stability
- Audio processing performance
- Database query performance
- API quota and rate limit usage

### Key Metrics to Track
1. Build success rate (target: >95%)
2. Deployment success rate (target: >98%)
3. Average build time (trend monitoring)
4. Test coverage (target: >90%)
5. Code quality score (static analysis)

## Troubleshooting

### Common Deployment Issues

**Device Locked Error**
```
ERROR: The device is locked
```
- **Solution**: Unlock iPhone and keep screen on during deployment

**Code Signature Error**
```
No code signature found
```
- **Solution**: Use `flutter run` instead of manual build commands

**Wireless Debugging Not Working**
```
The device must be opted into Developer Mode
```
- **Solution**: Enable Developer Mode in device settings, connect via USB first

See [BUILD_DEPLOY_WORKFLOW.md - Troubleshooting](BUILD_DEPLOY_WORKFLOW.md#troubleshooting) for complete guide

## CI/CD Integration

### GitHub Actions Example
```yaml
name: iOS Build
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.1'
      - run: flutter pub get
      - run: cd ios && pod install
      - run: flutter build ios --release --no-codesign
```

### Deployment Pipeline Stages
1. **Build** - Compile and package application
2. **Test** - Run automated test suites
3. **Quality** - Static analysis and code quality checks
4. **Deploy** - Distribute to test devices/stores
5. **Monitor** - Track deployment success and app health

## Related Documentation
- [Architecture](../architecture/) - System design for deployment
- [Developer Guides](../dev/) - Build and development setup
- [Testing](../evaluation/) - Testing before deployment
- [Product](../product/) - Feature requirements and acceptance

## Updating Operations Documentation

### When to Update
- After successful deployment process changes
- When new platforms are added
- After infrastructure changes
- When performance targets change
- After incident resolution (add to troubleshooting)

### What to Document
- New deployment procedures
- Build configuration changes
- Performance benchmark updates
- New monitoring and alerting
- Incident postmortems and solutions

---

**[← Back to Documentation Hub](../00-READ-FIRST.md)**
