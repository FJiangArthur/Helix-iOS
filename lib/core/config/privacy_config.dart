// ABOUTME: Privacy and data retention configuration
// ABOUTME: Defines retention periods, deletion policies, and privacy settings

/// Data retention periods for different data types
class DataRetentionPeriods {
  // Audio data retention
  static const Duration audioRecordings = Duration(hours: 24);
  static const Duration audioChunks = Duration(minutes: 5);
  static const Duration temporaryAudioFiles = Duration(hours: 24);

  // Transcription data retention
  static const Duration transcriptionResults = Duration(days: 7);
  static const Duration transcriptionSegments = Duration(days: 7);

  // Conversation data retention
  static const Duration conversationMessages = Duration(days: 7);
  static const Duration conversationContext = Duration(hours: 2);
  static const Duration conversationMetadata = Duration(days: 7);

  // AI analysis data retention
  static const Duration factCheckResults = Duration(days: 30);
  static const Duration conversationSummaries = Duration(days: 30);
  static const Duration actionItems = Duration(days: 30);
  static const Duration sentimentAnalysis = Duration(days: 30);
  static const Duration cachedAnalysisResults = Duration(minutes: 10);

  // Analytics and telemetry retention
  static const Duration analyticsEvents = Duration(hours: 24);
  static const Duration errorLogs = Duration(hours: 24);
  static const Duration performanceMetrics = Duration(hours: 24);
  static const Duration bleHealthMetrics = Duration(hours: 12);

  // Session data retention
  static const Duration sessionData = Duration(hours: 2);
  static const Duration activeStreams = Duration(minutes: 0); // Immediate deletion

  // API and credentials (never auto-delete, manual only)
  static const Duration apiKeys = Duration(days: 365 * 100); // Effectively permanent
}

/// Privacy configuration and settings
class PrivacyConfig {
  // Feature toggles
  final bool analyticsEnabled;
  final bool aiAnalysisEnabled;
  final bool errorReportingEnabled;
  final bool performanceTrackingEnabled;

  // Data retention settings
  final bool autoDeleteEnabled;
  final Map<String, Duration> customRetentionPeriods;

  // Anonymization settings
  final bool anonymizeAnalytics;
  final bool anonymizeExports;
  final bool removeSpeakerIds;

  // Security settings
  final bool requireSecureDeletion;
  final bool encryptSensitiveData;
  final bool enableAccessLogging;

  // User consent
  final bool hasAnalyticsConsent;
  final bool hasAIProcessingConsent;
  final bool hasDataExportConsent;
  final DateTime? consentTimestamp;

  const PrivacyConfig({
    this.analyticsEnabled = true,
    this.aiAnalysisEnabled = true,
    this.errorReportingEnabled = true,
    this.performanceTrackingEnabled = true,
    this.autoDeleteEnabled = true,
    this.customRetentionPeriods = const {},
    this.anonymizeAnalytics = false,
    this.anonymizeExports = true,
    this.removeSpeakerIds = false,
    this.requireSecureDeletion = true,
    this.encryptSensitiveData = false,
    this.enableAccessLogging = false,
    this.hasAnalyticsConsent = false,
    this.hasAIProcessingConsent = false,
    this.hasDataExportConsent = false,
    this.consentTimestamp,
  });

  /// Create a copy with updated values
  PrivacyConfig copyWith({
    bool? analyticsEnabled,
    bool? aiAnalysisEnabled,
    bool? errorReportingEnabled,
    bool? performanceTrackingEnabled,
    bool? autoDeleteEnabled,
    Map<String, Duration>? customRetentionPeriods,
    bool? anonymizeAnalytics,
    bool? anonymizeExports,
    bool? removeSpeakerIds,
    bool? requireSecureDeletion,
    bool? encryptSensitiveData,
    bool? enableAccessLogging,
    bool? hasAnalyticsConsent,
    bool? hasAIProcessingConsent,
    bool? hasDataExportConsent,
    DateTime? consentTimestamp,
  }) {
    return PrivacyConfig(
      analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
      aiAnalysisEnabled: aiAnalysisEnabled ?? this.aiAnalysisEnabled,
      errorReportingEnabled: errorReportingEnabled ?? this.errorReportingEnabled,
      performanceTrackingEnabled: performanceTrackingEnabled ?? this.performanceTrackingEnabled,
      autoDeleteEnabled: autoDeleteEnabled ?? this.autoDeleteEnabled,
      customRetentionPeriods: customRetentionPeriods ?? this.customRetentionPeriods,
      anonymizeAnalytics: anonymizeAnalytics ?? this.anonymizeAnalytics,
      anonymizeExports: anonymizeExports ?? this.anonymizeExports,
      removeSpeakerIds: removeSpeakerIds ?? this.removeSpeakerIds,
      requireSecureDeletion: requireSecureDeletion ?? this.requireSecureDeletion,
      encryptSensitiveData: encryptSensitiveData ?? this.encryptSensitiveData,
      enableAccessLogging: enableAccessLogging ?? this.enableAccessLogging,
      hasAnalyticsConsent: hasAnalyticsConsent ?? this.hasAnalyticsConsent,
      hasAIProcessingConsent: hasAIProcessingConsent ?? this.hasAIProcessingConsent,
      hasDataExportConsent: hasDataExportConsent ?? this.hasDataExportConsent,
      consentTimestamp: consentTimestamp ?? this.consentTimestamp,
    );
  }

