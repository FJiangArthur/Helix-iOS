# Code Ownership Model

This document describes the code ownership model, review requirements, and escalation paths for the Helix iOS project.

## Table of Contents

- [Overview](#overview)
- [Ownership Structure](#ownership-structure)
- [Teams and Responsibilities](#teams-and-responsibilities)
- [Review Requirements](#review-requirements)
- [Escalation Paths](#escalation-paths)
- [How to Modify Ownership](#how-to-modify-ownership)
- [Best Practices](#best-practices)

## Overview

The Helix iOS project uses a distributed ownership model based on:
- **Feature areas**: AI/ML, Audio, Bluetooth, UI
- **Platform responsibilities**: iOS, Android, macOS, Web, Linux, Windows
- **Infrastructure**: CI/CD, Build systems, Testing

Code ownership serves several purposes:
1. **Automated review assignment**: GitHub automatically requests reviews from code owners
2. **Accountability**: Clear ownership for maintenance and bug fixes
3. **Knowledge distribution**: Teams build expertise in specific areas
4. **Quality assurance**: Domain experts review changes to their areas

## Ownership Structure

### Primary Files

- **`.github/CODEOWNERS`**: GitHub CODEOWNERS file for automated review assignment
- **`OWNERS.md`**: This file - ownership model and processes (you're reading it!)
- **Per-folder OWNERS**: Detailed ownership for specific directories (see below)

### Ownership Hierarchy

```
┌─────────────────────────┐
│   Helix Maintainers     │  ← Repository-level oversight
│   (Default Reviewers)   │
└───────────┬─────────────┘
            │
    ┌───────┴────────┬──────────────┬──────────────┐
    ▼                ▼              ▼              ▼
┌─────────┐    ┌──────────┐   ┌──────────┐   ┌──────────┐
│Platform │    │ Feature  │   │ Service  │   │  Infra   │
│  Teams  │    │  Teams   │   │  Teams   │   │  Teams   │
└─────────┘    └──────────┘   └──────────┘   └──────────┘
```

## Teams and Responsibilities

### Core Teams

#### **Helix Maintainers** (`@helix-maintainers`)
- **Scope**: Repository-wide oversight, architecture decisions, critical changes
- **Responsibilities**:
  - Final approval for major architectural changes
  - Review of critical infrastructure files
  - Coordination across teams
  - Release management
  - Security and compliance

#### **Documentation Team** (`@docs-team`)
- **Scope**: All documentation files
- **Responsibilities**:
  - Maintain README, guides, and API documentation
  - Ensure documentation accuracy and completeness
  - Review technical writing quality
  - Keep documentation in sync with code changes

### Platform Teams

#### **iOS Platform** (`@ios-platform`)
- **Scope**: `ios/` directory, native Swift code
- **Responsibilities**:
  - iOS-specific implementations
  - Swift code quality and best practices
  - Xcode project configuration
  - iOS SDK integration
  - App Store deployment

#### **Android Platform** (`@android-platform`)
- **Scope**: `android/` directory
- **Responsibilities**:
  - Android-specific implementations
  - Kotlin/Java code quality
  - Gradle configuration
  - Google Play Store deployment

#### **macOS Platform** (`@macos-platform`)
- **Scope**: `macos/` directory
- **Responsibilities**:
  - macOS-specific implementations
  - macOS SDK integration

#### **Flutter Platform** (`@flutter-platform`)
- **Scope**: Core Flutter/Dart code, build configuration
- **Responsibilities**:
  - Flutter framework usage and best practices
  - Dart code quality and patterns
  - Package management (`pubspec.yaml`)
  - Code generation and build tools
  - Cross-platform consistency

#### **Web Platform** (`@web-platform`)
- **Scope**: `web/` directory
- **Responsibilities**:
  - Web-specific implementations
  - Browser compatibility

#### **Windows Platform** (`@windows-platform`)
- **Scope**: `windows/` directory

#### **Linux Platform** (`@linux-platform`)
- **Scope**: `linux/` directory

### Feature Teams

#### **AI Team** (`@ai-team`)
- **Scope**: AI services, LLM integration, fact-checking, insights
- **Responsibilities**:
  - AI/ML service implementations
  - LLM provider integrations (OpenAI, Anthropic)
  - Fact-checking algorithms
  - Conversation intelligence
  - AI model selection and optimization
  - Prompt engineering

#### **ML Engineers** (`@ml-engineers`)
- **Scope**: Advanced ML implementations, model optimization
- **Responsibilities**:
  - Advanced ML algorithm implementations
  - Model performance optimization
  - AI provider evaluation and selection
  - ML pipeline architecture

#### **Audio Team** (`@audio-team`)
- **Scope**: Audio recording, processing, transcription
- **Responsibilities**:
  - Audio capture and processing
  - Speech-to-text integration
  - Audio buffer management
  - Whisper API integration
  - Audio quality and latency optimization
  - Cross-platform audio consistency

#### **Bluetooth Team** (`@bluetooth-team`)
- **Scope**: BLE communication, hardware integration
- **Responsibilities**:
  - Bluetooth Low Energy (BLE) protocol
  - Even Realities glasses integration
  - Hardware communication protocols
  - HUD display control
  - Device pairing and connection management

#### **Hardware Team** (`@hardware-team`)
- **Scope**: Hardware-specific protocols and integrations
- **Responsibilities**:
  - Even Realities G1 protocol implementation
  - Hardware-specific optimizations
  - Sensor integration

#### **UI Team** (`@ui-team`)
- **Scope**: User interface, screens, widgets
- **Responsibilities**:
  - Flutter UI components
  - Screen implementations
  - User experience (UX)
  - Accessibility
  - Theming and styling
  - UI performance

### Service Teams

#### **Backend Team** (`@backend-team`)
- **Scope**: Service implementations, business logic
- **Responsibilities**:
  - Service architecture
  - Dependency injection setup
  - Service locator pattern
  - API integration patterns
  - Data models and serialization

#### **Data Team** (`@data-team`)
- **Scope**: Analytics, data collection, metrics
- **Responsibilities**:
  - Analytics implementation
  - Data collection and privacy
  - Metrics and monitoring
  - Data models for analytics

#### **QA Team** (`@qa-team`)
- **Scope**: Testing infrastructure, test files
- **Responsibilities**:
  - Test coverage and quality
  - Testing strategy and best practices
  - Integration and unit tests
  - Test automation
  - CI test configuration

### Infrastructure Teams

#### **DevOps Team** (`@devops-team`)
- **Scope**: CI/CD, build scripts, deployment
- **Responsibilities**:
  - GitHub Actions workflows
  - Build automation
  - Deployment pipelines
  - Logging and monitoring infrastructure
  - Script maintenance

## Review Requirements

### Standard Review Process

1. **Automated Assignment**: GitHub automatically assigns reviewers based on CODEOWNERS
2. **Minimum Approvals**: At least **1 approval** from a code owner is required
3. **Review Timeframe**: Reviewers should respond within **48 hours** (2 business days)
4. **CI Checks**: All CI checks must pass before merge

### Special Cases

#### Critical Files
Files marked as critical require approval from `@helix-maintainers`:
- `/lib/main.dart`
- `/lib/services/service_locator.dart`
- `/pubspec.yaml`
- `/.github/workflows/*.yml`

#### Cross-Team Changes
Changes spanning multiple team areas require:
- At least 1 approval from **each affected team**
- Coordination comment explaining the cross-team impact

#### Breaking Changes
Changes that break existing APIs or contracts require:
- **2 approvals** from `@helix-maintainers`
- Migration guide in PR description
- Deprecation warnings (when applicable)
- Updated documentation

#### Hotfixes
Emergency hotfixes for production issues:
- Can be merged with **1 maintainer approval**
- Must be followed by full review within 24 hours
- Must include post-mortem documentation

### Review Checklist

Reviewers should verify:
- [ ] Code follows project style and conventions
- [ ] Tests are included and passing
- [ ] Documentation is updated
- [ ] No security vulnerabilities introduced
- [ ] Performance impact is acceptable
- [ ] Breaking changes are documented
- [ ] Dependencies are justified and vetted

## Escalation Paths

### Level 1: Team Lead
If a team member is unavailable:
1. Contact another member of the same team
2. Teams should maintain a roster with backup reviewers

### Level 2: Cross-Team Coordination
For cross-team conflicts or decisions:
1. Schedule a quick sync meeting with affected teams
2. Document decision in PR comments
3. Tag `@helix-maintainers` for visibility

### Level 3: Maintainer Review
For architectural decisions or unresolved conflicts:
1. Tag `@helix-maintainers` in PR
2. Schedule architecture review meeting if needed
3. Document decision in ADR (Architecture Decision Record)

### Level 4: Emergency Override
For critical production issues:
1. Any maintainer can approve emergency hotfix
2. Full review follows within 24 hours
3. Post-mortem required for process improvement

## How to Modify Ownership

### Adding New Ownership Rules

1. **Identify the need**: New feature, reorganization, or new team
2. **Create a PR** modifying `.github/CODEOWNERS`
3. **Get approval** from `@helix-maintainers`
4. **Update documentation**: Update this file and per-folder OWNERS files
5. **Communicate**: Announce changes to the team

### Changing Team Membership

Team membership is typically managed at the GitHub organization level:
1. Contact GitHub organization administrators
2. Request team membership changes
3. Update per-folder OWNERS files if needed

### Temporary Ownership Delegation

For temporary absences (vacation, leave):
1. Add additional reviewers to CODEOWNERS for the period
2. Document in team communication channel
3. Revert after return

## Best Practices

### For Code Owners

1. **Respond Promptly**: Review requests within 48 hours
2. **Be Thorough**: Don't just rubber-stamp; provide meaningful feedback
3. **Share Knowledge**: Use reviews as teaching opportunities
4. **Stay Current**: Keep up with changes in your area
5. **Delegate When Needed**: Assign backup reviewers during absences

### For Contributors

1. **Tag Early**: Tag potential reviewers in draft PRs for early feedback
2. **Keep PRs Focused**: Smaller PRs get reviewed faster
3. **Write Clear Descriptions**: Help reviewers understand the "why"
4. **Address Feedback**: Respond to all review comments
5. **Test Thoroughly**: Don't waste reviewer time with broken code

### For Teams

1. **Maintain Expertise**: Ensure multiple team members know each area
2. **Document Decisions**: Keep ADRs for architectural choices
3. **Regular Sync**: Hold regular team syncs to stay aligned
4. **Knowledge Sharing**: Conduct code walkthroughs and pair programming
5. **Update Ownership**: Keep CODEOWNERS current as code evolves

## Per-Folder Ownership Documentation

For detailed ownership of specific areas, see:
- `/lib/services/ai/OWNERS` - AI service ownership details
- `/lib/services/transcription/OWNERS` - Transcription service ownership
- `/ios/OWNERS` - iOS platform ownership details
- `/android/OWNERS` - Android platform ownership details
- `/.github/OWNERS` - CI/CD ownership details

## Contact Information

For questions about code ownership:
- **GitHub Discussions**: Post in the "Development" category
- **Slack**: `#helix-development` channel
- **Email**: helix-dev@example.com

## Revision History

| Date | Author | Changes |
|------|--------|---------|
| 2025-11-16 | Helix Team | Initial ownership model established |

---

**Note**: This ownership model is a living document. As the project evolves, ownership boundaries should be reviewed and updated quarterly.
