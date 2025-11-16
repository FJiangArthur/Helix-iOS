# Linting & Formatting Quick Reference

Quick reference guide for code quality tools and common tasks.

## Quick Commands

```bash
# Format code
./scripts/format.sh                    # Format all files
./scripts/format.sh --check            # Check only (CI)

# Lint code
./scripts/lint.sh                      # Run analyzer
./scripts/lint.sh --strict             # Strict mode (CI)

# Auto-fix
./scripts/fix.sh                       # Fix all auto-fixable issues

# Validate (CI)
./scripts/validate.sh                  # Run all checks + tests

# Pre-commit
pre-commit run --all-files             # Run all pre-commit hooks
pre-commit run <hook-id>               # Run specific hook
```

## Common Scenarios

### Before Committing

```bash
# Quick check
./scripts/format.sh && ./scripts/lint.sh

# Auto-fix issues
./scripts/fix.sh

# Full validation (recommended)
./scripts/validate.sh
```

### Fixing Linting Errors

1. **Run auto-fix first**:
   ```bash
   ./scripts/fix.sh
   ```

2. **Check remaining issues**:
   ```bash
   ./scripts/lint.sh
   ```

3. **Fix manually** if needed

### CI/CD Integration

```bash
# In CI pipeline
./scripts/validate.sh
```

## Common Lint Errors & Fixes

### 1. Missing Type Annotations

**Error**: `always_specify_types`

```dart
// ✗ Bad
var name = 'John';
final items = [];

// ✓ Good
String name = 'John';
final List<String> items = [];
```

### 2. Missing Return Type

**Error**: `always_declare_return_types`

```dart
// ✗ Bad
getUserName() {
  return 'John';
}

// ✓ Good
String getUserName() {
  return 'John';
}
```

### 3. Use Final Instead of Var

**Error**: `prefer_final_locals`

```dart
// ✗ Bad
var name = 'John';

// ✓ Good
final String name = 'John';
```

### 4. Missing Const

**Error**: `prefer_const_constructors`

```dart
// ✗ Bad
SizedBox(height: 16)
Text('Hello')

// ✓ Good
const SizedBox(height: 16)
const Text('Hello')
```

### 5. Unnecessary This

**Error**: `unnecessary_this`

```dart
// ✗ Bad
class User {
  String name;
  String getName() {
    return this.name;
  }
}

// ✓ Good
class User {
  String name;
  String getName() {
    return name;
  }
}
```

### 6. Avoid Print Statements

**Error**: `avoid_print`

```dart
// ✗ Bad
print('Debug message');

// ✓ Good
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  debugPrint('Debug message');
}

// Or use a logger
logger.debug('Debug message');
```

### 7. Trailing Commas Required

**Error**: `require_trailing_commas`

```dart
// ✗ Bad
Widget build(BuildContext context) {
  return Column(
    children: [
      Text('Hello'),
      Text('World')
    ]
  );
}

// ✓ Good
Widget build(BuildContext context) {
  return Column(
    children: <Widget>[
      const Text('Hello'),
      const Text('World'),
    ],
  );
}
```

### 8. Prefer Single Quotes

**Error**: `prefer_single_quotes`

```dart
// ✗ Bad
String name = "John";

// ✓ Good
String name = 'John';

// Exception: when string contains single quotes
String message = "It's a nice day";  // OK
```

### 9. Unawaited Futures

**Error**: `unawaited_futures`

```dart
// ✗ Bad
void processData() async {
  saveToDatabase(data);  // Missing await
}

// ✓ Good
import 'package:flutter/foundation.dart';

void processData() async {
  await saveToDatabase(data);

  // Or explicitly mark as unawaited
  unawaited(analytics.logEvent('processed'));
}
```

### 10. Avoid Dynamic Calls

**Error**: `avoid_dynamic_calls`

```dart
// ✗ Bad
dynamic obj = getObject();
obj.someMethod();

// ✓ Good
Object obj = getObject();
if (obj is MyClass) {
  obj.someMethod();
}
```

## Suppressing Lint Rules

### Single Line

```dart
// ignore: rule_name
problematicCode();
```

### Entire File

```dart
// ignore_for_file: rule_name, another_rule

// Rest of file...
```

### Multiple Lines

```dart
// ignore: rule_name
line1();
line2();
line3();
```

**Note**: Only suppress rules when absolutely necessary. Document why you're suppressing:

```dart
// ignore: avoid_print - Temporary debug output for development
print('Debug: $value');
```

## Configuration Files

### analysis_options.yaml

Main linting configuration file. Contains all lint rules and analyzer settings.

**Location**: `/home/user/Helix-iOS/analysis_options.yaml`

**Key sections**:
- `analyzer.language`: Type safety settings
- `analyzer.errors`: Error severity levels
- `linter.rules`: Individual lint rules

### .editorconfig

Cross-editor formatting settings.

**Location**: `/home/user/Helix-iOS/.editorconfig`

**Settings**:
- Charset: UTF-8
- Line endings: LF
- Indentation: 2 spaces
- Trailing whitespace: trimmed
- Final newline: required

### .pre-commit-config.yaml

Pre-commit hooks configuration.

**Location**: `/home/user/Helix-iOS/.pre-commit-config.yaml`

**Hooks**:
- Code formatting
- Static analysis
- Tests
- Security scanning
- Markdown linting

## IDE Setup

### VS Code

Install extensions:
- Dart
- Flutter

Settings (`.vscode/settings.json`):
```json
{
  "dart.lineLength": 120,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true,
    "source.organizeImports": true
  }
}
```

### Android Studio / IntelliJ

1. Install Flutter/Dart plugins
2. Settings → Editor → Code Style → Dart
3. Set line length to 120
4. Enable format on save
5. Enable organize imports on save

## Troubleshooting

### "Analysis server is not running"

```bash
# Restart analysis server
flutter pub get
# Then restart your IDE
```

### "Some lint rules not working"

```bash
# Clear cache and reinstall
flutter clean
flutter pub get
```

### "Format script fails"

```bash
# Make sure script is executable
chmod +x scripts/format.sh

# Run from project root
cd /home/user/Helix-iOS
./scripts/format.sh
```

### "Pre-commit hooks not running"

```bash
# Reinstall hooks
pre-commit uninstall
pre-commit install

# Test
pre-commit run --all-files
```

## Best Practices

1. **Run validation before pushing**
   ```bash
   ./scripts/validate.sh
   ```

2. **Format often**
   - Enable format on save in your IDE
   - Or run `./scripts/format.sh` regularly

3. **Fix warnings early**
   - Don't let warnings accumulate
   - Address them when they appear

4. **Use auto-fix**
   - Many issues can be fixed automatically
   - Run `./scripts/fix.sh` regularly

5. **Don't suppress rules unnecessarily**
   - Only suppress when you have a good reason
   - Always add a comment explaining why

6. **Keep dependencies updated**
   ```bash
   flutter pub outdated
   flutter pub upgrade
   ```

## Resources

- [Dart Lints Documentation](https://dart.dev/lints)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [Flutter Style Guide](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo)
- [analysis_options.yaml Reference](https://dart.dev/guides/language/analysis-options)
- [Project Code Style Guide](./CODE_STYLE_GUIDE.md)
