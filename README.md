# Helix - Real Time Conversation Prompter for Even Realities G1S App

Helix is an iOS companion app for Even Realities smart glasses that provides real-time conversation analysis and AI-powered insights displayed directly on the glasses HUD. The app processes live audio, performs speech-to-text conversion, and sends conversation data to LLM APIs for fact-checking, summarization, and contextual assistance.

## Features
- Real-time audio capture with noise reduction and voice activity detection
- Live speech-to-text transcription with speaker diarization
- Multi-provider AI analysis (OpenAI GPT, Anthropic Claude) for fact-checking and summarization
- Intelligent HUD rendering on Even Realities smart glasses
- Conversation history and export
- Configurable privacy and security settings

## Getting Started
### Prerequisites
- Xcode 16.2 or later
- Swift 5.0+
- iOS 18.2 SDK
- CocoaPods or Swift Package Manager for dependency management

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/helix.git
   cd helix
   ```
2. Install dependencies (if using CocoaPods):
   ```bash
   pod install
   ```
3. Open the workspace in Xcode:
   ```bash
   open Helix.xcodeproj
   ```

### Building
```bash
xcodebuild -project Helix.xcodeproj \
           -scheme Helix \
           -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Testing
Run all tests:
```bash
xcodebuild test -project Helix.xcodeproj \
           -scheme Helix \
           -destination 'platform=iOS Simulator,name=iPhone 15'
```
Run unit tests only:
```bash
xcodebuild test -project Helix.xcodeproj \
           -scheme Helix \
           -destination 'platform=iOS Simulator,name=iPhone 15' \
           -only-testing:HelixTests
```

## Project Structure
```
Helix/                # iOS SwiftUI application
├── Core/             # Core modules (Audio, Transcription, AI, Glasses, Display)
├── UI/               # SwiftUI views and coordinators
├── Assets.xcassets    # App icons and colors
├── HelixApp.swift     # Entry point
HelixTests/           # Unit tests
HelixUITests/         # UI automation tests
docs/                 # Architecture, requirements, plans, SLA, technical specs
libs/                 # External libraries and demos
```

## Documentation
- docs/Requirements.md - Software requirements
- docs/Architecture.md - System architecture and design
- docs/Implementation-Plan.md - Development roadmap and milestones
- docs/TechnicalSpecs.md - Detailed technical specifications
- docs/SLA.md - Service level agreement and support guidelines

## Contributing
- Follow MVVM-C pattern and protocol-oriented programming
- Write comprehensive unit tests (>= 90% coverage)
- Document all public APIs and configuration settings
- Use Combine publishers for reactive flows

## License
MIT License. See LICENSE for details.
