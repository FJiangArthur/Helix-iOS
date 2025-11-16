// ABOUTME: Data export service for GDPR compliance
// ABOUTME: Allows users to export their data in portable formats

import 'dart:convert';
import 'dart:io';
import 'package:helix/services/analytics_service.dart';
import 'package:helix/core/config/privacy_config.dart';
import 'package:helix/core/utils/data_anonymization_service.dart';
import 'package:helix/core/utils/logging_service.dart';

/// Service for exporting user data
class DataExportService {
  static final DataExportService _instance = DataExportService._();
  static DataExportService get instance => _instance;

  DataExportService._();

  final _logger = LoggingService.instance;
  final _anonymizationService = DataAnonymizationService.instance;

  /// Export all analytics data
  Future<ExportResult> exportAnalyticsData({
    required PrivacyConfig config,
    bool anonymize = true,
  }) async {
    try {
      _logger.info('DataExport', 'Exporting analytics data (anonymize: $anonymize)');

      final analytics = AnalyticsService.instance;
      final events = analytics.getEvents();

      Map<String, dynamic> exportData;

      if (anonymize && config.anonymizeExports) {
        exportData = _anonymizationService.exportAnonymizedAnalytics(events, config);
      } else {
        exportData = {
          'exportedAt': DateTime.now().toIso8601String(),
          'totalEvents': events.length,
          'events': events.map((e) => e.toJson()).toList(),
          'summary': analytics.getSummary(),
          'anonymized': false,
        };
      }

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      return ExportResult(
        success: true,
        format: ExportFormat.json,
        content: jsonString,
        fileName: 'analytics_export_${DateTime.now().millisecondsSinceEpoch}.json',
        size: jsonString.length,
      );
    } catch (e, stackTrace) {
      _logger.error('DataExport', 'Failed to export analytics data', e, stackTrace);
      return ExportResult(
        success: false,
        error: 'Export failed: $e',
      );
    }
  }