  /// Get retention period for a specific data type
  Duration getRetentionPeriod(String dataType) {
    // Check custom retention periods first
    if (customRetentionPeriods.containsKey(dataType)) {
      return customRetentionPeriods[dataType]!;
    }

    // Return default retention periods
    switch (dataType) {
      case 'audioRecordings':
        return DataRetentionPeriods.audioRecordings;
      case 'audioChunks':
        return DataRetentionPeriods.audioChunks;
      case 'temporaryAudioFiles':
        return DataRetentionPeriods.temporaryAudioFiles;
      case 'transcriptionResults':
        return DataRetentionPeriods.transcriptionResults;
      case 'transcriptionSegments':
        return DataRetentionPeriods.transcriptionSegments;
      case 'conversationMessages':
        return DataRetentionPeriods.conversationMessages;
      case 'conversationContext':
        return DataRetentionPeriods.conversationContext;
      case 'conversationMetadata':
        return DataRetentionPeriods.conversationMetadata;
      case 'factCheckResults':
        return DataRetentionPeriods.factCheckResults;
      case 'conversationSummaries':
        return DataRetentionPeriods.conversationSummaries;
      case 'actionItems':
        return DataRetentionPeriods.actionItems;
      case 'sentimentAnalysis':
        return DataRetentionPeriods.sentimentAnalysis;
      case 'cachedAnalysisResults':
        return DataRetentionPeriods.cachedAnalysisResults;
      case 'analyticsEvents':
        return DataRetentionPeriods.analyticsEvents;
      case 'errorLogs':
        return DataRetentionPeriods.errorLogs;
      case 'performanceMetrics':
        return DataRetentionPeriods.performanceMetrics;
      case 'bleHealthMetrics':
        return DataRetentionPeriods.bleHealthMetrics;
      case 'sessionData':
        return DataRetentionPeriods.sessionData;
      case 'activeStreams':
        return DataRetentionPeriods.activeStreams;
      default:
        return const Duration(days: 7); // Default retention
    }
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'analyticsEnabled': analyticsEnabled,
      'aiAnalysisEnabled': aiAnalysisEnabled,
      'errorReportingEnabled': errorReportingEnabled,
      'performanceTrackingEnabled': performanceTrackingEnabled,
      'autoDeleteEnabled': autoDeleteEnabled,
      'customRetentionPeriods': customRetentionPeriods.map(
        (key, value) => MapEntry(key, value.inMilliseconds),
      ),
      'anonymizeAnalytics': anonymizeAnalytics,
      'anonymizeExports': anonymizeExports,
      'removeSpeakerIds': removeSpeakerIds,
      'requireSecureDeletion': requireSecureDeletion,
      'encryptSensitiveData': encryptSensitiveData,
      'enableAccessLogging': enableAccessLogging,
      'hasAnalyticsConsent': hasAnalyticsConsent,
      'hasAIProcessingConsent': hasAIProcessingConsent,
      'hasDataExportConsent': hasDataExportConsent,
      'consentTimestamp': consentTimestamp?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory PrivacyConfig.fromJson(Map<String, dynamic> json) {
    return PrivacyConfig(
      analyticsEnabled: json['analyticsEnabled'] as bool? ?? true,
      aiAnalysisEnabled: json['aiAnalysisEnabled'] as bool? ?? true,
      errorReportingEnabled: json['errorReportingEnabled'] as bool? ?? true,
      performanceTrackingEnabled: json['performanceTrackingEnabled'] as bool? ?? true,
      autoDeleteEnabled: json['autoDeleteEnabled'] as bool? ?? true,
      customRetentionPeriods: (json['customRetentionPeriods'] as Map<String, dynamic>?)
              ?.map((key, value) => MapEntry(
                    key,
                    Duration(milliseconds: value as int),
                  )) ??
          {},
      anonymizeAnalytics: json['anonymizeAnalytics'] as bool? ?? false,
      anonymizeExports: json['anonymizeExports'] as bool? ?? true,
      removeSpeakerIds: json['removeSpeakerIds'] as bool? ?? false,
      requireSecureDeletion: json['requireSecureDeletion'] as bool? ?? true,
      encryptSensitiveData: json['encryptSensitiveData'] as bool? ?? false,
      enableAccessLogging: json['enableAccessLogging'] as bool? ?? false,
      hasAnalyticsConsent: json['hasAnalyticsConsent'] as bool? ?? false,
      hasAIProcessingConsent: json['hasAIProcessingConsent'] as bool? ?? false,
      hasDataExportConsent: json['hasDataExportConsent'] as bool? ?? false,
      consentTimestamp: json['consentTimestamp'] != null
          ? DateTime.parse(json['consentTimestamp'] as String)
          : null,
    );
  }

  @override
  String toString() {
    return 'PrivacyConfig(analytics: $analyticsEnabled, aiAnalysis: $aiAnalysisEnabled, autoDelete: $autoDeleteEnabled)';
  }
}

/// Data classification levels
enum DataSensitivity {
  /// Non-sensitive data (e.g., app version, device model)
  public,

