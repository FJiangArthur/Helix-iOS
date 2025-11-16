/// Test Data Manager
///
/// Centralized management of test data, fixtures, and test resources

import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

/// Manager for test data files and resources
class TestDataManager {
  TestDataManager({this.testDataDir = 'test/test_data'});

  final String testDataDir;

  /// Load JSON test data from file
  Future<Map<String, dynamic>> loadJsonFixture(String filename) async {
    final File file = File(path.join(testDataDir, filename));

    if (!await file.exists()) {
      throw Exception('Test data file not found: ${file.path}');
    }

    final String content = await file.readAsString();
    return json.decode(content) as Map<String, dynamic>;
  }

  /// Load text test data from file
  Future<String> loadTextFixture(String filename) async {
    final File file = File(path.join(testDataDir, filename));

    if (!await file.exists()) {
      throw Exception('Test data file not found: ${file.path}');
    }

    return file.readAsString();
  }

  /// Load binary test data from file
  Future<List<int>> loadBinaryFixture(String filename) async {
    final File file = File(path.join(testDataDir, filename));

    if (!await file.exists()) {
      throw Exception('Test data file not found: ${file.path}');
    }

    return file.readAsBytes();
  }

  /// Load test data from assets
  Future<String> loadAssetFixture(String assetPath) async {
    try {
      return await rootBundle.loadString(assetPath);
    } catch (e) {
      throw Exception('Failed to load asset: $assetPath - $e');
    }
  }

  /// Save test data to file (useful for debugging)
  Future<void> saveTestData(String filename, dynamic data) async {
    final File file = File(path.join(testDataDir, filename));

    // Create directory if it doesn't exist
    await file.parent.create(recursive: true);

    if (data is String) {
      await file.writeAsString(data);
    } else if (data is List<int>) {
      await file.writeAsBytes(data);
    } else if (data is Map || data is List) {
      await file.writeAsString(json.encode(data));
    } else {
      throw Exception('Unsupported data type for saving');
    }
  }

  /// Clean up test data directory
  Future<void> cleanup() async {
    final Directory dir = Directory(testDataDir);

    if (await dir.exists()) {
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is File && entity.path.contains('temp_')) {
          await entity.delete();
        }
      }
    }
  }

  /// Create temporary test data file
  Future<File> createTempFile(String prefix, String content) async {
    final Directory dir = Directory(testDataDir);
    await dir.create(recursive: true);

    final String filename = '${prefix}_${DateTime.now().millisecondsSinceEpoch}.tmp';
    final File file = File(path.join(testDataDir, filename));

    await file.writeAsString(content);
    return file;
  }
}

/// Repository pattern for test data
class TestDataRepository {
  final Map<String, dynamic> _cache = <String, dynamic>{};

  /// Get cached test data or load it
  Future<T> getData<T>(
    String key,
    Future<T> Function() loader,
  ) async {
    if (_cache.containsKey(key)) {
      return _cache[key] as T;
    }

    final T data = await loader();
    _cache[key] = data;
    return data;
  }

  /// Clear cached test data
  void clearCache() {
    _cache.clear();
  }

  /// Preload test data
  Future<void> preload(
    String key,
    Future<dynamic> Function() loader,
  ) async {
    final dynamic data = await loader();
    _cache[key] = data;
  }

  /// Check if data is cached
  bool isCached(String key) {
    return _cache.containsKey(key);
  }
}

/// Builder for creating test scenarios
class TestScenarioBuilder {
  TestScenarioBuilder(this.name);

  final String name;
  final List<TestAction> _actions = <TestAction>[];
  final Map<String, dynamic> _data = <String, dynamic>{};

  /// Add test data
  TestScenarioBuilder withData(String key, dynamic value) {
    _data[key] = value;
    return this;
  }

  /// Add test action
  TestScenarioBuilder addAction(TestAction action) {
    _actions.add(action);
    return this;
  }

  /// Build the scenario
  TestScenario build() {
    return TestScenario(
      name: name,
      actions: _actions,
      data: _data,
    );
  }
}

/// Test scenario
class TestScenario {
  TestScenario({
    required this.name,
    required this.actions,
    required this.data,
  });

  final String name;
  final List<TestAction> actions;
  final Map<String, dynamic> data;

  /// Execute the scenario
  Future<void> execute() async {
    for (final TestAction action in actions) {
      await action.execute(data);
    }
  }
}

/// Test action interface
abstract class TestAction {
  Future<void> execute(Map<String, dynamic> context);
}

/// Example test action: delay
class DelayAction implements TestAction {
  DelayAction(this.duration);

  final Duration duration;

  @override
  Future<void> execute(Map<String, dynamic> context) async {
    await Future<void>.delayed(duration);
  }
}

/// Example test action: set data
class SetDataAction implements TestAction {
  SetDataAction(this.key, this.value);

  final String key;
  final dynamic value;

  @override
  Future<void> execute(Map<String, dynamic> context) async {
    context[key] = value;
  }
}

/// Test data cleanup utility
class TestDataCleanup {
  final List<File> _filesToCleanup = <File>[];
  final List<Directory> _dirsToCleanup = <Directory>[];

  /// Register file for cleanup
  void registerFile(File file) {
    _filesToCleanup.add(file);
  }

  /// Register directory for cleanup
  void registerDirectory(Directory dir) {
    _dirsToCleanup.add(dir);
  }

  /// Cleanup all registered resources
  Future<void> cleanup() async {
    // Delete files
    for (final File file in _filesToCleanup) {
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Delete directories
    for (final Directory dir in _dirsToCleanup) {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }

    _filesToCleanup.clear();
    _dirsToCleanup.clear();
  }
}
