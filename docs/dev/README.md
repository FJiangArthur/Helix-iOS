# Developer Guides

This directory contains hands-on guides and best practices for developers working on the Helix codebase.

## What's Here

### Getting Started
- **[QUICK_START.md](QUICK_START.md)** - Get running in 10 minutes
  - Prerequisites and setup
  - Clone, build, and run instructions
  - First-time configuration
  - Troubleshooting common issues
  - Use this when: Starting development for the first time

### Core Development Guide
- **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)** - Comprehensive development guide
  - Project structure deep dive
  - Service-based architecture patterns
  - State management with Riverpod
  - Working with AI services
  - Testing guidelines and patterns
  - Common development tasks
  - Debugging and troubleshooting
  - Use this when: Daily development work

### Best Practices & Standards
- **[FLUTTER_BEST_PRACTICES.md](FLUTTER_BEST_PRACTICES.md)** - Flutter coding standards
  - Code style and formatting
  - Widget composition patterns
  - State management best practices
  - Performance optimization techniques
  - Security and privacy guidelines
  - Accessibility requirements
  - Use this when: Writing Flutter code

### Implementation Guides
- **[COMPREHENSIVE_IMPLEMENTATION_GUIDE.md](COMPREHENSIVE_IMPLEMENTATION_GUIDE.md)** - Detailed feature implementation
  - Step-by-step feature development
  - Epic-based implementation strategy
  - Code generation and scaffolding
  - Integration patterns
  - Use this when: Implementing complex features

- **[SIMPLE_AI_TEST_USAGE.md](SIMPLE_AI_TEST_USAGE.md)** - AI feature testing guide
  - Setting up AI services for testing
  - Testing LLM integrations
  - Mock vs real API testing
  - AI feature validation
  - Use this when: Testing AI-powered features

## How to Use This Documentation

### For New Developers
**Week 1 - Setup & Orientation**
1. Follow [QUICK_START.md](QUICK_START.md) to get environment ready
2. Read [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) sections 1-3 (Overview, Structure, Workflow)
3. Review [FLUTTER_BEST_PRACTICES.md](FLUTTER_BEST_PRACTICES.md) sections 1-2 (Basics)
4. Complete first simple task to familiarize with codebase

**Week 2 - Deep Dive**
1. Complete [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) (all sections)
2. Study [FLUTTER_BEST_PRACTICES.md](FLUTTER_BEST_PRACTICES.md) (all sections)
3. Review relevant architecture docs
4. Start working on feature tickets

**Ongoing**
- Reference guides as needed for specific tasks
- Keep [FLUTTER_BEST_PRACTICES.md](FLUTTER_BEST_PRACTICES.md) open during code reviews
- Use [SIMPLE_AI_TEST_USAGE.md](SIMPLE_AI_TEST_USAGE.md) when testing AI features

### For Experienced Flutter Developers
1. Skim [QUICK_START.md](QUICK_START.md) for Helix-specific setup
2. Review [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) for architecture patterns
3. Check [FLUTTER_BEST_PRACTICES.md](FLUTTER_BEST_PRACTICES.md) for project-specific conventions
4. Jump into development with guidance from relevant sections

### For Backend/AI Developers (New to Flutter)
1. Start with [QUICK_START.md](QUICK_START.md) for Flutter setup
2. Study [FLUTTER_BEST_PRACTICES.md](FLUTTER_BEST_PRACTICES.md) to understand Flutter patterns
3. Focus on [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) service layer sections
4. Reference [SIMPLE_AI_TEST_USAGE.md](SIMPLE_AI_TEST_USAGE.md) for AI integration