  /// Internal data (e.g., performance metrics, usage stats)
  internal,

  /// Confidential data (e.g., user preferences, settings)
  confidential,

  /// Sensitive personal data (e.g., transcriptions, conversations)
  sensitive,

  /// Highly sensitive data (e.g., audio recordings, biometric data)
  critical,
}

/// Data type metadata
class DataTypeMetadata {
  final String name;
  final DataSensitivity sensitivity;
  final Duration defaultRetention;
  final bool requiresConsent;
  final bool canBeAnonymized;
  final bool requiresEncryption;

  const DataTypeMetadata({
    required this.name,
    required this.sensitivity,
    required this.defaultRetention,
    this.requiresConsent = false,
    this.canBeAnonymized = true,
    this.requiresEncryption = false,
  });
}

/// Registry of all data types in the application
class DataTypeRegistry {
  static const Map<String, DataTypeMetadata> dataTypes = {
    'audioRecordings': DataTypeMetadata(
      name: 'Audio Recordings',
      sensitivity: DataSensitivity.critical,
      defaultRetention: DataRetentionPeriods.audioRecordings,
      requiresConsent: true,
      canBeAnonymized: false,
      requiresEncryption: true,
    ),
    'transcriptions': DataTypeMetadata(
      name: 'Transcription Text',
      sensitivity: DataSensitivity.sensitive,
      defaultRetention: DataRetentionPeriods.transcriptionResults,
      requiresConsent: true,
      canBeAnonymized: true,
      requiresEncryption: true,
    ),
    'conversations': DataTypeMetadata(
      name: 'Conversation Data',
      sensitivity: DataSensitivity.sensitive,
      defaultRetention: DataRetentionPeriods.conversationMessages,
      requiresConsent: true,
      canBeAnonymized: true,
      requiresEncryption: false,
    ),
    'aiAnalysis': DataTypeMetadata(
      name: 'AI Analysis Results',
      sensitivity: DataSensitivity.confidential,
      defaultRetention: DataRetentionPeriods.factCheckResults,
      requiresConsent: true,
      canBeAnonymized: true,
      requiresEncryption: false,
    ),
    'analytics': DataTypeMetadata(
      name: 'Analytics Events',
      sensitivity: DataSensitivity.internal,
      defaultRetention: DataRetentionPeriods.analyticsEvents,
      requiresConsent: false,
      canBeAnonymized: true,
      requiresEncryption: false,
    ),
    'logs': DataTypeMetadata(
      name: 'Application Logs',
      sensitivity: DataSensitivity.internal,
      defaultRetention: DataRetentionPeriods.errorLogs,
      requiresConsent: false,
      canBeAnonymized: true,
      requiresEncryption: false,
    ),
    'bleMetrics': DataTypeMetadata(
      name: 'BLE Health Metrics',
      sensitivity: DataSensitivity.internal,
      defaultRetention: DataRetentionPeriods.bleHealthMetrics,
      requiresConsent: false,
      canBeAnonymized: true,
      requiresEncryption: false,
    ),
  };

  /// Get metadata for a data type
  static DataTypeMetadata? getMetadata(String dataType) {
    return dataTypes[dataType];
  }

  /// Get all data types requiring consent
  static List<String> getConsentRequiredTypes() {
    return dataTypes.entries
        .where((entry) => entry.value.requiresConsent)
        .map((entry) => entry.key)
        .toList();
  }

  /// Get all data types requiring encryption
  static List<String> getEncryptionRequiredTypes() {
    return dataTypes.entries
        .where((entry) => entry.value.requiresEncryption)
        .map((entry) => entry.key)
        .toList();
  }
}
