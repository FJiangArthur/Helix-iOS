// ABOUTME: Data cleanup and retention service
// ABOUTME: Handles automatic deletion of expired data based on retention policies

import 'dart:io';
import 'package:helix/core/config/privacy_config.dart';
import 'package:helix/core/utils/logging_service.dart';

/// Service for managing data cleanup and retention
class DataCleanupService {
  static final DataCleanupService _instance = DataCleanupService._();
  static DataCleanupService get instance => _instance;

  DataCleanupService._();

  final _logger = LoggingService.instance;
  PrivacyConfig _config = const PrivacyConfig();
  bool _isRunning = false;

  /// Initialize with privacy configuration
  void initialize(PrivacyConfig config) {
    _config = config;
    _logger.info('DataCleanup', 'Initialized with config: $config');
  }

  /// Update privacy configuration
  void updateConfig(PrivacyConfig config) {
    _config = config;
    _logger.info('DataCleanup', 'Configuration updated');
  }

  /// Run cleanup for all data types
  Future<DataCleanupResult> runCleanup() async {
    if (_isRunning) {
      _logger.warning('DataCleanup', 'Cleanup already in progress');
      return DataCleanupResult(
        success: false,
        message: 'Cleanup already in progress',
      );
    }

    _isRunning = true;
    _logger.info('DataCleanup', 'Starting data cleanup');

    try {
      int totalDeleted = 0;
      int totalErrors = 0;
      final deletedItems = <String, int>{};

      // Cleanup audio files
      if (_config.autoDeleteEnabled) {
        final audioResult = await _cleanupAudioFiles();
        totalDeleted += audioResult.itemsDeleted;
        totalErrors += audioResult.errors;
        deletedItems['audioFiles'] = audioResult.itemsDeleted;
      }

      // Cleanup temporary files
      final tempResult = await _cleanupTemporaryFiles();
      totalDeleted += tempResult.itemsDeleted;
      totalErrors += tempResult.errors;
      deletedItems['temporaryFiles'] = tempResult.itemsDeleted;

      _logger.info(
        'DataCleanup',
        'Cleanup completed: $totalDeleted items deleted, $totalErrors errors',
      );

      return DataCleanupResult(
        success: totalErrors == 0,
        message: 'Deleted $totalDeleted items with $totalErrors errors',
        itemsDeleted: totalDeleted,
        errors: totalErrors,
        details: deletedItems,
      );
    } catch (e, stackTrace) {
      _logger.error('DataCleanup', 'Cleanup failed', e, stackTrace);
      return DataCleanupResult(
        success: false,
        message: 'Cleanup failed: $e',
      );
    } finally {
      _isRunning = false;
    }
  }

  /// Clean up audio files based on retention period
  Future<CleanupItemResult> _cleanupAudioFiles() async {
    int deleted = 0;
    int errors = 0;

    try {
      final directory = Directory.systemTemp;
      final retentionPeriod = _config.getRetentionPeriod('audioRecordings');
      final cutoffTime = DateTime.now().subtract(retentionPeriod);

      _logger.info(
        'DataCleanup',
        'Cleaning audio files older than $retentionPeriod',
      );

      if (!await directory.exists()) {
        return CleanupItemResult(itemsDeleted: 0, errors: 0);
      }

      final files = directory
          .listSync()
          .where((file) =>
              file is File &&
              file.path.contains('helix_') &&
              file.path.endsWith('.wav'))
          .cast<File>();

      for (final file in files) {
        try {
          final stat = file.statSync();
          if (stat.modified.isBefore(cutoffTime)) {
            if (_config.requireSecureDeletion) {
              await _secureDeleteFile(file);
            } else {
              await file.delete();
            }
            deleted++;
            _logger.debug('DataCleanup', 'Deleted audio file: ${file.path}');
          }
        } catch (e) {
          errors++;
          _logger.error('DataCleanup', 'Failed to delete file: ${file.path}', e);
        }
      }
    } catch (e) {
      errors++;
      _logger.error('DataCleanup', 'Audio cleanup failed', e);
    }

    return CleanupItemResult(itemsDeleted: deleted, errors: errors);
  }

  /// Clean up temporary files
  Future<CleanupItemResult> _cleanupTemporaryFiles() async {
    int deleted = 0;
    int errors = 0;

    try {
      final directory = Directory.systemTemp;
      final retentionPeriod = _config.getRetentionPeriod('temporaryAudioFiles');
      final cutoffTime = DateTime.now().subtract(retentionPeriod);

      if (!await directory.exists()) {
        return CleanupItemResult(itemsDeleted: 0, errors: 0);
      }

      // Clean up temp files with specific patterns
      final patterns = [
        RegExp(r'helix_temp_.*'),
        RegExp(r'audio_chunk_.*'),
        RegExp(r'transcription_cache_.*'),
      ];

      final allFiles = directory.listSync().whereType<File>();

      for (final file in allFiles) {
        try {
          final fileName = file.path.split('/').last;
          final matchesPattern = patterns.any((pattern) => pattern.hasMatch(fileName));

          if (matchesPattern) {
            final stat = file.statSync();
            if (stat.modified.isBefore(cutoffTime)) {
              if (_config.requireSecureDeletion) {
                await _secureDeleteFile(file);
              } else {
                await file.delete();
              }
              deleted++;
              _logger.debug('DataCleanup', 'Deleted temp file: ${file.path}');
            }
          }
        } catch (e) {
          errors++;
          _logger.error('DataCleanup', 'Failed to delete temp file: ${file.path}', e);
        }
      }
    } catch (e) {
      errors++;
      _logger.error('DataCleanup', 'Temp cleanup failed', e);
    }

    return CleanupItemResult(itemsDeleted: deleted, errors: errors);
  }