### For Contributing Developers
1. Review [QUICK_START.md](QUICK_START.md) and [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)
2. Follow [FLUTTER_BEST_PRACTICES.md](FLUTTER_BEST_PRACTICES.md) strictly for PRs
3. Reference [COMPREHENSIVE_IMPLEMENTATION_GUIDE.md](COMPREHENSIVE_IMPLEMENTATION_GUIDE.md) for feature work
4. Ensure tests pass per [Testing section](DEVELOPER_GUIDE.md#testing-guidelines)

## Development Workflow Quick Reference

### Daily Development
```bash
# Start development
flutter run

# Hot reload changes
r (in running app)

# Generate code (after model changes)
flutter packages pub run build_runner build --delete-conflicting-outputs

# Run tests
flutter test

# Check code quality
flutter analyze
```

### Common Tasks
- **Add new feature** → Follow [COMPREHENSIVE_IMPLEMENTATION_GUIDE.md](COMPREHENSIVE_IMPLEMENTATION_GUIDE.md)
- **Add new service** → See [DEVELOPER_GUIDE.md - Adding New Features](DEVELOPER_GUIDE.md#adding-new-features)
- **Add AI provider** → See [DEVELOPER_GUIDE.md - Adding AI Providers](DEVELOPER_GUIDE.md#adding-new-ai-providers)
- **Fix bug** → See [DEVELOPER_GUIDE.md - Debugging](DEVELOPER_GUIDE.md#debugging-and-troubleshooting)
- **Write tests** → See [DEVELOPER_GUIDE.md - Testing](DEVELOPER_GUIDE.md#testing-guidelines)

### Code Review Checklist
- [ ] Follows [FLUTTER_BEST_PRACTICES.md](FLUTTER_BEST_PRACTICES.md)
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] `flutter analyze` passes
- [ ] `flutter test` passes
- [ ] Code reviewed by team member
- [ ] Breaking changes documented

## Key Development Patterns

### Service Layer
```dart
// Abstract interface
abstract class MyService {
  Future<void> initialize();
  Future<Data> getData();
}

// Implementation
class MyServiceImpl implements MyService {
  @override
  Future<void> initialize() async { ... }
}

// Registration
getIt.registerLazySingleton<MyService>(() => MyServiceImpl());
```

### State Management (Riverpod)
```dart
// Provider definition
final myProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  return MyNotifier();
});

// Usage in UI
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myProvider);
    // Build UI
  }
}
```

### Data Models (Freezed)
```dart
@freezed
class MyModel with _$MyModel {
  const factory MyModel({
    required String id,
    required String name,
  }) = _MyModel;

  factory MyModel.fromJson(Map<String, dynamic> json) =>
      _$MyModelFromJson(json);
}
```

## Tools & Resources

### Essential Tools
- **Flutter SDK** 3.24+ - [Download](https://flutter.dev)
- **VS Code** / **Android Studio** - IDEs
- **Flutter DevTools** - Debugging and profiling
- **Dart DevTools** - Performance analysis

### Useful Extensions (VS Code)
- Flutter
- Dart
- Riverpod Snippets
- Error Lens
- GitLens

### External Documentation
- [Flutter Documentation](https://docs.flutter.dev)
- [Riverpod Guide](https://riverpod.dev)
- [Freezed Package](https://pub.dev/packages/freezed)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)

## Troubleshooting

### Common Issues
**Issue**: Build fails after git pull
- **Solution**: Run `flutter clean && flutter pub get`

**Issue**: Code generation not working
- **Solution**: Run `flutter packages pub run build_runner build --delete-conflicting-outputs`

**Issue**: Hot reload not working
- **Solution**: Try hot restart (Shift + R) or full restart

**Issue**: Tests failing unexpectedly
- **Solution**: Check [DEVELOPER_GUIDE.md - Debugging](DEVELOPER_GUIDE.md#debugging-and-troubleshooting)

For more issues, see [QUICK_START.md - Troubleshooting](QUICK_START.md#troubleshooting)

## Related Documentation
- [Architecture](../architecture/) - System design and patterns
- [API Documentation](../api/) - Service interfaces
- [Testing](../evaluation/) - Testing strategies
- [Operations](../ops/) - Deployment and infrastructure

## Contributing to Developer Docs
- Keep guides current with code changes
- Add examples for new patterns
- Document common pitfalls and solutions
- Update troubleshooting sections based on team feedback

---

**[← Back to Documentation Hub](../00-READ-FIRST.md)**