  /// Export audio file metadata
  Future<ExportResult> exportAudioFileMetadata({
    required PrivacyConfig config,
  }) async {
    try {
      _logger.info('DataExport', 'Exporting audio file metadata');

      final directory = Directory.systemTemp;
      final files = directory
          .listSync()
          .where((file) =>
              file is File &&
              file.path.contains('helix_') &&
              file.path.endsWith('.wav'))
          .cast<File>()
          .toList();

      final fileData = <Map<String, dynamic>>[];

      for (final file in files) {
        final stat = file.statSync();
        fileData.add({
          'fileName': file.path.split('/').last,
          'filePath': config.anonymizeExports ? '[REDACTED]' : file.path,
          'size': stat.size,
          'sizeFormatted': _formatFileSize(stat.size),
          'created': stat.modified.toIso8601String(),
          'modified': stat.modified.toIso8601String(),
        });
      }

      final exportData = {
        'exportedAt': DateTime.now().toIso8601String(),
        'totalFiles': fileData.length,
        'totalSize': fileData.fold<int>(0, (sum, file) => sum + (file['size'] as int)),
        'files': fileData,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      return ExportResult(
        success: true,
        format: ExportFormat.json,
        content: jsonString,
        fileName: 'audio_files_export_${DateTime.now().millisecondsSinceEpoch}.json',
        size: jsonString.length,
      );
    } catch (e, stackTrace) {
      _logger.error('DataExport', 'Failed to export audio metadata', e, stackTrace);
      return ExportResult(
        success: false,
        error: 'Export failed: $e',
      );
    }
  }

  /// Export user preferences and settings
  Future<ExportResult> exportUserPreferences({
    required PrivacyConfig config,
  }) async {
    try {
      _logger.info('DataExport', 'Exporting user preferences');

      final exportData = {
        'exportedAt': DateTime.now().toIso8601String(),
        'privacySettings': config.toJson(),
        'retentionPeriods': _exportRetentionPeriods(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

      return ExportResult(
        success: true,
        format: ExportFormat.json,
        content: jsonString,
        fileName: 'preferences_export_${DateTime.now().millisecondsSinceEpoch}.json',
        size: jsonString.length,
      );
    } catch (e, stackTrace) {
      _logger.error('DataExport', 'Failed to export preferences', e, stackTrace);
      return ExportResult(
        success: false,
        error: 'Export failed: $e',
      );
    }
  }

  /// Export complete user data package (GDPR Article 20 - Data Portability)
  Future<ExportResult> exportCompleteDataPackage({
    required PrivacyConfig config,
    bool anonymize = true,
  }) async {
    try {
      _logger.info('DataExport', 'Creating complete data package');

      // Gather all data
      final analyticsResult = await exportAnalyticsData(
        config: config,
        anonymize: anonymize,
      );
      final audioResult = await exportAudioFileMetadata(config: config);
      final preferencesResult = await exportUserPreferences(config: config);

      if (!analyticsResult.success || !audioResult.success || !preferencesResult.success) {
        return ExportResult(
          success: false,
          error: 'Failed to export some data components',
        );
      }

      final packageData = {
        'exportedAt': DateTime.now().toIso8601String(),
        'exportType': 'complete_data_package',
        'anonymized': anonymize && config.anonymizeExports,
        'analytics': json.decode(analyticsResult.content!),
        'audioFiles': json.decode(audioResult.content!),
        'preferences': json.decode(preferencesResult.content!),
        'dataTypes': [
          'analytics',
          'audioFiles',
          'preferences',
        ],
        'exportInfo': {
          'version': '1.0.0',
          'format': 'JSON',
          'compliance': ['GDPR Article 20', 'CCPA'],
        },
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(packageData);

      return ExportResult(
        success: true,
        format: ExportFormat.json,
        content: jsonString,
        fileName: 'helix_data_export_${DateTime.now().millisecondsSinceEpoch}.json',
        size: jsonString.length,
      );
    } catch (e, stackTrace) {
      _logger.error('DataExport', 'Failed to create data package', e, stackTrace);
      return ExportResult(
        success: false,
        error: 'Export failed: $e',
      );
    }
  }

  /// Save export to file
  Future<bool> saveExportToFile(ExportResult result, String filePath) async {
    if (!result.success || result.content == null) {
      _logger.error('DataExport', 'Cannot save failed export');
      return false;
    }

    try {
      final file = File(filePath);
      await file.writeAsString(result.content!);
      _logger.info('DataExport', 'Export saved to: $filePath');
      return true;
    } catch (e, stackTrace) {
      _logger.error('DataExport', 'Failed to save export to file', e, stackTrace);
      return false;
    }
  }

  /// Export retention periods configuration
  Map<String, dynamic> _exportRetentionPeriods() {
    return {
      'audioRecordings': DataRetentionPeriods.audioRecordings.inHours,
      'audioChunks': DataRetentionPeriods.audioChunks.inMinutes,
      'temporaryAudioFiles': DataRetentionPeriods.temporaryAudioFiles.inHours,
      'transcriptionResults': DataRetentionPeriods.transcriptionResults.inDays,
      'transcriptionSegments': DataRetentionPeriods.transcriptionSegments.inDays,
      'conversationMessages': DataRetentionPeriods.conversationMessages.inDays,
      'conversationContext': DataRetentionPeriods.conversationContext.inHours,
      'conversationMetadata': DataRetentionPeriods.conversationMetadata.inDays,
      'factCheckResults': DataRetentionPeriods.factCheckResults.inDays,
      'conversationSummaries': DataRetentionPeriods.conversationSummaries.inDays,
      'actionItems': DataRetentionPeriods.actionItems.inDays,
      'sentimentAnalysis': DataRetentionPeriods.sentimentAnalysis.inDays,
      'cachedAnalysisResults': DataRetentionPeriods.cachedAnalysisResults.inMinutes,
      'analyticsEvents': DataRetentionPeriods.analyticsEvents.inHours,
      'errorLogs': DataRetentionPeriods.errorLogs.inHours,
      'performanceMetrics': DataRetentionPeriods.performanceMetrics.inHours,
      'bleHealthMetrics': DataRetentionPeriods.bleHealthMetrics.inHours,
      'sessionData': DataRetentionPeriods.sessionData.inHours,
    };
  }

  /// Format file size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Result of a data export operation
class ExportResult {
  final bool success;
  final ExportFormat? format;
  final String? content;
  final String? fileName;
  final int? size;
  final String? error;

  ExportResult({
    required this.success,
    this.format,
    this.content,
    this.fileName,
    this.size,
    this.error,
  });

  String get sizeFormatted {
    if (size == null) return '0 B';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(1)} KB';
    return '${(size! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() {
    if (success) {
      return 'ExportResult(success: true, format: $format, size: $sizeFormatted, file: $fileName)';
    } else {
      return 'ExportResult(success: false, error: $error)';
    }
  }
}

/// Export format enumeration
enum ExportFormat {
  json,
  csv,
  txt,
  xml,
}