  /// Securely delete a file by overwriting before deletion
  Future<void> _secureDeleteFile(File file) async {
    try {
      // Get file size
      final size = await file.length();

      // Overwrite with zeros (one pass is usually sufficient for SSDs)
      final zeros = List<int>.filled(size, 0);
      await file.writeAsBytes(zeros, flush: true);

      // Delete the file
      await file.delete();

      _logger.debug('DataCleanup', 'Securely deleted file: ${file.path}');
    } catch (e) {
      _logger.error('DataCleanup', 'Secure deletion failed: ${file.path}', e);
      // Try regular deletion as fallback
      await file.delete();
    }
  }

  /// Delete a specific file
  Future<bool> deleteFile(String filePath, {bool secure = true}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        _logger.warning('DataCleanup', 'File not found: $filePath');
        return false;
      }

      if (secure && _config.requireSecureDeletion) {
        await _secureDeleteFile(file);
      } else {
        await file.delete();
      }

      _logger.info('DataCleanup', 'Deleted file: $filePath');
      return true;
    } catch (e) {
      _logger.error('DataCleanup', 'Failed to delete file: $filePath', e);
      return false;
    }
  }

  /// Delete all audio files
  Future<int> deleteAllAudioFiles() async {
    int deleted = 0;

    try {
      final directory = Directory.systemTemp;
      if (!await directory.exists()) {
        return 0;
      }

      final files = directory
          .listSync()
          .where((file) =>
              file is File &&
              file.path.contains('helix_') &&
              file.path.endsWith('.wav'))
          .cast<File>();

      for (final file in files) {
        try {
          if (_config.requireSecureDeletion) {
            await _secureDeleteFile(file);
          } else {
            await file.delete();
          }
          deleted++;
        } catch (e) {
          _logger.error('DataCleanup', 'Failed to delete: ${file.path}', e);
        }
      }

      _logger.info('DataCleanup', 'Deleted $deleted audio files');
    } catch (e) {
      _logger.error('DataCleanup', 'Failed to delete all audio files', e);
    }

    return deleted;
  }

  /// Get storage usage statistics
  Future<StorageStats> getStorageStats() async {
    int audioFiles = 0;
    int totalAudioSize = 0;
    int tempFiles = 0;
    int totalTempSize = 0;

    try {
      final directory = Directory.systemTemp;
      if (!await directory.exists()) {
        return StorageStats(
          audioFileCount: 0,
          audioFileSize: 0,
          tempFileCount: 0,
          tempFileSize: 0,
        );
      }

      final allFiles = directory.listSync().whereType<File>();

      for (final file in allFiles) {
        try {
          final fileName = file.path.split('/').last;
          final size = file.lengthSync();

          if (fileName.contains('helix_') && fileName.endsWith('.wav')) {
            audioFiles++;
            totalAudioSize += size;
          } else if (fileName.startsWith('helix_temp_') ||
              fileName.startsWith('audio_chunk_')) {
            tempFiles++;
            totalTempSize += size;
          }
        } catch (e) {
          _logger.error('DataCleanup', 'Failed to stat file: ${file.path}', e);
        }
      }
    } catch (e) {
      _logger.error('DataCleanup', 'Failed to get storage stats', e);
    }

    return StorageStats(
      audioFileCount: audioFiles,
      audioFileSize: totalAudioSize,
      tempFileCount: tempFiles,
      tempFileSize: totalTempSize,
    );
  }

  /// Schedule periodic cleanup (call this from app initialization)
  void schedulePeriodicCleanup({Duration interval = const Duration(hours: 6)}) {
    _logger.info('DataCleanup', 'Scheduling periodic cleanup every $interval');

    // Note: In a real implementation, you would use WorkManager or similar
    // for background task scheduling on mobile platforms
    // For now, this is a placeholder for the scheduling logic
    Future.delayed(interval, () async {
      await runCleanup();
      schedulePeriodicCleanup(interval: interval);
    });
  }
}

/// Result of a cleanup operation
class DataCleanupResult {
  final bool success;
  final String message;
  final int itemsDeleted;
  final int errors;
  final Map<String, int> details;

  DataCleanupResult({
    required this.success,
    required this.message,
    this.itemsDeleted = 0,
    this.errors = 0,
    this.details = const {},
  });

  @override
  String toString() {
    return 'DataCleanupResult(success: $success, deleted: $itemsDeleted, errors: $errors)';
  }
}

/// Result of cleaning up a specific item type
class CleanupItemResult {
  final int itemsDeleted;
  final int errors;

  CleanupItemResult({
    required this.itemsDeleted,
    required this.errors,
  });
}

/// Storage usage statistics
class StorageStats {
  final int audioFileCount;
  final int audioFileSize;
  final int tempFileCount;
  final int tempFileSize;

  StorageStats({
    required this.audioFileCount,
    required this.audioFileSize,
    required this.tempFileCount,
    required this.tempFileSize,
  });

  int get totalFiles => audioFileCount + tempFileCount;
  int get totalSize => audioFileSize + tempFileSize;

  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() {
    return {
      'audioFiles': audioFileCount,
      'audioSize': formatSize(audioFileSize),
      'audioSizeBytes': audioFileSize,
      'tempFiles': tempFileCount,
      'tempSize': formatSize(tempFileSize),
      'tempSizeBytes': tempFileSize,
      'totalFiles': totalFiles,
      'totalSize': formatSize(totalSize),
      'totalSizeBytes': totalSize,
    };
  }

  @override
  String toString() {
    return 'StorageStats(audioFiles: $audioFileCount [${formatSize(audioFileSize)}], '
        'tempFiles: $tempFileCount [${formatSize(tempFileSize)}], '
        'total: $totalFiles [${formatSize(totalSize)}])';
  }
}
