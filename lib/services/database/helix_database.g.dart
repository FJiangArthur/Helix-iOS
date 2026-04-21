// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'helix_database.dart';

// ignore_for_file: type=lint
class $ConversationsTable extends Conversations
    with TableInfo<$ConversationsTable, Conversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('general'),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sentimentMeta = const VerificationMeta(
    'sentiment',
  );
  @override
  late final GeneratedColumn<String> sentiment = GeneratedColumn<String>(
    'sentiment',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toneAnalysisMeta = const VerificationMeta(
    'toneAnalysis',
  );
  @override
  late final GeneratedColumn<String> toneAnalysis = GeneratedColumn<String>(
    'tone_analysis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isProcessedMeta = const VerificationMeta(
    'isProcessed',
  );
  @override
  late final GeneratedColumn<bool> isProcessed = GeneratedColumn<bool>(
    'is_processed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_processed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _silenceEndedMeta = const VerificationMeta(
    'silenceEnded',
  );
  @override
  late final GeneratedColumn<bool> silenceEnded = GeneratedColumn<bool>(
    'silence_ended',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("silence_ended" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('phone'),
  );
  static const VerificationMeta _audioFilePathMeta = const VerificationMeta(
    'audioFilePath',
  );
  @override
  late final GeneratedColumn<String> audioFilePath = GeneratedColumn<String>(
    'audio_file_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costSmartUsdMicrosMeta =
      const VerificationMeta('costSmartUsdMicros');
  @override
  late final GeneratedColumn<int> costSmartUsdMicros = GeneratedColumn<int>(
    'cost_smart_usd_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costLightUsdMicrosMeta =
      const VerificationMeta('costLightUsdMicros');
  @override
  late final GeneratedColumn<int> costLightUsdMicros = GeneratedColumn<int>(
    'cost_light_usd_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costTranscriptionUsdMicrosMeta =
      const VerificationMeta('costTranscriptionUsdMicros');
  @override
  late final GeneratedColumn<int> costTranscriptionUsdMicros =
      GeneratedColumn<int>(
        'cost_transcription_usd_micros',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _costTotalUsdMicrosMeta =
      const VerificationMeta('costTotalUsdMicros');
  @override
  late final GeneratedColumn<int> costTotalUsdMicros = GeneratedColumn<int>(
    'cost_total_usd_micros',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    startedAt,
    endedAt,
    mode,
    title,
    summary,
    sentiment,
    toneAnalysis,
    isProcessed,
    silenceEnded,
    source,
    audioFilePath,
    costSmartUsdMicros,
    costLightUsdMicros,
    costTranscriptionUsdMicros,
    costTotalUsdMicros,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<Conversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('sentiment')) {
      context.handle(
        _sentimentMeta,
        sentiment.isAcceptableOrUnknown(data['sentiment']!, _sentimentMeta),
      );
    }
    if (data.containsKey('tone_analysis')) {
      context.handle(
        _toneAnalysisMeta,
        toneAnalysis.isAcceptableOrUnknown(
          data['tone_analysis']!,
          _toneAnalysisMeta,
        ),
      );
    }
    if (data.containsKey('is_processed')) {
      context.handle(
        _isProcessedMeta,
        isProcessed.isAcceptableOrUnknown(
          data['is_processed']!,
          _isProcessedMeta,
        ),
      );
    }
    if (data.containsKey('silence_ended')) {
      context.handle(
        _silenceEndedMeta,
        silenceEnded.isAcceptableOrUnknown(
          data['silence_ended']!,
          _silenceEndedMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('audio_file_path')) {
      context.handle(
        _audioFilePathMeta,
        audioFilePath.isAcceptableOrUnknown(
          data['audio_file_path']!,
          _audioFilePathMeta,
        ),
      );
    }
    if (data.containsKey('cost_smart_usd_micros')) {
      context.handle(
        _costSmartUsdMicrosMeta,
        costSmartUsdMicros.isAcceptableOrUnknown(
          data['cost_smart_usd_micros']!,
          _costSmartUsdMicrosMeta,
        ),
      );
    }
    if (data.containsKey('cost_light_usd_micros')) {
      context.handle(
        _costLightUsdMicrosMeta,
        costLightUsdMicros.isAcceptableOrUnknown(
          data['cost_light_usd_micros']!,
          _costLightUsdMicrosMeta,
        ),
      );
    }
    if (data.containsKey('cost_transcription_usd_micros')) {
      context.handle(
        _costTranscriptionUsdMicrosMeta,
        costTranscriptionUsdMicros.isAcceptableOrUnknown(
          data['cost_transcription_usd_micros']!,
          _costTranscriptionUsdMicrosMeta,
        ),
      );
    }
    if (data.containsKey('cost_total_usd_micros')) {
      context.handle(
        _costTotalUsdMicrosMeta,
        costTotalUsdMicros.isAcceptableOrUnknown(
          data['cost_total_usd_micros']!,
          _costTotalUsdMicrosMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Conversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Conversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      sentiment: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sentiment'],
      ),
      toneAnalysis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tone_analysis'],
      ),
      isProcessed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_processed'],
      )!,
      silenceEnded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}silence_ended'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      audioFilePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}audio_file_path'],
      ),
      costSmartUsdMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_smart_usd_micros'],
      ),
      costLightUsdMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_light_usd_micros'],
      ),
      costTranscriptionUsdMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_transcription_usd_micros'],
      ),
      costTotalUsdMicros: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cost_total_usd_micros'],
      ),
    );
  }

  @override
  $ConversationsTable createAlias(String alias) {
    return $ConversationsTable(attachedDatabase, alias);
  }
}

class Conversation extends DataClass implements Insertable<Conversation> {
  final String id;
  final int startedAt;
  final int? endedAt;
  final String mode;
  final String? title;
  final String? summary;
  final String? sentiment;
  final String? toneAnalysis;
  final bool isProcessed;
  final bool silenceEnded;
  final String source;
  final String? audioFilePath;
  final int? costSmartUsdMicros;
  final int? costLightUsdMicros;
  final int? costTranscriptionUsdMicros;
  final int? costTotalUsdMicros;
  const Conversation({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.mode,
    this.title,
    this.summary,
    this.sentiment,
    this.toneAnalysis,
    required this.isProcessed,
    required this.silenceEnded,
    required this.source,
    this.audioFilePath,
    this.costSmartUsdMicros,
    this.costLightUsdMicros,
    this.costTranscriptionUsdMicros,
    this.costTotalUsdMicros,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<int>(endedAt);
    }
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || sentiment != null) {
      map['sentiment'] = Variable<String>(sentiment);
    }
    if (!nullToAbsent || toneAnalysis != null) {
      map['tone_analysis'] = Variable<String>(toneAnalysis);
    }
    map['is_processed'] = Variable<bool>(isProcessed);
    map['silence_ended'] = Variable<bool>(silenceEnded);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || audioFilePath != null) {
      map['audio_file_path'] = Variable<String>(audioFilePath);
    }
    if (!nullToAbsent || costSmartUsdMicros != null) {
      map['cost_smart_usd_micros'] = Variable<int>(costSmartUsdMicros);
    }
    if (!nullToAbsent || costLightUsdMicros != null) {
      map['cost_light_usd_micros'] = Variable<int>(costLightUsdMicros);
    }
    if (!nullToAbsent || costTranscriptionUsdMicros != null) {
      map['cost_transcription_usd_micros'] = Variable<int>(
        costTranscriptionUsdMicros,
      );
    }
    if (!nullToAbsent || costTotalUsdMicros != null) {
      map['cost_total_usd_micros'] = Variable<int>(costTotalUsdMicros);
    }
    return map;
  }

  ConversationsCompanion toCompanion(bool nullToAbsent) {
    return ConversationsCompanion(
      id: Value(id),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      mode: Value(mode),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      sentiment: sentiment == null && nullToAbsent
          ? const Value.absent()
          : Value(sentiment),
      toneAnalysis: toneAnalysis == null && nullToAbsent
          ? const Value.absent()
          : Value(toneAnalysis),
      isProcessed: Value(isProcessed),
      silenceEnded: Value(silenceEnded),
      source: Value(source),
      audioFilePath: audioFilePath == null && nullToAbsent
          ? const Value.absent()
          : Value(audioFilePath),
      costSmartUsdMicros: costSmartUsdMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(costSmartUsdMicros),
      costLightUsdMicros: costLightUsdMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(costLightUsdMicros),
      costTranscriptionUsdMicros:
          costTranscriptionUsdMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(costTranscriptionUsdMicros),
      costTotalUsdMicros: costTotalUsdMicros == null && nullToAbsent
          ? const Value.absent()
          : Value(costTotalUsdMicros),
    );
  }

  factory Conversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Conversation(
      id: serializer.fromJson<String>(json['id']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endedAt: serializer.fromJson<int?>(json['endedAt']),
      mode: serializer.fromJson<String>(json['mode']),
      title: serializer.fromJson<String?>(json['title']),
      summary: serializer.fromJson<String?>(json['summary']),
      sentiment: serializer.fromJson<String?>(json['sentiment']),
      toneAnalysis: serializer.fromJson<String?>(json['toneAnalysis']),
      isProcessed: serializer.fromJson<bool>(json['isProcessed']),
      silenceEnded: serializer.fromJson<bool>(json['silenceEnded']),
      source: serializer.fromJson<String>(json['source']),
      audioFilePath: serializer.fromJson<String?>(json['audioFilePath']),
      costSmartUsdMicros: serializer.fromJson<int?>(json['costSmartUsdMicros']),
      costLightUsdMicros: serializer.fromJson<int?>(json['costLightUsdMicros']),
      costTranscriptionUsdMicros: serializer.fromJson<int?>(
        json['costTranscriptionUsdMicros'],
      ),
      costTotalUsdMicros: serializer.fromJson<int?>(json['costTotalUsdMicros']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'startedAt': serializer.toJson<int>(startedAt),
      'endedAt': serializer.toJson<int?>(endedAt),
      'mode': serializer.toJson<String>(mode),
      'title': serializer.toJson<String?>(title),
      'summary': serializer.toJson<String?>(summary),
      'sentiment': serializer.toJson<String?>(sentiment),
      'toneAnalysis': serializer.toJson<String?>(toneAnalysis),
      'isProcessed': serializer.toJson<bool>(isProcessed),
      'silenceEnded': serializer.toJson<bool>(silenceEnded),
      'source': serializer.toJson<String>(source),
      'audioFilePath': serializer.toJson<String?>(audioFilePath),
      'costSmartUsdMicros': serializer.toJson<int?>(costSmartUsdMicros),
      'costLightUsdMicros': serializer.toJson<int?>(costLightUsdMicros),
      'costTranscriptionUsdMicros': serializer.toJson<int?>(
        costTranscriptionUsdMicros,
      ),
      'costTotalUsdMicros': serializer.toJson<int?>(costTotalUsdMicros),
    };
  }

  Conversation copyWith({
    String? id,
    int? startedAt,
    Value<int?> endedAt = const Value.absent(),
    String? mode,
    Value<String?> title = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    Value<String?> sentiment = const Value.absent(),
    Value<String?> toneAnalysis = const Value.absent(),
    bool? isProcessed,
    bool? silenceEnded,
    String? source,
    Value<String?> audioFilePath = const Value.absent(),
    Value<int?> costSmartUsdMicros = const Value.absent(),
    Value<int?> costLightUsdMicros = const Value.absent(),
    Value<int?> costTranscriptionUsdMicros = const Value.absent(),
    Value<int?> costTotalUsdMicros = const Value.absent(),
  }) => Conversation(
    id: id ?? this.id,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    mode: mode ?? this.mode,
    title: title.present ? title.value : this.title,
    summary: summary.present ? summary.value : this.summary,
    sentiment: sentiment.present ? sentiment.value : this.sentiment,
    toneAnalysis: toneAnalysis.present ? toneAnalysis.value : this.toneAnalysis,
    isProcessed: isProcessed ?? this.isProcessed,
    silenceEnded: silenceEnded ?? this.silenceEnded,
    source: source ?? this.source,
    audioFilePath: audioFilePath.present
        ? audioFilePath.value
        : this.audioFilePath,
    costSmartUsdMicros: costSmartUsdMicros.present
        ? costSmartUsdMicros.value
        : this.costSmartUsdMicros,
    costLightUsdMicros: costLightUsdMicros.present
        ? costLightUsdMicros.value
        : this.costLightUsdMicros,
    costTranscriptionUsdMicros: costTranscriptionUsdMicros.present
        ? costTranscriptionUsdMicros.value
        : this.costTranscriptionUsdMicros,
    costTotalUsdMicros: costTotalUsdMicros.present
        ? costTotalUsdMicros.value
        : this.costTotalUsdMicros,
  );
  Conversation copyWithCompanion(ConversationsCompanion data) {
    return Conversation(
      id: data.id.present ? data.id.value : this.id,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      mode: data.mode.present ? data.mode.value : this.mode,
      title: data.title.present ? data.title.value : this.title,
      summary: data.summary.present ? data.summary.value : this.summary,
      sentiment: data.sentiment.present ? data.sentiment.value : this.sentiment,
      toneAnalysis: data.toneAnalysis.present
          ? data.toneAnalysis.value
          : this.toneAnalysis,
      isProcessed: data.isProcessed.present
          ? data.isProcessed.value
          : this.isProcessed,
      silenceEnded: data.silenceEnded.present
          ? data.silenceEnded.value
          : this.silenceEnded,
      source: data.source.present ? data.source.value : this.source,
      audioFilePath: data.audioFilePath.present
          ? data.audioFilePath.value
          : this.audioFilePath,
      costSmartUsdMicros: data.costSmartUsdMicros.present
          ? data.costSmartUsdMicros.value
          : this.costSmartUsdMicros,
      costLightUsdMicros: data.costLightUsdMicros.present
          ? data.costLightUsdMicros.value
          : this.costLightUsdMicros,
      costTranscriptionUsdMicros: data.costTranscriptionUsdMicros.present
          ? data.costTranscriptionUsdMicros.value
          : this.costTranscriptionUsdMicros,
      costTotalUsdMicros: data.costTotalUsdMicros.present
          ? data.costTotalUsdMicros.value
          : this.costTotalUsdMicros,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Conversation(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('mode: $mode, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('sentiment: $sentiment, ')
          ..write('toneAnalysis: $toneAnalysis, ')
          ..write('isProcessed: $isProcessed, ')
          ..write('silenceEnded: $silenceEnded, ')
          ..write('source: $source, ')
          ..write('audioFilePath: $audioFilePath, ')
          ..write('costSmartUsdMicros: $costSmartUsdMicros, ')
          ..write('costLightUsdMicros: $costLightUsdMicros, ')
          ..write('costTranscriptionUsdMicros: $costTranscriptionUsdMicros, ')
          ..write('costTotalUsdMicros: $costTotalUsdMicros')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    startedAt,
    endedAt,
    mode,
    title,
    summary,
    sentiment,
    toneAnalysis,
    isProcessed,
    silenceEnded,
    source,
    audioFilePath,
    costSmartUsdMicros,
    costLightUsdMicros,
    costTranscriptionUsdMicros,
    costTotalUsdMicros,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Conversation &&
          other.id == this.id &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.mode == this.mode &&
          other.title == this.title &&
          other.summary == this.summary &&
          other.sentiment == this.sentiment &&
          other.toneAnalysis == this.toneAnalysis &&
          other.isProcessed == this.isProcessed &&
          other.silenceEnded == this.silenceEnded &&
          other.source == this.source &&
          other.audioFilePath == this.audioFilePath &&
          other.costSmartUsdMicros == this.costSmartUsdMicros &&
          other.costLightUsdMicros == this.costLightUsdMicros &&
          other.costTranscriptionUsdMicros == this.costTranscriptionUsdMicros &&
          other.costTotalUsdMicros == this.costTotalUsdMicros);
}

class ConversationsCompanion extends UpdateCompanion<Conversation> {
  final Value<String> id;
  final Value<int> startedAt;
  final Value<int?> endedAt;
  final Value<String> mode;
  final Value<String?> title;
  final Value<String?> summary;
  final Value<String?> sentiment;
  final Value<String?> toneAnalysis;
  final Value<bool> isProcessed;
  final Value<bool> silenceEnded;
  final Value<String> source;
  final Value<String?> audioFilePath;
  final Value<int?> costSmartUsdMicros;
  final Value<int?> costLightUsdMicros;
  final Value<int?> costTranscriptionUsdMicros;
  final Value<int?> costTotalUsdMicros;
  final Value<int> rowid;
  const ConversationsCompanion({
    this.id = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.mode = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.sentiment = const Value.absent(),
    this.toneAnalysis = const Value.absent(),
    this.isProcessed = const Value.absent(),
    this.silenceEnded = const Value.absent(),
    this.source = const Value.absent(),
    this.audioFilePath = const Value.absent(),
    this.costSmartUsdMicros = const Value.absent(),
    this.costLightUsdMicros = const Value.absent(),
    this.costTranscriptionUsdMicros = const Value.absent(),
    this.costTotalUsdMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationsCompanion.insert({
    required String id,
    required int startedAt,
    this.endedAt = const Value.absent(),
    this.mode = const Value.absent(),
    this.title = const Value.absent(),
    this.summary = const Value.absent(),
    this.sentiment = const Value.absent(),
    this.toneAnalysis = const Value.absent(),
    this.isProcessed = const Value.absent(),
    this.silenceEnded = const Value.absent(),
    this.source = const Value.absent(),
    this.audioFilePath = const Value.absent(),
    this.costSmartUsdMicros = const Value.absent(),
    this.costLightUsdMicros = const Value.absent(),
    this.costTranscriptionUsdMicros = const Value.absent(),
    this.costTotalUsdMicros = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       startedAt = Value(startedAt);
  static Insertable<Conversation> custom({
    Expression<String>? id,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<String>? mode,
    Expression<String>? title,
    Expression<String>? summary,
    Expression<String>? sentiment,
    Expression<String>? toneAnalysis,
    Expression<bool>? isProcessed,
    Expression<bool>? silenceEnded,
    Expression<String>? source,
    Expression<String>? audioFilePath,
    Expression<int>? costSmartUsdMicros,
    Expression<int>? costLightUsdMicros,
    Expression<int>? costTranscriptionUsdMicros,
    Expression<int>? costTotalUsdMicros,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (mode != null) 'mode': mode,
      if (title != null) 'title': title,
      if (summary != null) 'summary': summary,
      if (sentiment != null) 'sentiment': sentiment,
      if (toneAnalysis != null) 'tone_analysis': toneAnalysis,
      if (isProcessed != null) 'is_processed': isProcessed,
      if (silenceEnded != null) 'silence_ended': silenceEnded,
      if (source != null) 'source': source,
      if (audioFilePath != null) 'audio_file_path': audioFilePath,
      if (costSmartUsdMicros != null)
        'cost_smart_usd_micros': costSmartUsdMicros,
      if (costLightUsdMicros != null)
        'cost_light_usd_micros': costLightUsdMicros,
      if (costTranscriptionUsdMicros != null)
        'cost_transcription_usd_micros': costTranscriptionUsdMicros,
      if (costTotalUsdMicros != null)
        'cost_total_usd_micros': costTotalUsdMicros,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationsCompanion copyWith({
    Value<String>? id,
    Value<int>? startedAt,
    Value<int?>? endedAt,
    Value<String>? mode,
    Value<String?>? title,
    Value<String?>? summary,
    Value<String?>? sentiment,
    Value<String?>? toneAnalysis,
    Value<bool>? isProcessed,
    Value<bool>? silenceEnded,
    Value<String>? source,
    Value<String?>? audioFilePath,
    Value<int?>? costSmartUsdMicros,
    Value<int?>? costLightUsdMicros,
    Value<int?>? costTranscriptionUsdMicros,
    Value<int?>? costTotalUsdMicros,
    Value<int>? rowid,
  }) {
    return ConversationsCompanion(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      mode: mode ?? this.mode,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      sentiment: sentiment ?? this.sentiment,
      toneAnalysis: toneAnalysis ?? this.toneAnalysis,
      isProcessed: isProcessed ?? this.isProcessed,
      silenceEnded: silenceEnded ?? this.silenceEnded,
      source: source ?? this.source,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      costSmartUsdMicros: costSmartUsdMicros ?? this.costSmartUsdMicros,
      costLightUsdMicros: costLightUsdMicros ?? this.costLightUsdMicros,
      costTranscriptionUsdMicros:
          costTranscriptionUsdMicros ?? this.costTranscriptionUsdMicros,
      costTotalUsdMicros: costTotalUsdMicros ?? this.costTotalUsdMicros,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (sentiment.present) {
      map['sentiment'] = Variable<String>(sentiment.value);
    }
    if (toneAnalysis.present) {
      map['tone_analysis'] = Variable<String>(toneAnalysis.value);
    }
    if (isProcessed.present) {
      map['is_processed'] = Variable<bool>(isProcessed.value);
    }
    if (silenceEnded.present) {
      map['silence_ended'] = Variable<bool>(silenceEnded.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (audioFilePath.present) {
      map['audio_file_path'] = Variable<String>(audioFilePath.value);
    }
    if (costSmartUsdMicros.present) {
      map['cost_smart_usd_micros'] = Variable<int>(costSmartUsdMicros.value);
    }
    if (costLightUsdMicros.present) {
      map['cost_light_usd_micros'] = Variable<int>(costLightUsdMicros.value);
    }
    if (costTranscriptionUsdMicros.present) {
      map['cost_transcription_usd_micros'] = Variable<int>(
        costTranscriptionUsdMicros.value,
      );
    }
    if (costTotalUsdMicros.present) {
      map['cost_total_usd_micros'] = Variable<int>(costTotalUsdMicros.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationsCompanion(')
          ..write('id: $id, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('mode: $mode, ')
          ..write('title: $title, ')
          ..write('summary: $summary, ')
          ..write('sentiment: $sentiment, ')
          ..write('toneAnalysis: $toneAnalysis, ')
          ..write('isProcessed: $isProcessed, ')
          ..write('silenceEnded: $silenceEnded, ')
          ..write('source: $source, ')
          ..write('audioFilePath: $audioFilePath, ')
          ..write('costSmartUsdMicros: $costSmartUsdMicros, ')
          ..write('costLightUsdMicros: $costLightUsdMicros, ')
          ..write('costTranscriptionUsdMicros: $costTranscriptionUsdMicros, ')
          ..write('costTotalUsdMicros: $costTotalUsdMicros, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationSegmentsTable extends ConversationSegments
    with TableInfo<$ConversationSegmentsTable, ConversationSegment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationSegmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id)',
    ),
  );
  static const VerificationMeta _segmentIndexMeta = const VerificationMeta(
    'segmentIndex',
  );
  @override
  late final GeneratedColumn<int> segmentIndex = GeneratedColumn<int>(
    'segment_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _text_Meta = const VerificationMeta('text_');
  @override
  late final GeneratedColumn<String> text_ = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _speakerLabelMeta = const VerificationMeta(
    'speakerLabel',
  );
  @override
  late final GeneratedColumn<String> speakerLabel = GeneratedColumn<String>(
    'speaker_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _topicIdMeta = const VerificationMeta(
    'topicId',
  );
  @override
  late final GeneratedColumn<String> topicId = GeneratedColumn<String>(
    'topic_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    segmentIndex,
    text_,
    speakerLabel,
    startedAt,
    endedAt,
    topicId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_segments';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationSegment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('segment_index')) {
      context.handle(
        _segmentIndexMeta,
        segmentIndex.isAcceptableOrUnknown(
          data['segment_index']!,
          _segmentIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_segmentIndexMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _text_Meta,
        text_.isAcceptableOrUnknown(data['text']!, _text_Meta),
      );
    } else if (isInserting) {
      context.missing(_text_Meta);
    }
    if (data.containsKey('speaker_label')) {
      context.handle(
        _speakerLabelMeta,
        speakerLabel.isAcceptableOrUnknown(
          data['speaker_label']!,
          _speakerLabelMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('topic_id')) {
      context.handle(
        _topicIdMeta,
        topicId.isAcceptableOrUnknown(data['topic_id']!, _topicIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationSegment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationSegment(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      segmentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}segment_index'],
      )!,
      text_: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      speakerLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker_label'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ended_at'],
      ),
      topicId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic_id'],
      ),
    );
  }

  @override
  $ConversationSegmentsTable createAlias(String alias) {
    return $ConversationSegmentsTable(attachedDatabase, alias);
  }
}

class ConversationSegment extends DataClass
    implements Insertable<ConversationSegment> {
  final String id;
  final String conversationId;
  final int segmentIndex;
  final String text_;
  final String? speakerLabel;
  final int startedAt;
  final int? endedAt;
  final String? topicId;
  const ConversationSegment({
    required this.id,
    required this.conversationId,
    required this.segmentIndex,
    required this.text_,
    this.speakerLabel,
    required this.startedAt,
    this.endedAt,
    this.topicId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['segment_index'] = Variable<int>(segmentIndex);
    map['text'] = Variable<String>(text_);
    if (!nullToAbsent || speakerLabel != null) {
      map['speaker_label'] = Variable<String>(speakerLabel);
    }
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<int>(endedAt);
    }
    if (!nullToAbsent || topicId != null) {
      map['topic_id'] = Variable<String>(topicId);
    }
    return map;
  }

  ConversationSegmentsCompanion toCompanion(bool nullToAbsent) {
    return ConversationSegmentsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      segmentIndex: Value(segmentIndex),
      text_: Value(text_),
      speakerLabel: speakerLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(speakerLabel),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      topicId: topicId == null && nullToAbsent
          ? const Value.absent()
          : Value(topicId),
    );
  }

  factory ConversationSegment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationSegment(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      segmentIndex: serializer.fromJson<int>(json['segmentIndex']),
      text_: serializer.fromJson<String>(json['text_']),
      speakerLabel: serializer.fromJson<String?>(json['speakerLabel']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endedAt: serializer.fromJson<int?>(json['endedAt']),
      topicId: serializer.fromJson<String?>(json['topicId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'segmentIndex': serializer.toJson<int>(segmentIndex),
      'text_': serializer.toJson<String>(text_),
      'speakerLabel': serializer.toJson<String?>(speakerLabel),
      'startedAt': serializer.toJson<int>(startedAt),
      'endedAt': serializer.toJson<int?>(endedAt),
      'topicId': serializer.toJson<String?>(topicId),
    };
  }

  ConversationSegment copyWith({
    String? id,
    String? conversationId,
    int? segmentIndex,
    String? text_,
    Value<String?> speakerLabel = const Value.absent(),
    int? startedAt,
    Value<int?> endedAt = const Value.absent(),
    Value<String?> topicId = const Value.absent(),
  }) => ConversationSegment(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    segmentIndex: segmentIndex ?? this.segmentIndex,
    text_: text_ ?? this.text_,
    speakerLabel: speakerLabel.present ? speakerLabel.value : this.speakerLabel,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    topicId: topicId.present ? topicId.value : this.topicId,
  );
  ConversationSegment copyWithCompanion(ConversationSegmentsCompanion data) {
    return ConversationSegment(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      segmentIndex: data.segmentIndex.present
          ? data.segmentIndex.value
          : this.segmentIndex,
      text_: data.text_.present ? data.text_.value : this.text_,
      speakerLabel: data.speakerLabel.present
          ? data.speakerLabel.value
          : this.speakerLabel,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      topicId: data.topicId.present ? data.topicId.value : this.topicId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationSegment(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('segmentIndex: $segmentIndex, ')
          ..write('text_: $text_, ')
          ..write('speakerLabel: $speakerLabel, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('topicId: $topicId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    segmentIndex,
    text_,
    speakerLabel,
    startedAt,
    endedAt,
    topicId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationSegment &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.segmentIndex == this.segmentIndex &&
          other.text_ == this.text_ &&
          other.speakerLabel == this.speakerLabel &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.topicId == this.topicId);
}

class ConversationSegmentsCompanion
    extends UpdateCompanion<ConversationSegment> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<int> segmentIndex;
  final Value<String> text_;
  final Value<String?> speakerLabel;
  final Value<int> startedAt;
  final Value<int?> endedAt;
  final Value<String?> topicId;
  final Value<int> rowid;
  const ConversationSegmentsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.segmentIndex = const Value.absent(),
    this.text_ = const Value.absent(),
    this.speakerLabel = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.topicId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationSegmentsCompanion.insert({
    required String id,
    required String conversationId,
    required int segmentIndex,
    required String text_,
    this.speakerLabel = const Value.absent(),
    required int startedAt,
    this.endedAt = const Value.absent(),
    this.topicId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       segmentIndex = Value(segmentIndex),
       text_ = Value(text_),
       startedAt = Value(startedAt);
  static Insertable<ConversationSegment> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<int>? segmentIndex,
    Expression<String>? text_,
    Expression<String>? speakerLabel,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<String>? topicId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (segmentIndex != null) 'segment_index': segmentIndex,
      if (text_ != null) 'text': text_,
      if (speakerLabel != null) 'speaker_label': speakerLabel,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (topicId != null) 'topic_id': topicId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationSegmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<int>? segmentIndex,
    Value<String>? text_,
    Value<String?>? speakerLabel,
    Value<int>? startedAt,
    Value<int?>? endedAt,
    Value<String?>? topicId,
    Value<int>? rowid,
  }) {
    return ConversationSegmentsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      segmentIndex: segmentIndex ?? this.segmentIndex,
      text_: text_ ?? this.text_,
      speakerLabel: speakerLabel ?? this.speakerLabel,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      topicId: topicId ?? this.topicId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (segmentIndex.present) {
      map['segment_index'] = Variable<int>(segmentIndex.value);
    }
    if (text_.present) {
      map['text'] = Variable<String>(text_.value);
    }
    if (speakerLabel.present) {
      map['speaker_label'] = Variable<String>(speakerLabel.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (topicId.present) {
      map['topic_id'] = Variable<String>(topicId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationSegmentsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('segmentIndex: $segmentIndex, ')
          ..write('text_: $text_, ')
          ..write('speakerLabel: $speakerLabel, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('topicId: $topicId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationAiCostEntriesTable extends ConversationAiCostEntries
    with TableInfo<$ConversationAiCostEntriesTable, ConversationAiCostEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationAiCostEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id)',
    ),
  );
  static const VerificationMeta _operationTypeMeta = const VerificationMeta(
    'operationType',
  );
  @override
  late final GeneratedColumn<String> operationType = GeneratedColumn<String>(
    'operation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelIdMeta = const VerificationMeta(
    'modelId',
  );
  @override
  late final GeneratedColumn<String> modelId = GeneratedColumn<String>(
    'model_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputTokensMeta = const VerificationMeta(
    'inputTokens',
  );
  @override
  late final GeneratedColumn<int> inputTokens = GeneratedColumn<int>(
    'input_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _outputTokensMeta = const VerificationMeta(
    'outputTokens',
  );
  @override
  late final GeneratedColumn<int> outputTokens = GeneratedColumn<int>(
    'output_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _cachedInputTokensMeta = const VerificationMeta(
    'cachedInputTokens',
  );
  @override
  late final GeneratedColumn<int> cachedInputTokens = GeneratedColumn<int>(
    'cached_input_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _audioInputTokensMeta = const VerificationMeta(
    'audioInputTokens',
  );
  @override
  late final GeneratedColumn<int> audioInputTokens = GeneratedColumn<int>(
    'audio_input_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _audioOutputTokensMeta = const VerificationMeta(
    'audioOutputTokens',
  );
  @override
  late final GeneratedColumn<int> audioOutputTokens = GeneratedColumn<int>(
    'audio_output_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _costUsdMeta = const VerificationMeta(
    'costUsd',
  );
  @override
  late final GeneratedColumn<double> costUsd = GeneratedColumn<double>(
    'cost_usd',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currencyMeta = const VerificationMeta(
    'currency',
  );
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
    'currency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('USD'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('completed'),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modelRoleMeta = const VerificationMeta(
    'modelRole',
  );
  @override
  late final GeneratedColumn<String> modelRole = GeneratedColumn<String>(
    'model_role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    operationType,
    providerId,
    modelId,
    inputTokens,
    outputTokens,
    cachedInputTokens,
    audioInputTokens,
    audioOutputTokens,
    costUsd,
    currency,
    status,
    startedAt,
    completedAt,
    modelRole,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_ai_cost_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationAiCostEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('operation_type')) {
      context.handle(
        _operationTypeMeta,
        operationType.isAcceptableOrUnknown(
          data['operation_type']!,
          _operationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_operationTypeMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('model_id')) {
      context.handle(
        _modelIdMeta,
        modelId.isAcceptableOrUnknown(data['model_id']!, _modelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_modelIdMeta);
    }
    if (data.containsKey('input_tokens')) {
      context.handle(
        _inputTokensMeta,
        inputTokens.isAcceptableOrUnknown(
          data['input_tokens']!,
          _inputTokensMeta,
        ),
      );
    }
    if (data.containsKey('output_tokens')) {
      context.handle(
        _outputTokensMeta,
        outputTokens.isAcceptableOrUnknown(
          data['output_tokens']!,
          _outputTokensMeta,
        ),
      );
    }
    if (data.containsKey('cached_input_tokens')) {
      context.handle(
        _cachedInputTokensMeta,
        cachedInputTokens.isAcceptableOrUnknown(
          data['cached_input_tokens']!,
          _cachedInputTokensMeta,
        ),
      );
    }
    if (data.containsKey('audio_input_tokens')) {
      context.handle(
        _audioInputTokensMeta,
        audioInputTokens.isAcceptableOrUnknown(
          data['audio_input_tokens']!,
          _audioInputTokensMeta,
        ),
      );
    }
    if (data.containsKey('audio_output_tokens')) {
      context.handle(
        _audioOutputTokensMeta,
        audioOutputTokens.isAcceptableOrUnknown(
          data['audio_output_tokens']!,
          _audioOutputTokensMeta,
        ),
      );
    }
    if (data.containsKey('cost_usd')) {
      context.handle(
        _costUsdMeta,
        costUsd.isAcceptableOrUnknown(data['cost_usd']!, _costUsdMeta),
      );
    }
    if (data.containsKey('currency')) {
      context.handle(
        _currencyMeta,
        currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('model_role')) {
      context.handle(
        _modelRoleMeta,
        modelRole.isAcceptableOrUnknown(data['model_role']!, _modelRoleMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ConversationAiCostEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationAiCostEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      operationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation_type'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      modelId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_id'],
      )!,
      inputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}input_tokens'],
      )!,
      outputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}output_tokens'],
      )!,
      cachedInputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cached_input_tokens'],
      )!,
      audioInputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_input_tokens'],
      )!,
      audioOutputTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}audio_output_tokens'],
      )!,
      costUsd: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost_usd'],
      ),
      currency: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      modelRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_role'],
      ),
    );
  }

  @override
  $ConversationAiCostEntriesTable createAlias(String alias) {
    return $ConversationAiCostEntriesTable(attachedDatabase, alias);
  }
}

class ConversationAiCostEntry extends DataClass
    implements Insertable<ConversationAiCostEntry> {
  final String id;
  final String conversationId;
  final String operationType;
  final String providerId;
  final String modelId;
  final int inputTokens;
  final int outputTokens;
  final int cachedInputTokens;
  final int audioInputTokens;
  final int audioOutputTokens;
  final double? costUsd;
  final String currency;
  final String status;
  final int startedAt;
  final int? completedAt;
  final String? modelRole;
  const ConversationAiCostEntry({
    required this.id,
    required this.conversationId,
    required this.operationType,
    required this.providerId,
    required this.modelId,
    required this.inputTokens,
    required this.outputTokens,
    required this.cachedInputTokens,
    required this.audioInputTokens,
    required this.audioOutputTokens,
    this.costUsd,
    required this.currency,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.modelRole,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['operation_type'] = Variable<String>(operationType);
    map['provider_id'] = Variable<String>(providerId);
    map['model_id'] = Variable<String>(modelId);
    map['input_tokens'] = Variable<int>(inputTokens);
    map['output_tokens'] = Variable<int>(outputTokens);
    map['cached_input_tokens'] = Variable<int>(cachedInputTokens);
    map['audio_input_tokens'] = Variable<int>(audioInputTokens);
    map['audio_output_tokens'] = Variable<int>(audioOutputTokens);
    if (!nullToAbsent || costUsd != null) {
      map['cost_usd'] = Variable<double>(costUsd);
    }
    map['currency'] = Variable<String>(currency);
    map['status'] = Variable<String>(status);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    if (!nullToAbsent || modelRole != null) {
      map['model_role'] = Variable<String>(modelRole);
    }
    return map;
  }

  ConversationAiCostEntriesCompanion toCompanion(bool nullToAbsent) {
    return ConversationAiCostEntriesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      operationType: Value(operationType),
      providerId: Value(providerId),
      modelId: Value(modelId),
      inputTokens: Value(inputTokens),
      outputTokens: Value(outputTokens),
      cachedInputTokens: Value(cachedInputTokens),
      audioInputTokens: Value(audioInputTokens),
      audioOutputTokens: Value(audioOutputTokens),
      costUsd: costUsd == null && nullToAbsent
          ? const Value.absent()
          : Value(costUsd),
      currency: Value(currency),
      status: Value(status),
      startedAt: Value(startedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      modelRole: modelRole == null && nullToAbsent
          ? const Value.absent()
          : Value(modelRole),
    );
  }

  factory ConversationAiCostEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationAiCostEntry(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      operationType: serializer.fromJson<String>(json['operationType']),
      providerId: serializer.fromJson<String>(json['providerId']),
      modelId: serializer.fromJson<String>(json['modelId']),
      inputTokens: serializer.fromJson<int>(json['inputTokens']),
      outputTokens: serializer.fromJson<int>(json['outputTokens']),
      cachedInputTokens: serializer.fromJson<int>(json['cachedInputTokens']),
      audioInputTokens: serializer.fromJson<int>(json['audioInputTokens']),
      audioOutputTokens: serializer.fromJson<int>(json['audioOutputTokens']),
      costUsd: serializer.fromJson<double?>(json['costUsd']),
      currency: serializer.fromJson<String>(json['currency']),
      status: serializer.fromJson<String>(json['status']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      modelRole: serializer.fromJson<String?>(json['modelRole']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'operationType': serializer.toJson<String>(operationType),
      'providerId': serializer.toJson<String>(providerId),
      'modelId': serializer.toJson<String>(modelId),
      'inputTokens': serializer.toJson<int>(inputTokens),
      'outputTokens': serializer.toJson<int>(outputTokens),
      'cachedInputTokens': serializer.toJson<int>(cachedInputTokens),
      'audioInputTokens': serializer.toJson<int>(audioInputTokens),
      'audioOutputTokens': serializer.toJson<int>(audioOutputTokens),
      'costUsd': serializer.toJson<double?>(costUsd),
      'currency': serializer.toJson<String>(currency),
      'status': serializer.toJson<String>(status),
      'startedAt': serializer.toJson<int>(startedAt),
      'completedAt': serializer.toJson<int?>(completedAt),
      'modelRole': serializer.toJson<String?>(modelRole),
    };
  }

  ConversationAiCostEntry copyWith({
    String? id,
    String? conversationId,
    String? operationType,
    String? providerId,
    String? modelId,
    int? inputTokens,
    int? outputTokens,
    int? cachedInputTokens,
    int? audioInputTokens,
    int? audioOutputTokens,
    Value<double?> costUsd = const Value.absent(),
    String? currency,
    String? status,
    int? startedAt,
    Value<int?> completedAt = const Value.absent(),
    Value<String?> modelRole = const Value.absent(),
  }) => ConversationAiCostEntry(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    operationType: operationType ?? this.operationType,
    providerId: providerId ?? this.providerId,
    modelId: modelId ?? this.modelId,
    inputTokens: inputTokens ?? this.inputTokens,
    outputTokens: outputTokens ?? this.outputTokens,
    cachedInputTokens: cachedInputTokens ?? this.cachedInputTokens,
    audioInputTokens: audioInputTokens ?? this.audioInputTokens,
    audioOutputTokens: audioOutputTokens ?? this.audioOutputTokens,
    costUsd: costUsd.present ? costUsd.value : this.costUsd,
    currency: currency ?? this.currency,
    status: status ?? this.status,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    modelRole: modelRole.present ? modelRole.value : this.modelRole,
  );
  ConversationAiCostEntry copyWithCompanion(
    ConversationAiCostEntriesCompanion data,
  ) {
    return ConversationAiCostEntry(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      operationType: data.operationType.present
          ? data.operationType.value
          : this.operationType,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      modelId: data.modelId.present ? data.modelId.value : this.modelId,
      inputTokens: data.inputTokens.present
          ? data.inputTokens.value
          : this.inputTokens,
      outputTokens: data.outputTokens.present
          ? data.outputTokens.value
          : this.outputTokens,
      cachedInputTokens: data.cachedInputTokens.present
          ? data.cachedInputTokens.value
          : this.cachedInputTokens,
      audioInputTokens: data.audioInputTokens.present
          ? data.audioInputTokens.value
          : this.audioInputTokens,
      audioOutputTokens: data.audioOutputTokens.present
          ? data.audioOutputTokens.value
          : this.audioOutputTokens,
      costUsd: data.costUsd.present ? data.costUsd.value : this.costUsd,
      currency: data.currency.present ? data.currency.value : this.currency,
      status: data.status.present ? data.status.value : this.status,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      modelRole: data.modelRole.present ? data.modelRole.value : this.modelRole,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationAiCostEntry(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('operationType: $operationType, ')
          ..write('providerId: $providerId, ')
          ..write('modelId: $modelId, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('cachedInputTokens: $cachedInputTokens, ')
          ..write('audioInputTokens: $audioInputTokens, ')
          ..write('audioOutputTokens: $audioOutputTokens, ')
          ..write('costUsd: $costUsd, ')
          ..write('currency: $currency, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('modelRole: $modelRole')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    operationType,
    providerId,
    modelId,
    inputTokens,
    outputTokens,
    cachedInputTokens,
    audioInputTokens,
    audioOutputTokens,
    costUsd,
    currency,
    status,
    startedAt,
    completedAt,
    modelRole,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationAiCostEntry &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.operationType == this.operationType &&
          other.providerId == this.providerId &&
          other.modelId == this.modelId &&
          other.inputTokens == this.inputTokens &&
          other.outputTokens == this.outputTokens &&
          other.cachedInputTokens == this.cachedInputTokens &&
          other.audioInputTokens == this.audioInputTokens &&
          other.audioOutputTokens == this.audioOutputTokens &&
          other.costUsd == this.costUsd &&
          other.currency == this.currency &&
          other.status == this.status &&
          other.startedAt == this.startedAt &&
          other.completedAt == this.completedAt &&
          other.modelRole == this.modelRole);
}

class ConversationAiCostEntriesCompanion
    extends UpdateCompanion<ConversationAiCostEntry> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> operationType;
  final Value<String> providerId;
  final Value<String> modelId;
  final Value<int> inputTokens;
  final Value<int> outputTokens;
  final Value<int> cachedInputTokens;
  final Value<int> audioInputTokens;
  final Value<int> audioOutputTokens;
  final Value<double?> costUsd;
  final Value<String> currency;
  final Value<String> status;
  final Value<int> startedAt;
  final Value<int?> completedAt;
  final Value<String?> modelRole;
  final Value<int> rowid;
  const ConversationAiCostEntriesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.operationType = const Value.absent(),
    this.providerId = const Value.absent(),
    this.modelId = const Value.absent(),
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.cachedInputTokens = const Value.absent(),
    this.audioInputTokens = const Value.absent(),
    this.audioOutputTokens = const Value.absent(),
    this.costUsd = const Value.absent(),
    this.currency = const Value.absent(),
    this.status = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.modelRole = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationAiCostEntriesCompanion.insert({
    required String id,
    required String conversationId,
    required String operationType,
    required String providerId,
    required String modelId,
    this.inputTokens = const Value.absent(),
    this.outputTokens = const Value.absent(),
    this.cachedInputTokens = const Value.absent(),
    this.audioInputTokens = const Value.absent(),
    this.audioOutputTokens = const Value.absent(),
    this.costUsd = const Value.absent(),
    this.currency = const Value.absent(),
    this.status = const Value.absent(),
    required int startedAt,
    this.completedAt = const Value.absent(),
    this.modelRole = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       operationType = Value(operationType),
       providerId = Value(providerId),
       modelId = Value(modelId),
       startedAt = Value(startedAt);
  static Insertable<ConversationAiCostEntry> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? operationType,
    Expression<String>? providerId,
    Expression<String>? modelId,
    Expression<int>? inputTokens,
    Expression<int>? outputTokens,
    Expression<int>? cachedInputTokens,
    Expression<int>? audioInputTokens,
    Expression<int>? audioOutputTokens,
    Expression<double>? costUsd,
    Expression<String>? currency,
    Expression<String>? status,
    Expression<int>? startedAt,
    Expression<int>? completedAt,
    Expression<String>? modelRole,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (operationType != null) 'operation_type': operationType,
      if (providerId != null) 'provider_id': providerId,
      if (modelId != null) 'model_id': modelId,
      if (inputTokens != null) 'input_tokens': inputTokens,
      if (outputTokens != null) 'output_tokens': outputTokens,
      if (cachedInputTokens != null) 'cached_input_tokens': cachedInputTokens,
      if (audioInputTokens != null) 'audio_input_tokens': audioInputTokens,
      if (audioOutputTokens != null) 'audio_output_tokens': audioOutputTokens,
      if (costUsd != null) 'cost_usd': costUsd,
      if (currency != null) 'currency': currency,
      if (status != null) 'status': status,
      if (startedAt != null) 'started_at': startedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (modelRole != null) 'model_role': modelRole,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationAiCostEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? operationType,
    Value<String>? providerId,
    Value<String>? modelId,
    Value<int>? inputTokens,
    Value<int>? outputTokens,
    Value<int>? cachedInputTokens,
    Value<int>? audioInputTokens,
    Value<int>? audioOutputTokens,
    Value<double?>? costUsd,
    Value<String>? currency,
    Value<String>? status,
    Value<int>? startedAt,
    Value<int?>? completedAt,
    Value<String?>? modelRole,
    Value<int>? rowid,
  }) {
    return ConversationAiCostEntriesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      operationType: operationType ?? this.operationType,
      providerId: providerId ?? this.providerId,
      modelId: modelId ?? this.modelId,
      inputTokens: inputTokens ?? this.inputTokens,
      outputTokens: outputTokens ?? this.outputTokens,
      cachedInputTokens: cachedInputTokens ?? this.cachedInputTokens,
      audioInputTokens: audioInputTokens ?? this.audioInputTokens,
      audioOutputTokens: audioOutputTokens ?? this.audioOutputTokens,
      costUsd: costUsd ?? this.costUsd,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      modelRole: modelRole ?? this.modelRole,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (operationType.present) {
      map['operation_type'] = Variable<String>(operationType.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (modelId.present) {
      map['model_id'] = Variable<String>(modelId.value);
    }
    if (inputTokens.present) {
      map['input_tokens'] = Variable<int>(inputTokens.value);
    }
    if (outputTokens.present) {
      map['output_tokens'] = Variable<int>(outputTokens.value);
    }
    if (cachedInputTokens.present) {
      map['cached_input_tokens'] = Variable<int>(cachedInputTokens.value);
    }
    if (audioInputTokens.present) {
      map['audio_input_tokens'] = Variable<int>(audioInputTokens.value);
    }
    if (audioOutputTokens.present) {
      map['audio_output_tokens'] = Variable<int>(audioOutputTokens.value);
    }
    if (costUsd.present) {
      map['cost_usd'] = Variable<double>(costUsd.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (modelRole.present) {
      map['model_role'] = Variable<String>(modelRole.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationAiCostEntriesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('operationType: $operationType, ')
          ..write('providerId: $providerId, ')
          ..write('modelId: $modelId, ')
          ..write('inputTokens: $inputTokens, ')
          ..write('outputTokens: $outputTokens, ')
          ..write('cachedInputTokens: $cachedInputTokens, ')
          ..write('audioInputTokens: $audioInputTokens, ')
          ..write('audioOutputTokens: $audioOutputTokens, ')
          ..write('costUsd: $costUsd, ')
          ..write('currency: $currency, ')
          ..write('status: $status, ')
          ..write('startedAt: $startedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('modelRole: $modelRole, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TopicsTable extends Topics with TableInfo<$TopicsTable, Topic> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TopicsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES conversations (id)',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _segmentRangeMeta = const VerificationMeta(
    'segmentRange',
  );
  @override
  late final GeneratedColumn<String> segmentRange = GeneratedColumn<String>(
    'segment_range',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    label,
    summary,
    segmentRange,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'topics';
  @override
  VerificationContext validateIntegrity(
    Insertable<Topic> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('segment_range')) {
      context.handle(
        _segmentRangeMeta,
        segmentRange.isAcceptableOrUnknown(
          data['segment_range']!,
          _segmentRangeMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Topic map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Topic(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      )!,
      segmentRange: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}segment_range'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $TopicsTable createAlias(String alias) {
    return $TopicsTable(attachedDatabase, alias);
  }
}

class Topic extends DataClass implements Insertable<Topic> {
  final String id;
  final String conversationId;
  final String label;
  final String summary;
  final String segmentRange;
  final int sortOrder;
  const Topic({
    required this.id,
    required this.conversationId,
    required this.label,
    required this.summary,
    required this.segmentRange,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['label'] = Variable<String>(label);
    map['summary'] = Variable<String>(summary);
    map['segment_range'] = Variable<String>(segmentRange);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  TopicsCompanion toCompanion(bool nullToAbsent) {
    return TopicsCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      label: Value(label),
      summary: Value(summary),
      segmentRange: Value(segmentRange),
      sortOrder: Value(sortOrder),
    );
  }

  factory Topic.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Topic(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      label: serializer.fromJson<String>(json['label']),
      summary: serializer.fromJson<String>(json['summary']),
      segmentRange: serializer.fromJson<String>(json['segmentRange']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'label': serializer.toJson<String>(label),
      'summary': serializer.toJson<String>(summary),
      'segmentRange': serializer.toJson<String>(segmentRange),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  Topic copyWith({
    String? id,
    String? conversationId,
    String? label,
    String? summary,
    String? segmentRange,
    int? sortOrder,
  }) => Topic(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    label: label ?? this.label,
    summary: summary ?? this.summary,
    segmentRange: segmentRange ?? this.segmentRange,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  Topic copyWithCompanion(TopicsCompanion data) {
    return Topic(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      label: data.label.present ? data.label.value : this.label,
      summary: data.summary.present ? data.summary.value : this.summary,
      segmentRange: data.segmentRange.present
          ? data.segmentRange.value
          : this.segmentRange,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Topic(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('label: $label, ')
          ..write('summary: $summary, ')
          ..write('segmentRange: $segmentRange, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, conversationId, label, summary, segmentRange, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Topic &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.label == this.label &&
          other.summary == this.summary &&
          other.segmentRange == this.segmentRange &&
          other.sortOrder == this.sortOrder);
}

class TopicsCompanion extends UpdateCompanion<Topic> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> label;
  final Value<String> summary;
  final Value<String> segmentRange;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const TopicsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.label = const Value.absent(),
    this.summary = const Value.absent(),
    this.segmentRange = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TopicsCompanion.insert({
    required String id,
    required String conversationId,
    required String label,
    this.summary = const Value.absent(),
    this.segmentRange = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       label = Value(label);
  static Insertable<Topic> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? label,
    Expression<String>? summary,
    Expression<String>? segmentRange,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (label != null) 'label': label,
      if (summary != null) 'summary': summary,
      if (segmentRange != null) 'segment_range': segmentRange,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TopicsCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? label,
    Value<String>? summary,
    Value<String>? segmentRange,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return TopicsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      label: label ?? this.label,
      summary: summary ?? this.summary,
      segmentRange: segmentRange ?? this.segmentRange,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (segmentRange.present) {
      map['segment_range'] = Variable<String>(segmentRange.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TopicsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('label: $label, ')
          ..write('summary: $summary, ')
          ..write('segmentRange: $segmentRange, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FactsTable extends Facts with TableInfo<$FactsTable, Fact> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FactsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceQuoteMeta = const VerificationMeta(
    'sourceQuote',
  );
  @override
  late final GeneratedColumn<String> sourceQuote = GeneratedColumn<String>(
    'source_quote',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confirmedAtMeta = const VerificationMeta(
    'confirmedAt',
  );
  @override
  late final GeneratedColumn<int> confirmedAt = GeneratedColumn<int>(
    'confirmed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    category,
    content,
    sourceQuote,
    confidence,
    status,
    dedupeKey,
    createdAt,
    confirmedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'facts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Fact> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('source_quote')) {
      context.handle(
        _sourceQuoteMeta,
        sourceQuote.isAcceptableOrUnknown(
          data['source_quote']!,
          _sourceQuoteMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('confirmed_at')) {
      context.handle(
        _confirmedAtMeta,
        confirmedAt.isAcceptableOrUnknown(
          data['confirmed_at']!,
          _confirmedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Fact map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Fact(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      sourceQuote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_quote'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      confirmedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}confirmed_at'],
      ),
    );
  }

  @override
  $FactsTable createAlias(String alias) {
    return $FactsTable(attachedDatabase, alias);
  }
}

class Fact extends DataClass implements Insertable<Fact> {
  final String id;
  final String? conversationId;
  final String category;
  final String content;
  final String? sourceQuote;
  final double confidence;
  final String status;
  final String? dedupeKey;
  final int createdAt;
  final int? confirmedAt;
  const Fact({
    required this.id,
    this.conversationId,
    required this.category,
    required this.content,
    this.sourceQuote,
    required this.confidence,
    required this.status,
    this.dedupeKey,
    required this.createdAt,
    this.confirmedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<String>(conversationId);
    }
    map['category'] = Variable<String>(category);
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || sourceQuote != null) {
      map['source_quote'] = Variable<String>(sourceQuote);
    }
    map['confidence'] = Variable<double>(confidence);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || dedupeKey != null) {
      map['dedupe_key'] = Variable<String>(dedupeKey);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || confirmedAt != null) {
      map['confirmed_at'] = Variable<int>(confirmedAt);
    }
    return map;
  }

  FactsCompanion toCompanion(bool nullToAbsent) {
    return FactsCompanion(
      id: Value(id),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      category: Value(category),
      content: Value(content),
      sourceQuote: sourceQuote == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceQuote),
      confidence: Value(confidence),
      status: Value(status),
      dedupeKey: dedupeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(dedupeKey),
      createdAt: Value(createdAt),
      confirmedAt: confirmedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(confirmedAt),
    );
  }

  factory Fact.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Fact(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String?>(json['conversationId']),
      category: serializer.fromJson<String>(json['category']),
      content: serializer.fromJson<String>(json['content']),
      sourceQuote: serializer.fromJson<String?>(json['sourceQuote']),
      confidence: serializer.fromJson<double>(json['confidence']),
      status: serializer.fromJson<String>(json['status']),
      dedupeKey: serializer.fromJson<String?>(json['dedupeKey']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      confirmedAt: serializer.fromJson<int?>(json['confirmedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String?>(conversationId),
      'category': serializer.toJson<String>(category),
      'content': serializer.toJson<String>(content),
      'sourceQuote': serializer.toJson<String?>(sourceQuote),
      'confidence': serializer.toJson<double>(confidence),
      'status': serializer.toJson<String>(status),
      'dedupeKey': serializer.toJson<String?>(dedupeKey),
      'createdAt': serializer.toJson<int>(createdAt),
      'confirmedAt': serializer.toJson<int?>(confirmedAt),
    };
  }

  Fact copyWith({
    String? id,
    Value<String?> conversationId = const Value.absent(),
    String? category,
    String? content,
    Value<String?> sourceQuote = const Value.absent(),
    double? confidence,
    String? status,
    Value<String?> dedupeKey = const Value.absent(),
    int? createdAt,
    Value<int?> confirmedAt = const Value.absent(),
  }) => Fact(
    id: id ?? this.id,
    conversationId: conversationId.present
        ? conversationId.value
        : this.conversationId,
    category: category ?? this.category,
    content: content ?? this.content,
    sourceQuote: sourceQuote.present ? sourceQuote.value : this.sourceQuote,
    confidence: confidence ?? this.confidence,
    status: status ?? this.status,
    dedupeKey: dedupeKey.present ? dedupeKey.value : this.dedupeKey,
    createdAt: createdAt ?? this.createdAt,
    confirmedAt: confirmedAt.present ? confirmedAt.value : this.confirmedAt,
  );
  Fact copyWithCompanion(FactsCompanion data) {
    return Fact(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      category: data.category.present ? data.category.value : this.category,
      content: data.content.present ? data.content.value : this.content,
      sourceQuote: data.sourceQuote.present
          ? data.sourceQuote.value
          : this.sourceQuote,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      status: data.status.present ? data.status.value : this.status,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      confirmedAt: data.confirmedAt.present
          ? data.confirmedAt.value
          : this.confirmedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Fact(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('category: $category, ')
          ..write('content: $content, ')
          ..write('sourceQuote: $sourceQuote, ')
          ..write('confidence: $confidence, ')
          ..write('status: $status, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('confirmedAt: $confirmedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    category,
    content,
    sourceQuote,
    confidence,
    status,
    dedupeKey,
    createdAt,
    confirmedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Fact &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.category == this.category &&
          other.content == this.content &&
          other.sourceQuote == this.sourceQuote &&
          other.confidence == this.confidence &&
          other.status == this.status &&
          other.dedupeKey == this.dedupeKey &&
          other.createdAt == this.createdAt &&
          other.confirmedAt == this.confirmedAt);
}

class FactsCompanion extends UpdateCompanion<Fact> {
  final Value<String> id;
  final Value<String?> conversationId;
  final Value<String> category;
  final Value<String> content;
  final Value<String?> sourceQuote;
  final Value<double> confidence;
  final Value<String> status;
  final Value<String?> dedupeKey;
  final Value<int> createdAt;
  final Value<int?> confirmedAt;
  final Value<int> rowid;
  const FactsCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.category = const Value.absent(),
    this.content = const Value.absent(),
    this.sourceQuote = const Value.absent(),
    this.confidence = const Value.absent(),
    this.status = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.confirmedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FactsCompanion.insert({
    required String id,
    this.conversationId = const Value.absent(),
    required String category,
    required String content,
    this.sourceQuote = const Value.absent(),
    this.confidence = const Value.absent(),
    this.status = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    required int createdAt,
    this.confirmedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       category = Value(category),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<Fact> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? category,
    Expression<String>? content,
    Expression<String>? sourceQuote,
    Expression<double>? confidence,
    Expression<String>? status,
    Expression<String>? dedupeKey,
    Expression<int>? createdAt,
    Expression<int>? confirmedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (category != null) 'category': category,
      if (content != null) 'content': content,
      if (sourceQuote != null) 'source_quote': sourceQuote,
      if (confidence != null) 'confidence': confidence,
      if (status != null) 'status': status,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (createdAt != null) 'created_at': createdAt,
      if (confirmedAt != null) 'confirmed_at': confirmedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FactsCompanion copyWith({
    Value<String>? id,
    Value<String?>? conversationId,
    Value<String>? category,
    Value<String>? content,
    Value<String?>? sourceQuote,
    Value<double>? confidence,
    Value<String>? status,
    Value<String?>? dedupeKey,
    Value<int>? createdAt,
    Value<int?>? confirmedAt,
    Value<int>? rowid,
  }) {
    return FactsCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      category: category ?? this.category,
      content: content ?? this.content,
      sourceQuote: sourceQuote ?? this.sourceQuote,
      confidence: confidence ?? this.confidence,
      status: status ?? this.status,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (sourceQuote.present) {
      map['source_quote'] = Variable<String>(sourceQuote.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (confirmedAt.present) {
      map['confirmed_at'] = Variable<int>(confirmedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FactsCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('category: $category, ')
          ..write('content: $content, ')
          ..write('sourceQuote: $sourceQuote, ')
          ..write('confidence: $confidence, ')
          ..write('status: $status, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('createdAt: $createdAt, ')
          ..write('confirmedAt: $confirmedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyMemoriesTable extends DailyMemories
    with TableInfo<$DailyMemoriesTable, DailyMemory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyMemoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _narrativeMeta = const VerificationMeta(
    'narrative',
  );
  @override
  late final GeneratedColumn<String> narrative = GeneratedColumn<String>(
    'narrative',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _themesMeta = const VerificationMeta('themes');
  @override
  late final GeneratedColumn<String> themes = GeneratedColumn<String>(
    'themes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _conversationIdsMeta = const VerificationMeta(
    'conversationIds',
  );
  @override
  late final GeneratedColumn<String> conversationIds = GeneratedColumn<String>(
    'conversation_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _generatedAtMeta = const VerificationMeta(
    'generatedAt',
  );
  @override
  late final GeneratedColumn<int> generatedAt = GeneratedColumn<int>(
    'generated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    narrative,
    themes,
    conversationIds,
    generatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_memories';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyMemory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('narrative')) {
      context.handle(
        _narrativeMeta,
        narrative.isAcceptableOrUnknown(data['narrative']!, _narrativeMeta),
      );
    } else if (isInserting) {
      context.missing(_narrativeMeta);
    }
    if (data.containsKey('themes')) {
      context.handle(
        _themesMeta,
        themes.isAcceptableOrUnknown(data['themes']!, _themesMeta),
      );
    }
    if (data.containsKey('conversation_ids')) {
      context.handle(
        _conversationIdsMeta,
        conversationIds.isAcceptableOrUnknown(
          data['conversation_ids']!,
          _conversationIdsMeta,
        ),
      );
    }
    if (data.containsKey('generated_at')) {
      context.handle(
        _generatedAtMeta,
        generatedAt.isAcceptableOrUnknown(
          data['generated_at']!,
          _generatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailyMemory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyMemory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      narrative: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}narrative'],
      )!,
      themes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}themes'],
      )!,
      conversationIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_ids'],
      )!,
      generatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generated_at'],
      )!,
    );
  }

  @override
  $DailyMemoriesTable createAlias(String alias) {
    return $DailyMemoriesTable(attachedDatabase, alias);
  }
}

class DailyMemory extends DataClass implements Insertable<DailyMemory> {
  final String id;
  final String date;
  final String narrative;
  final String themes;
  final String conversationIds;
  final int generatedAt;
  const DailyMemory({
    required this.id,
    required this.date,
    required this.narrative,
    required this.themes,
    required this.conversationIds,
    required this.generatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['date'] = Variable<String>(date);
    map['narrative'] = Variable<String>(narrative);
    map['themes'] = Variable<String>(themes);
    map['conversation_ids'] = Variable<String>(conversationIds);
    map['generated_at'] = Variable<int>(generatedAt);
    return map;
  }

  DailyMemoriesCompanion toCompanion(bool nullToAbsent) {
    return DailyMemoriesCompanion(
      id: Value(id),
      date: Value(date),
      narrative: Value(narrative),
      themes: Value(themes),
      conversationIds: Value(conversationIds),
      generatedAt: Value(generatedAt),
    );
  }

  factory DailyMemory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyMemory(
      id: serializer.fromJson<String>(json['id']),
      date: serializer.fromJson<String>(json['date']),
      narrative: serializer.fromJson<String>(json['narrative']),
      themes: serializer.fromJson<String>(json['themes']),
      conversationIds: serializer.fromJson<String>(json['conversationIds']),
      generatedAt: serializer.fromJson<int>(json['generatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'date': serializer.toJson<String>(date),
      'narrative': serializer.toJson<String>(narrative),
      'themes': serializer.toJson<String>(themes),
      'conversationIds': serializer.toJson<String>(conversationIds),
      'generatedAt': serializer.toJson<int>(generatedAt),
    };
  }

  DailyMemory copyWith({
    String? id,
    String? date,
    String? narrative,
    String? themes,
    String? conversationIds,
    int? generatedAt,
  }) => DailyMemory(
    id: id ?? this.id,
    date: date ?? this.date,
    narrative: narrative ?? this.narrative,
    themes: themes ?? this.themes,
    conversationIds: conversationIds ?? this.conversationIds,
    generatedAt: generatedAt ?? this.generatedAt,
  );
  DailyMemory copyWithCompanion(DailyMemoriesCompanion data) {
    return DailyMemory(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      narrative: data.narrative.present ? data.narrative.value : this.narrative,
      themes: data.themes.present ? data.themes.value : this.themes,
      conversationIds: data.conversationIds.present
          ? data.conversationIds.value
          : this.conversationIds,
      generatedAt: data.generatedAt.present
          ? data.generatedAt.value
          : this.generatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyMemory(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('narrative: $narrative, ')
          ..write('themes: $themes, ')
          ..write('conversationIds: $conversationIds, ')
          ..write('generatedAt: $generatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, narrative, themes, conversationIds, generatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyMemory &&
          other.id == this.id &&
          other.date == this.date &&
          other.narrative == this.narrative &&
          other.themes == this.themes &&
          other.conversationIds == this.conversationIds &&
          other.generatedAt == this.generatedAt);
}

class DailyMemoriesCompanion extends UpdateCompanion<DailyMemory> {
  final Value<String> id;
  final Value<String> date;
  final Value<String> narrative;
  final Value<String> themes;
  final Value<String> conversationIds;
  final Value<int> generatedAt;
  final Value<int> rowid;
  const DailyMemoriesCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.narrative = const Value.absent(),
    this.themes = const Value.absent(),
    this.conversationIds = const Value.absent(),
    this.generatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyMemoriesCompanion.insert({
    required String id,
    required String date,
    required String narrative,
    this.themes = const Value.absent(),
    this.conversationIds = const Value.absent(),
    required int generatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       date = Value(date),
       narrative = Value(narrative),
       generatedAt = Value(generatedAt);
  static Insertable<DailyMemory> custom({
    Expression<String>? id,
    Expression<String>? date,
    Expression<String>? narrative,
    Expression<String>? themes,
    Expression<String>? conversationIds,
    Expression<int>? generatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (narrative != null) 'narrative': narrative,
      if (themes != null) 'themes': themes,
      if (conversationIds != null) 'conversation_ids': conversationIds,
      if (generatedAt != null) 'generated_at': generatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyMemoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? date,
    Value<String>? narrative,
    Value<String>? themes,
    Value<String>? conversationIds,
    Value<int>? generatedAt,
    Value<int>? rowid,
  }) {
    return DailyMemoriesCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      narrative: narrative ?? this.narrative,
      themes: themes ?? this.themes,
      conversationIds: conversationIds ?? this.conversationIds,
      generatedAt: generatedAt ?? this.generatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (narrative.present) {
      map['narrative'] = Variable<String>(narrative.value);
    }
    if (themes.present) {
      map['themes'] = Variable<String>(themes.value);
    }
    if (conversationIds.present) {
      map['conversation_ids'] = Variable<String>(conversationIds.value);
    }
    if (generatedAt.present) {
      map['generated_at'] = Variable<int>(generatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyMemoriesCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('narrative: $narrative, ')
          ..write('themes: $themes, ')
          ..write('conversationIds: $conversationIds, ')
          ..write('generatedAt: $generatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VoiceNotesTable extends VoiceNotes
    with TableInfo<$VoiceNotesTable, VoiceNote> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VoiceNotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _transcriptMeta = const VerificationMeta(
    'transcript',
  );
  @override
  late final GeneratedColumn<String> transcript = GeneratedColumn<String>(
    'transcript',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
    'tags',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    durationMs,
    transcript,
    summary,
    tags,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'voice_notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<VoiceNote> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('transcript')) {
      context.handle(
        _transcriptMeta,
        transcript.isAcceptableOrUnknown(data['transcript']!, _transcriptMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('tags')) {
      context.handle(
        _tagsMeta,
        tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VoiceNote map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VoiceNote(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      transcript: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transcript'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      tags: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tags'],
      )!,
    );
  }

  @override
  $VoiceNotesTable createAlias(String alias) {
    return $VoiceNotesTable(attachedDatabase, alias);
  }
}

class VoiceNote extends DataClass implements Insertable<VoiceNote> {
  final String id;
  final int createdAt;
  final int durationMs;
  final String? transcript;
  final String? summary;
  final String tags;
  const VoiceNote({
    required this.id,
    required this.createdAt,
    required this.durationMs,
    this.transcript,
    this.summary,
    required this.tags,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['created_at'] = Variable<int>(createdAt);
    map['duration_ms'] = Variable<int>(durationMs);
    if (!nullToAbsent || transcript != null) {
      map['transcript'] = Variable<String>(transcript);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['tags'] = Variable<String>(tags);
    return map;
  }

  VoiceNotesCompanion toCompanion(bool nullToAbsent) {
    return VoiceNotesCompanion(
      id: Value(id),
      createdAt: Value(createdAt),
      durationMs: Value(durationMs),
      transcript: transcript == null && nullToAbsent
          ? const Value.absent()
          : Value(transcript),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      tags: Value(tags),
    );
  }

  factory VoiceNote.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VoiceNote(
      id: serializer.fromJson<String>(json['id']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      transcript: serializer.fromJson<String?>(json['transcript']),
      summary: serializer.fromJson<String?>(json['summary']),
      tags: serializer.fromJson<String>(json['tags']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'createdAt': serializer.toJson<int>(createdAt),
      'durationMs': serializer.toJson<int>(durationMs),
      'transcript': serializer.toJson<String?>(transcript),
      'summary': serializer.toJson<String?>(summary),
      'tags': serializer.toJson<String>(tags),
    };
  }

  VoiceNote copyWith({
    String? id,
    int? createdAt,
    int? durationMs,
    Value<String?> transcript = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    String? tags,
  }) => VoiceNote(
    id: id ?? this.id,
    createdAt: createdAt ?? this.createdAt,
    durationMs: durationMs ?? this.durationMs,
    transcript: transcript.present ? transcript.value : this.transcript,
    summary: summary.present ? summary.value : this.summary,
    tags: tags ?? this.tags,
  );
  VoiceNote copyWithCompanion(VoiceNotesCompanion data) {
    return VoiceNote(
      id: data.id.present ? data.id.value : this.id,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      transcript: data.transcript.present
          ? data.transcript.value
          : this.transcript,
      summary: data.summary.present ? data.summary.value : this.summary,
      tags: data.tags.present ? data.tags.value : this.tags,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VoiceNote(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('transcript: $transcript, ')
          ..write('summary: $summary, ')
          ..write('tags: $tags')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, createdAt, durationMs, transcript, summary, tags);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VoiceNote &&
          other.id == this.id &&
          other.createdAt == this.createdAt &&
          other.durationMs == this.durationMs &&
          other.transcript == this.transcript &&
          other.summary == this.summary &&
          other.tags == this.tags);
}

class VoiceNotesCompanion extends UpdateCompanion<VoiceNote> {
  final Value<String> id;
  final Value<int> createdAt;
  final Value<int> durationMs;
  final Value<String?> transcript;
  final Value<String?> summary;
  final Value<String> tags;
  final Value<int> rowid;
  const VoiceNotesCompanion({
    this.id = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.transcript = const Value.absent(),
    this.summary = const Value.absent(),
    this.tags = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VoiceNotesCompanion.insert({
    required String id,
    required int createdAt,
    this.durationMs = const Value.absent(),
    this.transcript = const Value.absent(),
    this.summary = const Value.absent(),
    this.tags = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       createdAt = Value(createdAt);
  static Insertable<VoiceNote> custom({
    Expression<String>? id,
    Expression<int>? createdAt,
    Expression<int>? durationMs,
    Expression<String>? transcript,
    Expression<String>? summary,
    Expression<String>? tags,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (createdAt != null) 'created_at': createdAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (transcript != null) 'transcript': transcript,
      if (summary != null) 'summary': summary,
      if (tags != null) 'tags': tags,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VoiceNotesCompanion copyWith({
    Value<String>? id,
    Value<int>? createdAt,
    Value<int>? durationMs,
    Value<String?>? transcript,
    Value<String?>? summary,
    Value<String>? tags,
    Value<int>? rowid,
  }) {
    return VoiceNotesCompanion(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      durationMs: durationMs ?? this.durationMs,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
      tags: tags ?? this.tags,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (transcript.present) {
      map['transcript'] = Variable<String>(transcript.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VoiceNotesCompanion(')
          ..write('id: $id, ')
          ..write('createdAt: $createdAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('transcript: $transcript, ')
          ..write('summary: $summary, ')
          ..write('tags: $tags, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TodosTable extends Todos with TableInfo<$TodosTable, Todo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<int> dueDate = GeneratedColumn<int>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<int> completedAt = GeneratedColumn<int>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('auto'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    content,
    isCompleted,
    dueDate,
    createdAt,
    completedAt,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Todo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Todo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Todo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}due_date'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $TodosTable createAlias(String alias) {
    return $TodosTable(attachedDatabase, alias);
  }
}

class Todo extends DataClass implements Insertable<Todo> {
  final String id;
  final String? conversationId;
  final String content;
  final bool isCompleted;
  final int? dueDate;
  final int createdAt;
  final int? completedAt;
  final String source;
  const Todo({
    required this.id,
    this.conversationId,
    required this.content,
    required this.isCompleted,
    this.dueDate,
    required this.createdAt,
    this.completedAt,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || conversationId != null) {
      map['conversation_id'] = Variable<String>(conversationId);
    }
    map['content'] = Variable<String>(content);
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<int>(dueDate);
    }
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<int>(completedAt);
    }
    map['source'] = Variable<String>(source);
    return map;
  }

  TodosCompanion toCompanion(bool nullToAbsent) {
    return TodosCompanion(
      id: Value(id),
      conversationId: conversationId == null && nullToAbsent
          ? const Value.absent()
          : Value(conversationId),
      content: Value(content),
      isCompleted: Value(isCompleted),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      createdAt: Value(createdAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      source: Value(source),
    );
  }

  factory Todo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Todo(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String?>(json['conversationId']),
      content: serializer.fromJson<String>(json['content']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      dueDate: serializer.fromJson<int?>(json['dueDate']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      completedAt: serializer.fromJson<int?>(json['completedAt']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String?>(conversationId),
      'content': serializer.toJson<String>(content),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'dueDate': serializer.toJson<int?>(dueDate),
      'createdAt': serializer.toJson<int>(createdAt),
      'completedAt': serializer.toJson<int?>(completedAt),
      'source': serializer.toJson<String>(source),
    };
  }

  Todo copyWith({
    String? id,
    Value<String?> conversationId = const Value.absent(),
    String? content,
    bool? isCompleted,
    Value<int?> dueDate = const Value.absent(),
    int? createdAt,
    Value<int?> completedAt = const Value.absent(),
    String? source,
  }) => Todo(
    id: id ?? this.id,
    conversationId: conversationId.present
        ? conversationId.value
        : this.conversationId,
    content: content ?? this.content,
    isCompleted: isCompleted ?? this.isCompleted,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    createdAt: createdAt ?? this.createdAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    source: source ?? this.source,
  );
  Todo copyWithCompanion(TodosCompanion data) {
    return Todo(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      content: data.content.present ? data.content.value : this.content,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Todo(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('content: $content, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('dueDate: $dueDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    content,
    isCompleted,
    dueDate,
    createdAt,
    completedAt,
    source,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Todo &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.content == this.content &&
          other.isCompleted == this.isCompleted &&
          other.dueDate == this.dueDate &&
          other.createdAt == this.createdAt &&
          other.completedAt == this.completedAt &&
          other.source == this.source);
}

class TodosCompanion extends UpdateCompanion<Todo> {
  final Value<String> id;
  final Value<String?> conversationId;
  final Value<String> content;
  final Value<bool> isCompleted;
  final Value<int?> dueDate;
  final Value<int> createdAt;
  final Value<int?> completedAt;
  final Value<String> source;
  final Value<int> rowid;
  const TodosCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.content = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodosCompanion.insert({
    required String id,
    this.conversationId = const Value.absent(),
    required String content,
    this.isCompleted = const Value.absent(),
    this.dueDate = const Value.absent(),
    required int createdAt,
    this.completedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       content = Value(content),
       createdAt = Value(createdAt);
  static Insertable<Todo> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? content,
    Expression<bool>? isCompleted,
    Expression<int>? dueDate,
    Expression<int>? createdAt,
    Expression<int>? completedAt,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (content != null) 'content': content,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (dueDate != null) 'due_date': dueDate,
      if (createdAt != null) 'created_at': createdAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodosCompanion copyWith({
    Value<String>? id,
    Value<String?>? conversationId,
    Value<String>? content,
    Value<bool>? isCompleted,
    Value<int?>? dueDate,
    Value<int>? createdAt,
    Value<int?>? completedAt,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return TodosCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      content: content ?? this.content,
      isCompleted: isCompleted ?? this.isCompleted,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<int>(dueDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<int>(completedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodosCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('content: $content, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('dueDate: $dueDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BuzzHistoryEntriesTable extends BuzzHistoryEntries
    with TableInfo<$BuzzHistoryEntriesTable, BuzzHistoryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BuzzHistoryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionMeta = const VerificationMeta(
    'question',
  );
  @override
  late final GeneratedColumn<String> question = GeneratedColumn<String>(
    'question',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _citationsMeta = const VerificationMeta(
    'citations',
  );
  @override
  late final GeneratedColumn<String> citations = GeneratedColumn<String>(
    'citations',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    question,
    answer,
    citations,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'buzz_history_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BuzzHistoryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('question')) {
      context.handle(
        _questionMeta,
        question.isAcceptableOrUnknown(data['question']!, _questionMeta),
      );
    } else if (isInserting) {
      context.missing(_questionMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('citations')) {
      context.handle(
        _citationsMeta,
        citations.isAcceptableOrUnknown(data['citations']!, _citationsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BuzzHistoryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BuzzHistoryEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      question: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
      citations: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}citations'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BuzzHistoryEntriesTable createAlias(String alias) {
    return $BuzzHistoryEntriesTable(attachedDatabase, alias);
  }
}

class BuzzHistoryEntry extends DataClass
    implements Insertable<BuzzHistoryEntry> {
  final String id;
  final String question;
  final String answer;
  final String citations;
  final int createdAt;
  const BuzzHistoryEntry({
    required this.id,
    required this.question,
    required this.answer,
    required this.citations,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['question'] = Variable<String>(question);
    map['answer'] = Variable<String>(answer);
    map['citations'] = Variable<String>(citations);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  BuzzHistoryEntriesCompanion toCompanion(bool nullToAbsent) {
    return BuzzHistoryEntriesCompanion(
      id: Value(id),
      question: Value(question),
      answer: Value(answer),
      citations: Value(citations),
      createdAt: Value(createdAt),
    );
  }

  factory BuzzHistoryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BuzzHistoryEntry(
      id: serializer.fromJson<String>(json['id']),
      question: serializer.fromJson<String>(json['question']),
      answer: serializer.fromJson<String>(json['answer']),
      citations: serializer.fromJson<String>(json['citations']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'question': serializer.toJson<String>(question),
      'answer': serializer.toJson<String>(answer),
      'citations': serializer.toJson<String>(citations),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  BuzzHistoryEntry copyWith({
    String? id,
    String? question,
    String? answer,
    String? citations,
    int? createdAt,
  }) => BuzzHistoryEntry(
    id: id ?? this.id,
    question: question ?? this.question,
    answer: answer ?? this.answer,
    citations: citations ?? this.citations,
    createdAt: createdAt ?? this.createdAt,
  );
  BuzzHistoryEntry copyWithCompanion(BuzzHistoryEntriesCompanion data) {
    return BuzzHistoryEntry(
      id: data.id.present ? data.id.value : this.id,
      question: data.question.present ? data.question.value : this.question,
      answer: data.answer.present ? data.answer.value : this.answer,
      citations: data.citations.present ? data.citations.value : this.citations,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BuzzHistoryEntry(')
          ..write('id: $id, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('citations: $citations, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, question, answer, citations, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BuzzHistoryEntry &&
          other.id == this.id &&
          other.question == this.question &&
          other.answer == this.answer &&
          other.citations == this.citations &&
          other.createdAt == this.createdAt);
}

class BuzzHistoryEntriesCompanion extends UpdateCompanion<BuzzHistoryEntry> {
  final Value<String> id;
  final Value<String> question;
  final Value<String> answer;
  final Value<String> citations;
  final Value<int> createdAt;
  final Value<int> rowid;
  const BuzzHistoryEntriesCompanion({
    this.id = const Value.absent(),
    this.question = const Value.absent(),
    this.answer = const Value.absent(),
    this.citations = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BuzzHistoryEntriesCompanion.insert({
    required String id,
    required String question,
    required String answer,
    this.citations = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       question = Value(question),
       answer = Value(answer),
       createdAt = Value(createdAt);
  static Insertable<BuzzHistoryEntry> custom({
    Expression<String>? id,
    Expression<String>? question,
    Expression<String>? answer,
    Expression<String>? citations,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (question != null) 'question': question,
      if (answer != null) 'answer': answer,
      if (citations != null) 'citations': citations,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BuzzHistoryEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? question,
    Value<String>? answer,
    Value<String>? citations,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return BuzzHistoryEntriesCompanion(
      id: id ?? this.id,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      citations: citations ?? this.citations,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (question.present) {
      map['question'] = Variable<String>(question.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (citations.present) {
      map['citations'] = Variable<String>(citations.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BuzzHistoryEntriesCompanion(')
          ..write('id: $id, ')
          ..write('question: $question, ')
          ..write('answer: $answer, ')
          ..write('citations: $citations, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KnowledgeEntitiesTable extends KnowledgeEntities
    with TableInfo<$KnowledgeEntitiesTable, KnowledgeEntity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnowledgeEntitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metadataMeta = const VerificationMeta(
    'metadata',
  );
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
    'metadata',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstSeenMeta = const VerificationMeta(
    'firstSeen',
  );
  @override
  late final GeneratedColumn<int> firstSeen = GeneratedColumn<int>(
    'first_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<int> lastSeen = GeneratedColumn<int>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mentionCountMeta = const VerificationMeta(
    'mentionCount',
  );
  @override
  late final GeneratedColumn<int> mentionCount = GeneratedColumn<int>(
    'mention_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    type,
    metadata,
    firstSeen,
    lastSeen,
    mentionCount,
    confidence,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'knowledge_entities';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnowledgeEntity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('metadata')) {
      context.handle(
        _metadataMeta,
        metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta),
      );
    }
    if (data.containsKey('first_seen')) {
      context.handle(
        _firstSeenMeta,
        firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_firstSeenMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    if (data.containsKey('mention_count')) {
      context.handle(
        _mentionCountMeta,
        mentionCount.isAcceptableOrUnknown(
          data['mention_count']!,
          _mentionCountMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KnowledgeEntity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnowledgeEntity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      metadata: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metadata'],
      ),
      firstSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen'],
      )!,
      mentionCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mention_count'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $KnowledgeEntitiesTable createAlias(String alias) {
    return $KnowledgeEntitiesTable(attachedDatabase, alias);
  }
}

class KnowledgeEntity extends DataClass implements Insertable<KnowledgeEntity> {
  final String id;
  final String name;
  final String type;
  final String? metadata;
  final int firstSeen;
  final int lastSeen;
  final int mentionCount;
  final double confidence;
  final String source;
  const KnowledgeEntity({
    required this.id,
    required this.name,
    required this.type,
    this.metadata,
    required this.firstSeen,
    required this.lastSeen,
    required this.mentionCount,
    required this.confidence,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    map['first_seen'] = Variable<int>(firstSeen);
    map['last_seen'] = Variable<int>(lastSeen);
    map['mention_count'] = Variable<int>(mentionCount);
    map['confidence'] = Variable<double>(confidence);
    map['source'] = Variable<String>(source);
    return map;
  }

  KnowledgeEntitiesCompanion toCompanion(bool nullToAbsent) {
    return KnowledgeEntitiesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
      firstSeen: Value(firstSeen),
      lastSeen: Value(lastSeen),
      mentionCount: Value(mentionCount),
      confidence: Value(confidence),
      source: Value(source),
    );
  }

  factory KnowledgeEntity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnowledgeEntity(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      metadata: serializer.fromJson<String?>(json['metadata']),
      firstSeen: serializer.fromJson<int>(json['firstSeen']),
      lastSeen: serializer.fromJson<int>(json['lastSeen']),
      mentionCount: serializer.fromJson<int>(json['mentionCount']),
      confidence: serializer.fromJson<double>(json['confidence']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'metadata': serializer.toJson<String?>(metadata),
      'firstSeen': serializer.toJson<int>(firstSeen),
      'lastSeen': serializer.toJson<int>(lastSeen),
      'mentionCount': serializer.toJson<int>(mentionCount),
      'confidence': serializer.toJson<double>(confidence),
      'source': serializer.toJson<String>(source),
    };
  }

  KnowledgeEntity copyWith({
    String? id,
    String? name,
    String? type,
    Value<String?> metadata = const Value.absent(),
    int? firstSeen,
    int? lastSeen,
    int? mentionCount,
    double? confidence,
    String? source,
  }) => KnowledgeEntity(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    metadata: metadata.present ? metadata.value : this.metadata,
    firstSeen: firstSeen ?? this.firstSeen,
    lastSeen: lastSeen ?? this.lastSeen,
    mentionCount: mentionCount ?? this.mentionCount,
    confidence: confidence ?? this.confidence,
    source: source ?? this.source,
  );
  KnowledgeEntity copyWithCompanion(KnowledgeEntitiesCompanion data) {
    return KnowledgeEntity(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      mentionCount: data.mentionCount.present
          ? data.mentionCount.value
          : this.mentionCount,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeEntity(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('metadata: $metadata, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('mentionCount: $mentionCount, ')
          ..write('confidence: $confidence, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    metadata,
    firstSeen,
    lastSeen,
    mentionCount,
    confidence,
    source,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnowledgeEntity &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.metadata == this.metadata &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen &&
          other.mentionCount == this.mentionCount &&
          other.confidence == this.confidence &&
          other.source == this.source);
}

class KnowledgeEntitiesCompanion extends UpdateCompanion<KnowledgeEntity> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> metadata;
  final Value<int> firstSeen;
  final Value<int> lastSeen;
  final Value<int> mentionCount;
  final Value<double> confidence;
  final Value<String> source;
  final Value<int> rowid;
  const KnowledgeEntitiesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.metadata = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.mentionCount = const Value.absent(),
    this.confidence = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KnowledgeEntitiesCompanion.insert({
    required String id,
    required String name,
    required String type,
    this.metadata = const Value.absent(),
    required int firstSeen,
    required int lastSeen,
    this.mentionCount = const Value.absent(),
    this.confidence = const Value.absent(),
    required String source,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type),
       firstSeen = Value(firstSeen),
       lastSeen = Value(lastSeen),
       source = Value(source);
  static Insertable<KnowledgeEntity> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? metadata,
    Expression<int>? firstSeen,
    Expression<int>? lastSeen,
    Expression<int>? mentionCount,
    Expression<double>? confidence,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (metadata != null) 'metadata': metadata,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (mentionCount != null) 'mention_count': mentionCount,
      if (confidence != null) 'confidence': confidence,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KnowledgeEntitiesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? metadata,
    Value<int>? firstSeen,
    Value<int>? lastSeen,
    Value<int>? mentionCount,
    Value<double>? confidence,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return KnowledgeEntitiesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      mentionCount: mentionCount ?? this.mentionCount,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<int>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<int>(lastSeen.value);
    }
    if (mentionCount.present) {
      map['mention_count'] = Variable<int>(mentionCount.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeEntitiesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('metadata: $metadata, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('mentionCount: $mentionCount, ')
          ..write('confidence: $confidence, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KnowledgeRelationshipsTable extends KnowledgeRelationships
    with TableInfo<$KnowledgeRelationshipsTable, KnowledgeRelationship> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnowledgeRelationshipsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityAIdMeta = const VerificationMeta(
    'entityAId',
  );
  @override
  late final GeneratedColumn<String> entityAId = GeneratedColumn<String>(
    'entity_a_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityBIdMeta = const VerificationMeta(
    'entityBId',
  );
  @override
  late final GeneratedColumn<String> entityBId = GeneratedColumn<String>(
    'entity_b_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relationTypeMeta = const VerificationMeta(
    'relationType',
  );
  @override
  late final GeneratedColumn<String> relationType = GeneratedColumn<String>(
    'relation_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.5),
  );
  static const VerificationMeta _firstSeenMeta = const VerificationMeta(
    'firstSeen',
  );
  @override
  late final GeneratedColumn<int> firstSeen = GeneratedColumn<int>(
    'first_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<int> lastSeen = GeneratedColumn<int>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityAId,
    entityBId,
    relationType,
    description,
    confidence,
    firstSeen,
    lastSeen,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'knowledge_relationships';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnowledgeRelationship> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_a_id')) {
      context.handle(
        _entityAIdMeta,
        entityAId.isAcceptableOrUnknown(data['entity_a_id']!, _entityAIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityAIdMeta);
    }
    if (data.containsKey('entity_b_id')) {
      context.handle(
        _entityBIdMeta,
        entityBId.isAcceptableOrUnknown(data['entity_b_id']!, _entityBIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityBIdMeta);
    }
    if (data.containsKey('relation_type')) {
      context.handle(
        _relationTypeMeta,
        relationType.isAcceptableOrUnknown(
          data['relation_type']!,
          _relationTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relationTypeMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('first_seen')) {
      context.handle(
        _firstSeenMeta,
        firstSeen.isAcceptableOrUnknown(data['first_seen']!, _firstSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_firstSeenMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KnowledgeRelationship map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnowledgeRelationship(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityAId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_a_id'],
      )!,
      entityBId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_b_id'],
      )!,
      relationType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relation_type'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
      firstSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_seen'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen'],
      )!,
    );
  }

  @override
  $KnowledgeRelationshipsTable createAlias(String alias) {
    return $KnowledgeRelationshipsTable(attachedDatabase, alias);
  }
}

class KnowledgeRelationship extends DataClass
    implements Insertable<KnowledgeRelationship> {
  final String id;
  final String entityAId;
  final String entityBId;
  final String relationType;
  final String? description;
  final double confidence;
  final int firstSeen;
  final int lastSeen;
  const KnowledgeRelationship({
    required this.id,
    required this.entityAId,
    required this.entityBId,
    required this.relationType,
    this.description,
    required this.confidence,
    required this.firstSeen,
    required this.lastSeen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_a_id'] = Variable<String>(entityAId);
    map['entity_b_id'] = Variable<String>(entityBId);
    map['relation_type'] = Variable<String>(relationType);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['confidence'] = Variable<double>(confidence);
    map['first_seen'] = Variable<int>(firstSeen);
    map['last_seen'] = Variable<int>(lastSeen);
    return map;
  }

  KnowledgeRelationshipsCompanion toCompanion(bool nullToAbsent) {
    return KnowledgeRelationshipsCompanion(
      id: Value(id),
      entityAId: Value(entityAId),
      entityBId: Value(entityBId),
      relationType: Value(relationType),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      confidence: Value(confidence),
      firstSeen: Value(firstSeen),
      lastSeen: Value(lastSeen),
    );
  }

  factory KnowledgeRelationship.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnowledgeRelationship(
      id: serializer.fromJson<String>(json['id']),
      entityAId: serializer.fromJson<String>(json['entityAId']),
      entityBId: serializer.fromJson<String>(json['entityBId']),
      relationType: serializer.fromJson<String>(json['relationType']),
      description: serializer.fromJson<String?>(json['description']),
      confidence: serializer.fromJson<double>(json['confidence']),
      firstSeen: serializer.fromJson<int>(json['firstSeen']),
      lastSeen: serializer.fromJson<int>(json['lastSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityAId': serializer.toJson<String>(entityAId),
      'entityBId': serializer.toJson<String>(entityBId),
      'relationType': serializer.toJson<String>(relationType),
      'description': serializer.toJson<String?>(description),
      'confidence': serializer.toJson<double>(confidence),
      'firstSeen': serializer.toJson<int>(firstSeen),
      'lastSeen': serializer.toJson<int>(lastSeen),
    };
  }

  KnowledgeRelationship copyWith({
    String? id,
    String? entityAId,
    String? entityBId,
    String? relationType,
    Value<String?> description = const Value.absent(),
    double? confidence,
    int? firstSeen,
    int? lastSeen,
  }) => KnowledgeRelationship(
    id: id ?? this.id,
    entityAId: entityAId ?? this.entityAId,
    entityBId: entityBId ?? this.entityBId,
    relationType: relationType ?? this.relationType,
    description: description.present ? description.value : this.description,
    confidence: confidence ?? this.confidence,
    firstSeen: firstSeen ?? this.firstSeen,
    lastSeen: lastSeen ?? this.lastSeen,
  );
  KnowledgeRelationship copyWithCompanion(
    KnowledgeRelationshipsCompanion data,
  ) {
    return KnowledgeRelationship(
      id: data.id.present ? data.id.value : this.id,
      entityAId: data.entityAId.present ? data.entityAId.value : this.entityAId,
      entityBId: data.entityBId.present ? data.entityBId.value : this.entityBId,
      relationType: data.relationType.present
          ? data.relationType.value
          : this.relationType,
      description: data.description.present
          ? data.description.value
          : this.description,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      firstSeen: data.firstSeen.present ? data.firstSeen.value : this.firstSeen,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeRelationship(')
          ..write('id: $id, ')
          ..write('entityAId: $entityAId, ')
          ..write('entityBId: $entityBId, ')
          ..write('relationType: $relationType, ')
          ..write('description: $description, ')
          ..write('confidence: $confidence, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityAId,
    entityBId,
    relationType,
    description,
    confidence,
    firstSeen,
    lastSeen,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnowledgeRelationship &&
          other.id == this.id &&
          other.entityAId == this.entityAId &&
          other.entityBId == this.entityBId &&
          other.relationType == this.relationType &&
          other.description == this.description &&
          other.confidence == this.confidence &&
          other.firstSeen == this.firstSeen &&
          other.lastSeen == this.lastSeen);
}

class KnowledgeRelationshipsCompanion
    extends UpdateCompanion<KnowledgeRelationship> {
  final Value<String> id;
  final Value<String> entityAId;
  final Value<String> entityBId;
  final Value<String> relationType;
  final Value<String?> description;
  final Value<double> confidence;
  final Value<int> firstSeen;
  final Value<int> lastSeen;
  final Value<int> rowid;
  const KnowledgeRelationshipsCompanion({
    this.id = const Value.absent(),
    this.entityAId = const Value.absent(),
    this.entityBId = const Value.absent(),
    this.relationType = const Value.absent(),
    this.description = const Value.absent(),
    this.confidence = const Value.absent(),
    this.firstSeen = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KnowledgeRelationshipsCompanion.insert({
    required String id,
    required String entityAId,
    required String entityBId,
    required String relationType,
    this.description = const Value.absent(),
    this.confidence = const Value.absent(),
    required int firstSeen,
    required int lastSeen,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityAId = Value(entityAId),
       entityBId = Value(entityBId),
       relationType = Value(relationType),
       firstSeen = Value(firstSeen),
       lastSeen = Value(lastSeen);
  static Insertable<KnowledgeRelationship> custom({
    Expression<String>? id,
    Expression<String>? entityAId,
    Expression<String>? entityBId,
    Expression<String>? relationType,
    Expression<String>? description,
    Expression<double>? confidence,
    Expression<int>? firstSeen,
    Expression<int>? lastSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityAId != null) 'entity_a_id': entityAId,
      if (entityBId != null) 'entity_b_id': entityBId,
      if (relationType != null) 'relation_type': relationType,
      if (description != null) 'description': description,
      if (confidence != null) 'confidence': confidence,
      if (firstSeen != null) 'first_seen': firstSeen,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KnowledgeRelationshipsCompanion copyWith({
    Value<String>? id,
    Value<String>? entityAId,
    Value<String>? entityBId,
    Value<String>? relationType,
    Value<String?>? description,
    Value<double>? confidence,
    Value<int>? firstSeen,
    Value<int>? lastSeen,
    Value<int>? rowid,
  }) {
    return KnowledgeRelationshipsCompanion(
      id: id ?? this.id,
      entityAId: entityAId ?? this.entityAId,
      entityBId: entityBId ?? this.entityBId,
      relationType: relationType ?? this.relationType,
      description: description ?? this.description,
      confidence: confidence ?? this.confidence,
      firstSeen: firstSeen ?? this.firstSeen,
      lastSeen: lastSeen ?? this.lastSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityAId.present) {
      map['entity_a_id'] = Variable<String>(entityAId.value);
    }
    if (entityBId.present) {
      map['entity_b_id'] = Variable<String>(entityBId.value);
    }
    if (relationType.present) {
      map['relation_type'] = Variable<String>(relationType.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    if (firstSeen.present) {
      map['first_seen'] = Variable<int>(firstSeen.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<int>(lastSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnowledgeRelationshipsCompanion(')
          ..write('id: $id, ')
          ..write('entityAId: $entityAId, ')
          ..write('entityBId: $entityBId, ')
          ..write('relationType: $relationType, ')
          ..write('description: $description, ')
          ..write('confidence: $confidence, ')
          ..write('firstSeen: $firstSeen, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _profileJsonMeta = const VerificationMeta(
    'profileJson',
  );
  @override
  late final GeneratedColumn<String> profileJson = GeneratedColumn<String>(
    'profile_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUpdatedMeta = const VerificationMeta(
    'lastUpdated',
  );
  @override
  late final GeneratedColumn<int> lastUpdated = GeneratedColumn<int>(
    'last_updated',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [id, profileJson, lastUpdated, version];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('profile_json')) {
      context.handle(
        _profileJsonMeta,
        profileJson.isAcceptableOrUnknown(
          data['profile_json']!,
          _profileJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_profileJsonMeta);
    }
    if (data.containsKey('last_updated')) {
      context.handle(
        _lastUpdatedMeta,
        lastUpdated.isAcceptableOrUnknown(
          data['last_updated']!,
          _lastUpdatedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastUpdatedMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      profileJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_json'],
      )!,
      lastUpdated: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_updated'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final int id;
  final String profileJson;
  final int lastUpdated;
  final int version;
  const UserProfile({
    required this.id,
    required this.profileJson,
    required this.lastUpdated,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['profile_json'] = Variable<String>(profileJson);
    map['last_updated'] = Variable<int>(lastUpdated);
    map['version'] = Variable<int>(version);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      profileJson: Value(profileJson),
      lastUpdated: Value(lastUpdated),
      version: Value(version),
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      id: serializer.fromJson<int>(json['id']),
      profileJson: serializer.fromJson<String>(json['profileJson']),
      lastUpdated: serializer.fromJson<int>(json['lastUpdated']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'profileJson': serializer.toJson<String>(profileJson),
      'lastUpdated': serializer.toJson<int>(lastUpdated),
      'version': serializer.toJson<int>(version),
    };
  }

  UserProfile copyWith({
    int? id,
    String? profileJson,
    int? lastUpdated,
    int? version,
  }) => UserProfile(
    id: id ?? this.id,
    profileJson: profileJson ?? this.profileJson,
    lastUpdated: lastUpdated ?? this.lastUpdated,
    version: version ?? this.version,
  );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      id: data.id.present ? data.id.value : this.id,
      profileJson: data.profileJson.present
          ? data.profileJson.value
          : this.profileJson,
      lastUpdated: data.lastUpdated.present
          ? data.lastUpdated.value
          : this.lastUpdated,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('id: $id, ')
          ..write('profileJson: $profileJson, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, profileJson, lastUpdated, version);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.id == this.id &&
          other.profileJson == this.profileJson &&
          other.lastUpdated == this.lastUpdated &&
          other.version == this.version);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<int> id;
  final Value<String> profileJson;
  final Value<int> lastUpdated;
  final Value<int> version;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.profileJson = const Value.absent(),
    this.lastUpdated = const Value.absent(),
    this.version = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    this.id = const Value.absent(),
    required String profileJson,
    required int lastUpdated,
    this.version = const Value.absent(),
  }) : profileJson = Value(profileJson),
       lastUpdated = Value(lastUpdated);
  static Insertable<UserProfile> custom({
    Expression<int>? id,
    Expression<String>? profileJson,
    Expression<int>? lastUpdated,
    Expression<int>? version,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (profileJson != null) 'profile_json': profileJson,
      if (lastUpdated != null) 'last_updated': lastUpdated,
      if (version != null) 'version': version,
    });
  }

  UserProfilesCompanion copyWith({
    Value<int>? id,
    Value<String>? profileJson,
    Value<int>? lastUpdated,
    Value<int>? version,
  }) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      profileJson: profileJson ?? this.profileJson,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      version: version ?? this.version,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (profileJson.present) {
      map['profile_json'] = Variable<String>(profileJson.value);
    }
    if (lastUpdated.present) {
      map['last_updated'] = Variable<int>(lastUpdated.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('profileJson: $profileJson, ')
          ..write('lastUpdated: $lastUpdated, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }
}

class $ProjectsTable extends Projects with TableInfo<$ProjectsTable, Project> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chunkSizeTokensMeta = const VerificationMeta(
    'chunkSizeTokens',
  );
  @override
  late final GeneratedColumn<int> chunkSizeTokens = GeneratedColumn<int>(
    'chunk_size_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(800),
  );
  static const VerificationMeta _chunkOverlapTokensMeta =
      const VerificationMeta('chunkOverlapTokens');
  @override
  late final GeneratedColumn<int> chunkOverlapTokens = GeneratedColumn<int>(
    'chunk_overlap_tokens',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _retrievalTopKMeta = const VerificationMeta(
    'retrievalTopK',
  );
  @override
  late final GeneratedColumn<int> retrievalTopK = GeneratedColumn<int>(
    'retrieval_top_k',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _retrievalMinSimilarityMeta =
      const VerificationMeta('retrievalMinSimilarity');
  @override
  late final GeneratedColumn<double> retrievalMinSimilarity =
      GeneratedColumn<double>(
        'retrieval_min_similarity',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.3),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    createdAt,
    updatedAt,
    deletedAt,
    chunkSizeTokens,
    chunkOverlapTokens,
    retrievalTopK,
    retrievalMinSimilarity,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<Project> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('chunk_size_tokens')) {
      context.handle(
        _chunkSizeTokensMeta,
        chunkSizeTokens.isAcceptableOrUnknown(
          data['chunk_size_tokens']!,
          _chunkSizeTokensMeta,
        ),
      );
    }
    if (data.containsKey('chunk_overlap_tokens')) {
      context.handle(
        _chunkOverlapTokensMeta,
        chunkOverlapTokens.isAcceptableOrUnknown(
          data['chunk_overlap_tokens']!,
          _chunkOverlapTokensMeta,
        ),
      );
    }
    if (data.containsKey('retrieval_top_k')) {
      context.handle(
        _retrievalTopKMeta,
        retrievalTopK.isAcceptableOrUnknown(
          data['retrieval_top_k']!,
          _retrievalTopKMeta,
        ),
      );
    }
    if (data.containsKey('retrieval_min_similarity')) {
      context.handle(
        _retrievalMinSimilarityMeta,
        retrievalMinSimilarity.isAcceptableOrUnknown(
          data['retrieval_min_similarity']!,
          _retrievalMinSimilarityMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Project map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Project(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      chunkSizeTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_size_tokens'],
      )!,
      chunkOverlapTokens: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_overlap_tokens'],
      )!,
      retrievalTopK: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retrieval_top_k'],
      )!,
      retrievalMinSimilarity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}retrieval_min_similarity'],
      )!,
    );
  }

  @override
  $ProjectsTable createAlias(String alias) {
    return $ProjectsTable(attachedDatabase, alias);
  }
}

class Project extends DataClass implements Insertable<Project> {
  final String id;
  final String name;
  final String? description;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
  final int chunkSizeTokens;
  final int chunkOverlapTokens;
  final int retrievalTopK;
  final double retrievalMinSimilarity;
  const Project({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.chunkSizeTokens,
    required this.chunkOverlapTokens,
    required this.retrievalTopK,
    required this.retrievalMinSimilarity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['chunk_size_tokens'] = Variable<int>(chunkSizeTokens);
    map['chunk_overlap_tokens'] = Variable<int>(chunkOverlapTokens);
    map['retrieval_top_k'] = Variable<int>(retrievalTopK);
    map['retrieval_min_similarity'] = Variable<double>(retrievalMinSimilarity);
    return map;
  }

  ProjectsCompanion toCompanion(bool nullToAbsent) {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      chunkSizeTokens: Value(chunkSizeTokens),
      chunkOverlapTokens: Value(chunkOverlapTokens),
      retrievalTopK: Value(retrievalTopK),
      retrievalMinSimilarity: Value(retrievalMinSimilarity),
    );
  }

  factory Project.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Project(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      chunkSizeTokens: serializer.fromJson<int>(json['chunkSizeTokens']),
      chunkOverlapTokens: serializer.fromJson<int>(json['chunkOverlapTokens']),
      retrievalTopK: serializer.fromJson<int>(json['retrievalTopK']),
      retrievalMinSimilarity: serializer.fromJson<double>(
        json['retrievalMinSimilarity'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'chunkSizeTokens': serializer.toJson<int>(chunkSizeTokens),
      'chunkOverlapTokens': serializer.toJson<int>(chunkOverlapTokens),
      'retrievalTopK': serializer.toJson<int>(retrievalTopK),
      'retrievalMinSimilarity': serializer.toJson<double>(
        retrievalMinSimilarity,
      ),
    };
  }

  Project copyWith({
    String? id,
    String? name,
    Value<String?> description = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> deletedAt = const Value.absent(),
    int? chunkSizeTokens,
    int? chunkOverlapTokens,
    int? retrievalTopK,
    double? retrievalMinSimilarity,
  }) => Project(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    chunkSizeTokens: chunkSizeTokens ?? this.chunkSizeTokens,
    chunkOverlapTokens: chunkOverlapTokens ?? this.chunkOverlapTokens,
    retrievalTopK: retrievalTopK ?? this.retrievalTopK,
    retrievalMinSimilarity:
        retrievalMinSimilarity ?? this.retrievalMinSimilarity,
  );
  Project copyWithCompanion(ProjectsCompanion data) {
    return Project(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      chunkSizeTokens: data.chunkSizeTokens.present
          ? data.chunkSizeTokens.value
          : this.chunkSizeTokens,
      chunkOverlapTokens: data.chunkOverlapTokens.present
          ? data.chunkOverlapTokens.value
          : this.chunkOverlapTokens,
      retrievalTopK: data.retrievalTopK.present
          ? data.retrievalTopK.value
          : this.retrievalTopK,
      retrievalMinSimilarity: data.retrievalMinSimilarity.present
          ? data.retrievalMinSimilarity.value
          : this.retrievalMinSimilarity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Project(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('chunkSizeTokens: $chunkSizeTokens, ')
          ..write('chunkOverlapTokens: $chunkOverlapTokens, ')
          ..write('retrievalTopK: $retrievalTopK, ')
          ..write('retrievalMinSimilarity: $retrievalMinSimilarity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    createdAt,
    updatedAt,
    deletedAt,
    chunkSizeTokens,
    chunkOverlapTokens,
    retrievalTopK,
    retrievalMinSimilarity,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.chunkSizeTokens == this.chunkSizeTokens &&
          other.chunkOverlapTokens == this.chunkOverlapTokens &&
          other.retrievalTopK == this.retrievalTopK &&
          other.retrievalMinSimilarity == this.retrievalMinSimilarity);
}

class ProjectsCompanion extends UpdateCompanion<Project> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> deletedAt;
  final Value<int> chunkSizeTokens;
  final Value<int> chunkOverlapTokens;
  final Value<int> retrievalTopK;
  final Value<double> retrievalMinSimilarity;
  final Value<int> rowid;
  const ProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.chunkSizeTokens = const Value.absent(),
    this.chunkOverlapTokens = const Value.absent(),
    this.retrievalTopK = const Value.absent(),
    this.retrievalMinSimilarity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.deletedAt = const Value.absent(),
    this.chunkSizeTokens = const Value.absent(),
    this.chunkOverlapTokens = const Value.absent(),
    this.retrievalTopK = const Value.absent(),
    this.retrievalMinSimilarity = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Project> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? deletedAt,
    Expression<int>? chunkSizeTokens,
    Expression<int>? chunkOverlapTokens,
    Expression<int>? retrievalTopK,
    Expression<double>? retrievalMinSimilarity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (chunkSizeTokens != null) 'chunk_size_tokens': chunkSizeTokens,
      if (chunkOverlapTokens != null)
        'chunk_overlap_tokens': chunkOverlapTokens,
      if (retrievalTopK != null) 'retrieval_top_k': retrievalTopK,
      if (retrievalMinSimilarity != null)
        'retrieval_min_similarity': retrievalMinSimilarity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? deletedAt,
    Value<int>? chunkSizeTokens,
    Value<int>? chunkOverlapTokens,
    Value<int>? retrievalTopK,
    Value<double>? retrievalMinSimilarity,
    Value<int>? rowid,
  }) {
    return ProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      chunkSizeTokens: chunkSizeTokens ?? this.chunkSizeTokens,
      chunkOverlapTokens: chunkOverlapTokens ?? this.chunkOverlapTokens,
      retrievalTopK: retrievalTopK ?? this.retrievalTopK,
      retrievalMinSimilarity:
          retrievalMinSimilarity ?? this.retrievalMinSimilarity,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (chunkSizeTokens.present) {
      map['chunk_size_tokens'] = Variable<int>(chunkSizeTokens.value);
    }
    if (chunkOverlapTokens.present) {
      map['chunk_overlap_tokens'] = Variable<int>(chunkOverlapTokens.value);
    }
    if (retrievalTopK.present) {
      map['retrieval_top_k'] = Variable<int>(retrievalTopK.value);
    }
    if (retrievalMinSimilarity.present) {
      map['retrieval_min_similarity'] = Variable<double>(
        retrievalMinSimilarity.value,
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('chunkSizeTokens: $chunkSizeTokens, ')
          ..write('chunkOverlapTokens: $chunkOverlapTokens, ')
          ..write('retrievalTopK: $retrievalTopK, ')
          ..write('retrievalMinSimilarity: $retrievalMinSimilarity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectDocumentsTable extends ProjectDocuments
    with TableInfo<$ProjectDocumentsTable, ProjectDocument> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectDocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ingestedAtMeta = const VerificationMeta(
    'ingestedAt',
  );
  @override
  late final GeneratedColumn<int> ingestedAt = GeneratedColumn<int>(
    'ingested_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ingestStatusMeta = const VerificationMeta(
    'ingestStatus',
  );
  @override
  late final GeneratedColumn<String> ingestStatus = GeneratedColumn<String>(
    'ingest_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ingestErrorMeta = const VerificationMeta(
    'ingestError',
  );
  @override
  late final GeneratedColumn<String> ingestError = GeneratedColumn<String>(
    'ingest_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    filename,
    contentType,
    byteSize,
    pageCount,
    ingestedAt,
    deletedAt,
    ingestStatus,
    ingestError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectDocument> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentTypeMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_byteSizeMeta);
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    }
    if (data.containsKey('ingested_at')) {
      context.handle(
        _ingestedAtMeta,
        ingestedAt.isAcceptableOrUnknown(data['ingested_at']!, _ingestedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_ingestedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('ingest_status')) {
      context.handle(
        _ingestStatusMeta,
        ingestStatus.isAcceptableOrUnknown(
          data['ingest_status']!,
          _ingestStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ingestStatusMeta);
    }
    if (data.containsKey('ingest_error')) {
      context.handle(
        _ingestErrorMeta,
        ingestError.isAcceptableOrUnknown(
          data['ingest_error']!,
          _ingestErrorMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectDocument map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectDocument(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      )!,
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      ),
      ingestedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ingested_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
      ingestStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ingest_status'],
      )!,
      ingestError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ingest_error'],
      ),
    );
  }

  @override
  $ProjectDocumentsTable createAlias(String alias) {
    return $ProjectDocumentsTable(attachedDatabase, alias);
  }
}

class ProjectDocument extends DataClass implements Insertable<ProjectDocument> {
  final String id;
  final String projectId;
  final String filename;
  final String contentType;
  final int byteSize;
  final int? pageCount;
  final int ingestedAt;
  final int? deletedAt;
  final String ingestStatus;
  final String? ingestError;
  const ProjectDocument({
    required this.id,
    required this.projectId,
    required this.filename,
    required this.contentType,
    required this.byteSize,
    this.pageCount,
    required this.ingestedAt,
    this.deletedAt,
    required this.ingestStatus,
    this.ingestError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['project_id'] = Variable<String>(projectId);
    map['filename'] = Variable<String>(filename);
    map['content_type'] = Variable<String>(contentType);
    map['byte_size'] = Variable<int>(byteSize);
    if (!nullToAbsent || pageCount != null) {
      map['page_count'] = Variable<int>(pageCount);
    }
    map['ingested_at'] = Variable<int>(ingestedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['ingest_status'] = Variable<String>(ingestStatus);
    if (!nullToAbsent || ingestError != null) {
      map['ingest_error'] = Variable<String>(ingestError);
    }
    return map;
  }

  ProjectDocumentsCompanion toCompanion(bool nullToAbsent) {
    return ProjectDocumentsCompanion(
      id: Value(id),
      projectId: Value(projectId),
      filename: Value(filename),
      contentType: Value(contentType),
      byteSize: Value(byteSize),
      pageCount: pageCount == null && nullToAbsent
          ? const Value.absent()
          : Value(pageCount),
      ingestedAt: Value(ingestedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      ingestStatus: Value(ingestStatus),
      ingestError: ingestError == null && nullToAbsent
          ? const Value.absent()
          : Value(ingestError),
    );
  }

  factory ProjectDocument.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectDocument(
      id: serializer.fromJson<String>(json['id']),
      projectId: serializer.fromJson<String>(json['projectId']),
      filename: serializer.fromJson<String>(json['filename']),
      contentType: serializer.fromJson<String>(json['contentType']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      pageCount: serializer.fromJson<int?>(json['pageCount']),
      ingestedAt: serializer.fromJson<int>(json['ingestedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      ingestStatus: serializer.fromJson<String>(json['ingestStatus']),
      ingestError: serializer.fromJson<String?>(json['ingestError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'projectId': serializer.toJson<String>(projectId),
      'filename': serializer.toJson<String>(filename),
      'contentType': serializer.toJson<String>(contentType),
      'byteSize': serializer.toJson<int>(byteSize),
      'pageCount': serializer.toJson<int?>(pageCount),
      'ingestedAt': serializer.toJson<int>(ingestedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'ingestStatus': serializer.toJson<String>(ingestStatus),
      'ingestError': serializer.toJson<String?>(ingestError),
    };
  }

  ProjectDocument copyWith({
    String? id,
    String? projectId,
    String? filename,
    String? contentType,
    int? byteSize,
    Value<int?> pageCount = const Value.absent(),
    int? ingestedAt,
    Value<int?> deletedAt = const Value.absent(),
    String? ingestStatus,
    Value<String?> ingestError = const Value.absent(),
  }) => ProjectDocument(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    filename: filename ?? this.filename,
    contentType: contentType ?? this.contentType,
    byteSize: byteSize ?? this.byteSize,
    pageCount: pageCount.present ? pageCount.value : this.pageCount,
    ingestedAt: ingestedAt ?? this.ingestedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    ingestStatus: ingestStatus ?? this.ingestStatus,
    ingestError: ingestError.present ? ingestError.value : this.ingestError,
  );
  ProjectDocument copyWithCompanion(ProjectDocumentsCompanion data) {
    return ProjectDocument(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      filename: data.filename.present ? data.filename.value : this.filename,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      ingestedAt: data.ingestedAt.present
          ? data.ingestedAt.value
          : this.ingestedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      ingestStatus: data.ingestStatus.present
          ? data.ingestStatus.value
          : this.ingestStatus,
      ingestError: data.ingestError.present
          ? data.ingestError.value
          : this.ingestError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectDocument(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('filename: $filename, ')
          ..write('contentType: $contentType, ')
          ..write('byteSize: $byteSize, ')
          ..write('pageCount: $pageCount, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ingestStatus: $ingestStatus, ')
          ..write('ingestError: $ingestError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    filename,
    contentType,
    byteSize,
    pageCount,
    ingestedAt,
    deletedAt,
    ingestStatus,
    ingestError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectDocument &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.filename == this.filename &&
          other.contentType == this.contentType &&
          other.byteSize == this.byteSize &&
          other.pageCount == this.pageCount &&
          other.ingestedAt == this.ingestedAt &&
          other.deletedAt == this.deletedAt &&
          other.ingestStatus == this.ingestStatus &&
          other.ingestError == this.ingestError);
}

class ProjectDocumentsCompanion extends UpdateCompanion<ProjectDocument> {
  final Value<String> id;
  final Value<String> projectId;
  final Value<String> filename;
  final Value<String> contentType;
  final Value<int> byteSize;
  final Value<int?> pageCount;
  final Value<int> ingestedAt;
  final Value<int?> deletedAt;
  final Value<String> ingestStatus;
  final Value<String?> ingestError;
  final Value<int> rowid;
  const ProjectDocumentsCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.filename = const Value.absent(),
    this.contentType = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.ingestedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.ingestStatus = const Value.absent(),
    this.ingestError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectDocumentsCompanion.insert({
    required String id,
    required String projectId,
    required String filename,
    required String contentType,
    required int byteSize,
    this.pageCount = const Value.absent(),
    required int ingestedAt,
    this.deletedAt = const Value.absent(),
    required String ingestStatus,
    this.ingestError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       projectId = Value(projectId),
       filename = Value(filename),
       contentType = Value(contentType),
       byteSize = Value(byteSize),
       ingestedAt = Value(ingestedAt),
       ingestStatus = Value(ingestStatus);
  static Insertable<ProjectDocument> custom({
    Expression<String>? id,
    Expression<String>? projectId,
    Expression<String>? filename,
    Expression<String>? contentType,
    Expression<int>? byteSize,
    Expression<int>? pageCount,
    Expression<int>? ingestedAt,
    Expression<int>? deletedAt,
    Expression<String>? ingestStatus,
    Expression<String>? ingestError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (filename != null) 'filename': filename,
      if (contentType != null) 'content_type': contentType,
      if (byteSize != null) 'byte_size': byteSize,
      if (pageCount != null) 'page_count': pageCount,
      if (ingestedAt != null) 'ingested_at': ingestedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (ingestStatus != null) 'ingest_status': ingestStatus,
      if (ingestError != null) 'ingest_error': ingestError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectDocumentsCompanion copyWith({
    Value<String>? id,
    Value<String>? projectId,
    Value<String>? filename,
    Value<String>? contentType,
    Value<int>? byteSize,
    Value<int?>? pageCount,
    Value<int>? ingestedAt,
    Value<int?>? deletedAt,
    Value<String>? ingestStatus,
    Value<String?>? ingestError,
    Value<int>? rowid,
  }) {
    return ProjectDocumentsCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      filename: filename ?? this.filename,
      contentType: contentType ?? this.contentType,
      byteSize: byteSize ?? this.byteSize,
      pageCount: pageCount ?? this.pageCount,
      ingestedAt: ingestedAt ?? this.ingestedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      ingestStatus: ingestStatus ?? this.ingestStatus,
      ingestError: ingestError ?? this.ingestError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (ingestedAt.present) {
      map['ingested_at'] = Variable<int>(ingestedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (ingestStatus.present) {
      map['ingest_status'] = Variable<String>(ingestStatus.value);
    }
    if (ingestError.present) {
      map['ingest_error'] = Variable<String>(ingestError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectDocumentsCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('filename: $filename, ')
          ..write('contentType: $contentType, ')
          ..write('byteSize: $byteSize, ')
          ..write('pageCount: $pageCount, ')
          ..write('ingestedAt: $ingestedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('ingestStatus: $ingestStatus, ')
          ..write('ingestError: $ingestError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectDocumentChunksTable extends ProjectDocumentChunks
    with TableInfo<$ProjectDocumentChunksTable, ProjectDocumentChunk> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectDocumentChunksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES project_documents (id)',
    ),
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES projects (id)',
    ),
  );
  static const VerificationMeta _chunkIndexMeta = const VerificationMeta(
    'chunkIndex',
  );
  @override
  late final GeneratedColumn<int> chunkIndex = GeneratedColumn<int>(
    'chunk_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _text_Meta = const VerificationMeta('text_');
  @override
  late final GeneratedColumn<String> text_ = GeneratedColumn<String>(
    'text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenCountMeta = const VerificationMeta(
    'tokenCount',
  );
  @override
  late final GeneratedColumn<int> tokenCount = GeneratedColumn<int>(
    'token_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pageStartMeta = const VerificationMeta(
    'pageStart',
  );
  @override
  late final GeneratedColumn<int> pageStart = GeneratedColumn<int>(
    'page_start',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageEndMeta = const VerificationMeta(
    'pageEnd',
  );
  @override
  late final GeneratedColumn<int> pageEnd = GeneratedColumn<int>(
    'page_end',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    projectId,
    chunkIndex,
    text_,
    tokenCount,
    pageStart,
    pageEnd,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_document_chunks';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectDocumentChunk> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('chunk_index')) {
      context.handle(
        _chunkIndexMeta,
        chunkIndex.isAcceptableOrUnknown(data['chunk_index']!, _chunkIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkIndexMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
        _text_Meta,
        text_.isAcceptableOrUnknown(data['text']!, _text_Meta),
      );
    } else if (isInserting) {
      context.missing(_text_Meta);
    }
    if (data.containsKey('token_count')) {
      context.handle(
        _tokenCountMeta,
        tokenCount.isAcceptableOrUnknown(data['token_count']!, _tokenCountMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenCountMeta);
    }
    if (data.containsKey('page_start')) {
      context.handle(
        _pageStartMeta,
        pageStart.isAcceptableOrUnknown(data['page_start']!, _pageStartMeta),
      );
    }
    if (data.containsKey('page_end')) {
      context.handle(
        _pageEndMeta,
        pageEnd.isAcceptableOrUnknown(data['page_end']!, _pageEndMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectDocumentChunk map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectDocumentChunk(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      chunkIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_index'],
      )!,
      text_: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}text'],
      )!,
      tokenCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}token_count'],
      )!,
      pageStart: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_start'],
      ),
      pageEnd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_end'],
      ),
    );
  }

  @override
  $ProjectDocumentChunksTable createAlias(String alias) {
    return $ProjectDocumentChunksTable(attachedDatabase, alias);
  }
}

class ProjectDocumentChunk extends DataClass
    implements Insertable<ProjectDocumentChunk> {
  final String id;
  final String documentId;
  final String projectId;
  final int chunkIndex;
  final String text_;
  final int tokenCount;
  final int? pageStart;
  final int? pageEnd;
  const ProjectDocumentChunk({
    required this.id,
    required this.documentId,
    required this.projectId,
    required this.chunkIndex,
    required this.text_,
    required this.tokenCount,
    this.pageStart,
    this.pageEnd,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    map['project_id'] = Variable<String>(projectId);
    map['chunk_index'] = Variable<int>(chunkIndex);
    map['text'] = Variable<String>(text_);
    map['token_count'] = Variable<int>(tokenCount);
    if (!nullToAbsent || pageStart != null) {
      map['page_start'] = Variable<int>(pageStart);
    }
    if (!nullToAbsent || pageEnd != null) {
      map['page_end'] = Variable<int>(pageEnd);
    }
    return map;
  }

  ProjectDocumentChunksCompanion toCompanion(bool nullToAbsent) {
    return ProjectDocumentChunksCompanion(
      id: Value(id),
      documentId: Value(documentId),
      projectId: Value(projectId),
      chunkIndex: Value(chunkIndex),
      text_: Value(text_),
      tokenCount: Value(tokenCount),
      pageStart: pageStart == null && nullToAbsent
          ? const Value.absent()
          : Value(pageStart),
      pageEnd: pageEnd == null && nullToAbsent
          ? const Value.absent()
          : Value(pageEnd),
    );
  }

  factory ProjectDocumentChunk.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectDocumentChunk(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      chunkIndex: serializer.fromJson<int>(json['chunkIndex']),
      text_: serializer.fromJson<String>(json['text_']),
      tokenCount: serializer.fromJson<int>(json['tokenCount']),
      pageStart: serializer.fromJson<int?>(json['pageStart']),
      pageEnd: serializer.fromJson<int?>(json['pageEnd']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'projectId': serializer.toJson<String>(projectId),
      'chunkIndex': serializer.toJson<int>(chunkIndex),
      'text_': serializer.toJson<String>(text_),
      'tokenCount': serializer.toJson<int>(tokenCount),
      'pageStart': serializer.toJson<int?>(pageStart),
      'pageEnd': serializer.toJson<int?>(pageEnd),
    };
  }

  ProjectDocumentChunk copyWith({
    String? id,
    String? documentId,
    String? projectId,
    int? chunkIndex,
    String? text_,
    int? tokenCount,
    Value<int?> pageStart = const Value.absent(),
    Value<int?> pageEnd = const Value.absent(),
  }) => ProjectDocumentChunk(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    projectId: projectId ?? this.projectId,
    chunkIndex: chunkIndex ?? this.chunkIndex,
    text_: text_ ?? this.text_,
    tokenCount: tokenCount ?? this.tokenCount,
    pageStart: pageStart.present ? pageStart.value : this.pageStart,
    pageEnd: pageEnd.present ? pageEnd.value : this.pageEnd,
  );
  ProjectDocumentChunk copyWithCompanion(ProjectDocumentChunksCompanion data) {
    return ProjectDocumentChunk(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      chunkIndex: data.chunkIndex.present
          ? data.chunkIndex.value
          : this.chunkIndex,
      text_: data.text_.present ? data.text_.value : this.text_,
      tokenCount: data.tokenCount.present
          ? data.tokenCount.value
          : this.tokenCount,
      pageStart: data.pageStart.present ? data.pageStart.value : this.pageStart,
      pageEnd: data.pageEnd.present ? data.pageEnd.value : this.pageEnd,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectDocumentChunk(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('projectId: $projectId, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('text_: $text_, ')
          ..write('tokenCount: $tokenCount, ')
          ..write('pageStart: $pageStart, ')
          ..write('pageEnd: $pageEnd')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    projectId,
    chunkIndex,
    text_,
    tokenCount,
    pageStart,
    pageEnd,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectDocumentChunk &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.projectId == this.projectId &&
          other.chunkIndex == this.chunkIndex &&
          other.text_ == this.text_ &&
          other.tokenCount == this.tokenCount &&
          other.pageStart == this.pageStart &&
          other.pageEnd == this.pageEnd);
}

class ProjectDocumentChunksCompanion
    extends UpdateCompanion<ProjectDocumentChunk> {
  final Value<String> id;
  final Value<String> documentId;
  final Value<String> projectId;
  final Value<int> chunkIndex;
  final Value<String> text_;
  final Value<int> tokenCount;
  final Value<int?> pageStart;
  final Value<int?> pageEnd;
  final Value<int> rowid;
  const ProjectDocumentChunksCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.chunkIndex = const Value.absent(),
    this.text_ = const Value.absent(),
    this.tokenCount = const Value.absent(),
    this.pageStart = const Value.absent(),
    this.pageEnd = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectDocumentChunksCompanion.insert({
    required String id,
    required String documentId,
    required String projectId,
    required int chunkIndex,
    required String text_,
    required int tokenCount,
    this.pageStart = const Value.absent(),
    this.pageEnd = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       documentId = Value(documentId),
       projectId = Value(projectId),
       chunkIndex = Value(chunkIndex),
       text_ = Value(text_),
       tokenCount = Value(tokenCount);
  static Insertable<ProjectDocumentChunk> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<String>? projectId,
    Expression<int>? chunkIndex,
    Expression<String>? text_,
    Expression<int>? tokenCount,
    Expression<int>? pageStart,
    Expression<int>? pageEnd,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (projectId != null) 'project_id': projectId,
      if (chunkIndex != null) 'chunk_index': chunkIndex,
      if (text_ != null) 'text': text_,
      if (tokenCount != null) 'token_count': tokenCount,
      if (pageStart != null) 'page_start': pageStart,
      if (pageEnd != null) 'page_end': pageEnd,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectDocumentChunksCompanion copyWith({
    Value<String>? id,
    Value<String>? documentId,
    Value<String>? projectId,
    Value<int>? chunkIndex,
    Value<String>? text_,
    Value<int>? tokenCount,
    Value<int?>? pageStart,
    Value<int?>? pageEnd,
    Value<int>? rowid,
  }) {
    return ProjectDocumentChunksCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      projectId: projectId ?? this.projectId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      text_: text_ ?? this.text_,
      tokenCount: tokenCount ?? this.tokenCount,
      pageStart: pageStart ?? this.pageStart,
      pageEnd: pageEnd ?? this.pageEnd,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (chunkIndex.present) {
      map['chunk_index'] = Variable<int>(chunkIndex.value);
    }
    if (text_.present) {
      map['text'] = Variable<String>(text_.value);
    }
    if (tokenCount.present) {
      map['token_count'] = Variable<int>(tokenCount.value);
    }
    if (pageStart.present) {
      map['page_start'] = Variable<int>(pageStart.value);
    }
    if (pageEnd.present) {
      map['page_end'] = Variable<int>(pageEnd.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectDocumentChunksCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('projectId: $projectId, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('text_: $text_, ')
          ..write('tokenCount: $tokenCount, ')
          ..write('pageStart: $pageStart, ')
          ..write('pageEnd: $pageEnd, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProjectDocumentChunkVectorsTable extends ProjectDocumentChunkVectors
    with
        TableInfo<
          $ProjectDocumentChunkVectorsTable,
          ProjectDocumentChunkVector
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectDocumentChunkVectorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chunkIdMeta = const VerificationMeta(
    'chunkId',
  );
  @override
  late final GeneratedColumn<String> chunkId = GeneratedColumn<String>(
    'chunk_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES project_document_chunks (id)',
    ),
  );
  static const VerificationMeta _embeddingMeta = const VerificationMeta(
    'embedding',
  );
  @override
  late final GeneratedColumn<Uint8List> embedding = GeneratedColumn<Uint8List>(
    'embedding',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _embeddingModelMeta = const VerificationMeta(
    'embeddingModel',
  );
  @override
  late final GeneratedColumn<String> embeddingModel = GeneratedColumn<String>(
    'embedding_model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [chunkId, embedding, embeddingModel];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_document_chunk_vectors';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectDocumentChunkVector> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('chunk_id')) {
      context.handle(
        _chunkIdMeta,
        chunkId.isAcceptableOrUnknown(data['chunk_id']!, _chunkIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkIdMeta);
    }
    if (data.containsKey('embedding')) {
      context.handle(
        _embeddingMeta,
        embedding.isAcceptableOrUnknown(data['embedding']!, _embeddingMeta),
      );
    } else if (isInserting) {
      context.missing(_embeddingMeta);
    }
    if (data.containsKey('embedding_model')) {
      context.handle(
        _embeddingModelMeta,
        embeddingModel.isAcceptableOrUnknown(
          data['embedding_model']!,
          _embeddingModelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_embeddingModelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {chunkId};
  @override
  ProjectDocumentChunkVector map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectDocumentChunkVector(
      chunkId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chunk_id'],
      )!,
      embedding: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}embedding'],
      )!,
      embeddingModel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}embedding_model'],
      )!,
    );
  }

  @override
  $ProjectDocumentChunkVectorsTable createAlias(String alias) {
    return $ProjectDocumentChunkVectorsTable(attachedDatabase, alias);
  }
}

class ProjectDocumentChunkVector extends DataClass
    implements Insertable<ProjectDocumentChunkVector> {
  final String chunkId;
  final Uint8List embedding;
  final String embeddingModel;
  const ProjectDocumentChunkVector({
    required this.chunkId,
    required this.embedding,
    required this.embeddingModel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['chunk_id'] = Variable<String>(chunkId);
    map['embedding'] = Variable<Uint8List>(embedding);
    map['embedding_model'] = Variable<String>(embeddingModel);
    return map;
  }

  ProjectDocumentChunkVectorsCompanion toCompanion(bool nullToAbsent) {
    return ProjectDocumentChunkVectorsCompanion(
      chunkId: Value(chunkId),
      embedding: Value(embedding),
      embeddingModel: Value(embeddingModel),
    );
  }

  factory ProjectDocumentChunkVector.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectDocumentChunkVector(
      chunkId: serializer.fromJson<String>(json['chunkId']),
      embedding: serializer.fromJson<Uint8List>(json['embedding']),
      embeddingModel: serializer.fromJson<String>(json['embeddingModel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'chunkId': serializer.toJson<String>(chunkId),
      'embedding': serializer.toJson<Uint8List>(embedding),
      'embeddingModel': serializer.toJson<String>(embeddingModel),
    };
  }

  ProjectDocumentChunkVector copyWith({
    String? chunkId,
    Uint8List? embedding,
    String? embeddingModel,
  }) => ProjectDocumentChunkVector(
    chunkId: chunkId ?? this.chunkId,
    embedding: embedding ?? this.embedding,
    embeddingModel: embeddingModel ?? this.embeddingModel,
  );
  ProjectDocumentChunkVector copyWithCompanion(
    ProjectDocumentChunkVectorsCompanion data,
  ) {
    return ProjectDocumentChunkVector(
      chunkId: data.chunkId.present ? data.chunkId.value : this.chunkId,
      embedding: data.embedding.present ? data.embedding.value : this.embedding,
      embeddingModel: data.embeddingModel.present
          ? data.embeddingModel.value
          : this.embeddingModel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectDocumentChunkVector(')
          ..write('chunkId: $chunkId, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingModel: $embeddingModel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(chunkId, $driftBlobEquality.hash(embedding), embeddingModel);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectDocumentChunkVector &&
          other.chunkId == this.chunkId &&
          $driftBlobEquality.equals(other.embedding, this.embedding) &&
          other.embeddingModel == this.embeddingModel);
}

class ProjectDocumentChunkVectorsCompanion
    extends UpdateCompanion<ProjectDocumentChunkVector> {
  final Value<String> chunkId;
  final Value<Uint8List> embedding;
  final Value<String> embeddingModel;
  final Value<int> rowid;
  const ProjectDocumentChunkVectorsCompanion({
    this.chunkId = const Value.absent(),
    this.embedding = const Value.absent(),
    this.embeddingModel = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectDocumentChunkVectorsCompanion.insert({
    required String chunkId,
    required Uint8List embedding,
    required String embeddingModel,
    this.rowid = const Value.absent(),
  }) : chunkId = Value(chunkId),
       embedding = Value(embedding),
       embeddingModel = Value(embeddingModel);
  static Insertable<ProjectDocumentChunkVector> custom({
    Expression<String>? chunkId,
    Expression<Uint8List>? embedding,
    Expression<String>? embeddingModel,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (chunkId != null) 'chunk_id': chunkId,
      if (embedding != null) 'embedding': embedding,
      if (embeddingModel != null) 'embedding_model': embeddingModel,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectDocumentChunkVectorsCompanion copyWith({
    Value<String>? chunkId,
    Value<Uint8List>? embedding,
    Value<String>? embeddingModel,
    Value<int>? rowid,
  }) {
    return ProjectDocumentChunkVectorsCompanion(
      chunkId: chunkId ?? this.chunkId,
      embedding: embedding ?? this.embedding,
      embeddingModel: embeddingModel ?? this.embeddingModel,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (chunkId.present) {
      map['chunk_id'] = Variable<String>(chunkId.value);
    }
    if (embedding.present) {
      map['embedding'] = Variable<Uint8List>(embedding.value);
    }
    if (embeddingModel.present) {
      map['embedding_model'] = Variable<String>(embeddingModel.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectDocumentChunkVectorsCompanion(')
          ..write('chunkId: $chunkId, ')
          ..write('embedding: $embedding, ')
          ..write('embeddingModel: $embeddingModel, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$HelixDatabase extends GeneratedDatabase {
  _$HelixDatabase(QueryExecutor e) : super(e);
  $HelixDatabaseManager get managers => $HelixDatabaseManager(this);
  late final $ConversationsTable conversations = $ConversationsTable(this);
  late final $ConversationSegmentsTable conversationSegments =
      $ConversationSegmentsTable(this);
  late final $ConversationAiCostEntriesTable conversationAiCostEntries =
      $ConversationAiCostEntriesTable(this);
  late final $TopicsTable topics = $TopicsTable(this);
  late final $FactsTable facts = $FactsTable(this);
  late final $DailyMemoriesTable dailyMemories = $DailyMemoriesTable(this);
  late final $VoiceNotesTable voiceNotes = $VoiceNotesTable(this);
  late final $TodosTable todos = $TodosTable(this);
  late final $BuzzHistoryEntriesTable buzzHistoryEntries =
      $BuzzHistoryEntriesTable(this);
  late final $KnowledgeEntitiesTable knowledgeEntities =
      $KnowledgeEntitiesTable(this);
  late final $KnowledgeRelationshipsTable knowledgeRelationships =
      $KnowledgeRelationshipsTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $ProjectsTable projects = $ProjectsTable(this);
  late final $ProjectDocumentsTable projectDocuments = $ProjectDocumentsTable(
    this,
  );
  late final $ProjectDocumentChunksTable projectDocumentChunks =
      $ProjectDocumentChunksTable(this);
  late final $ProjectDocumentChunkVectorsTable projectDocumentChunkVectors =
      $ProjectDocumentChunkVectorsTable(this);
  late final ConversationDao conversationDao = ConversationDao(
    this as HelixDatabase,
  );
  late final FactsDao factsDao = FactsDao(this as HelixDatabase);
  late final KnowledgeDao knowledgeDao = KnowledgeDao(this as HelixDatabase);
  late final TodoDao todoDao = TodoDao(this as HelixDatabase);
  late final VoiceNoteDao voiceNoteDao = VoiceNoteDao(this as HelixDatabase);
  late final DailyMemoryDao dailyMemoryDao = DailyMemoryDao(
    this as HelixDatabase,
  );
  late final SearchDao searchDao = SearchDao(this as HelixDatabase);
  late final ProjectDao projectDao = ProjectDao(this as HelixDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    conversations,
    conversationSegments,
    conversationAiCostEntries,
    topics,
    facts,
    dailyMemories,
    voiceNotes,
    todos,
    buzzHistoryEntries,
    knowledgeEntities,
    knowledgeRelationships,
    userProfiles,
    projects,
    projectDocuments,
    projectDocumentChunks,
    projectDocumentChunkVectors,
  ];
}

typedef $$ConversationsTableCreateCompanionBuilder =
    ConversationsCompanion Function({
      required String id,
      required int startedAt,
      Value<int?> endedAt,
      Value<String> mode,
      Value<String?> title,
      Value<String?> summary,
      Value<String?> sentiment,
      Value<String?> toneAnalysis,
      Value<bool> isProcessed,
      Value<bool> silenceEnded,
      Value<String> source,
      Value<String?> audioFilePath,
      Value<int?> costSmartUsdMicros,
      Value<int?> costLightUsdMicros,
      Value<int?> costTranscriptionUsdMicros,
      Value<int?> costTotalUsdMicros,
      Value<int> rowid,
    });
typedef $$ConversationsTableUpdateCompanionBuilder =
    ConversationsCompanion Function({
      Value<String> id,
      Value<int> startedAt,
      Value<int?> endedAt,
      Value<String> mode,
      Value<String?> title,
      Value<String?> summary,
      Value<String?> sentiment,
      Value<String?> toneAnalysis,
      Value<bool> isProcessed,
      Value<bool> silenceEnded,
      Value<String> source,
      Value<String?> audioFilePath,
      Value<int?> costSmartUsdMicros,
      Value<int?> costLightUsdMicros,
      Value<int?> costTranscriptionUsdMicros,
      Value<int?> costTotalUsdMicros,
      Value<int> rowid,
    });

final class $$ConversationsTableReferences
    extends BaseReferences<_$HelixDatabase, $ConversationsTable, Conversation> {
  $$ConversationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $ConversationSegmentsTable,
    List<ConversationSegment>
  >
  _conversationSegmentsRefsTable(_$HelixDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.conversationSegments,
        aliasName: $_aliasNameGenerator(
          db.conversations.id,
          db.conversationSegments.conversationId,
        ),
      );

  $$ConversationSegmentsTableProcessedTableManager
  get conversationSegmentsRefs {
    final manager = $$ConversationSegmentsTableTableManager(
      $_db,
      $_db.conversationSegments,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _conversationSegmentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ConversationAiCostEntriesTable,
    List<ConversationAiCostEntry>
  >
  _conversationAiCostEntriesRefsTable(_$HelixDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.conversationAiCostEntries,
        aliasName: $_aliasNameGenerator(
          db.conversations.id,
          db.conversationAiCostEntries.conversationId,
        ),
      );

  $$ConversationAiCostEntriesTableProcessedTableManager
  get conversationAiCostEntriesRefs {
    final manager = $$ConversationAiCostEntriesTableTableManager(
      $_db,
      $_db.conversationAiCostEntries,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _conversationAiCostEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TopicsTable, List<Topic>> _topicsRefsTable(
    _$HelixDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.topics,
    aliasName: $_aliasNameGenerator(
      db.conversations.id,
      db.topics.conversationId,
    ),
  );

  $$TopicsTableProcessedTableManager get topicsRefs {
    final manager = $$TopicsTableTableManager(
      $_db,
      $_db.topics,
    ).filter((f) => f.conversationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_topicsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ConversationsTableFilterComposer
    extends Composer<_$HelixDatabase, $ConversationsTable> {
  $$ConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentiment => $composableBuilder(
    column: $table.sentiment,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toneAnalysis => $composableBuilder(
    column: $table.toneAnalysis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isProcessed => $composableBuilder(
    column: $table.isProcessed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get silenceEnded => $composableBuilder(
    column: $table.silenceEnded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get audioFilePath => $composableBuilder(
    column: $table.audioFilePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costSmartUsdMicros => $composableBuilder(
    column: $table.costSmartUsdMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costLightUsdMicros => $composableBuilder(
    column: $table.costLightUsdMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costTranscriptionUsdMicros => $composableBuilder(
    column: $table.costTranscriptionUsdMicros,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get costTotalUsdMicros => $composableBuilder(
    column: $table.costTotalUsdMicros,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> conversationSegmentsRefs(
    Expression<bool> Function($$ConversationSegmentsTableFilterComposer f) f,
  ) {
    final $$ConversationSegmentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.conversationSegments,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationSegmentsTableFilterComposer(
            $db: $db,
            $table: $db.conversationSegments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> conversationAiCostEntriesRefs(
    Expression<bool> Function($$ConversationAiCostEntriesTableFilterComposer f)
    f,
  ) {
    final $$ConversationAiCostEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.conversationAiCostEntries,
          getReferencedColumn: (t) => t.conversationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationAiCostEntriesTableFilterComposer(
                $db: $db,
                $table: $db.conversationAiCostEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> topicsRefs(
    Expression<bool> Function($$TopicsTableFilterComposer f) f,
  ) {
    final $$TopicsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.topics,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TopicsTableFilterComposer(
            $db: $db,
            $table: $db.topics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableOrderingComposer
    extends Composer<_$HelixDatabase, $ConversationsTable> {
  $$ConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentiment => $composableBuilder(
    column: $table.sentiment,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toneAnalysis => $composableBuilder(
    column: $table.toneAnalysis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isProcessed => $composableBuilder(
    column: $table.isProcessed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get silenceEnded => $composableBuilder(
    column: $table.silenceEnded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get audioFilePath => $composableBuilder(
    column: $table.audioFilePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costSmartUsdMicros => $composableBuilder(
    column: $table.costSmartUsdMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costLightUsdMicros => $composableBuilder(
    column: $table.costLightUsdMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costTranscriptionUsdMicros => $composableBuilder(
    column: $table.costTranscriptionUsdMicros,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get costTotalUsdMicros => $composableBuilder(
    column: $table.costTotalUsdMicros,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationsTableAnnotationComposer
    extends Composer<_$HelixDatabase, $ConversationsTable> {
  $$ConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get sentiment =>
      $composableBuilder(column: $table.sentiment, builder: (column) => column);

  GeneratedColumn<String> get toneAnalysis => $composableBuilder(
    column: $table.toneAnalysis,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isProcessed => $composableBuilder(
    column: $table.isProcessed,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get silenceEnded => $composableBuilder(
    column: $table.silenceEnded,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get audioFilePath => $composableBuilder(
    column: $table.audioFilePath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get costSmartUsdMicros => $composableBuilder(
    column: $table.costSmartUsdMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get costLightUsdMicros => $composableBuilder(
    column: $table.costLightUsdMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get costTranscriptionUsdMicros => $composableBuilder(
    column: $table.costTranscriptionUsdMicros,
    builder: (column) => column,
  );

  GeneratedColumn<int> get costTotalUsdMicros => $composableBuilder(
    column: $table.costTotalUsdMicros,
    builder: (column) => column,
  );

  Expression<T> conversationSegmentsRefs<T extends Object>(
    Expression<T> Function($$ConversationSegmentsTableAnnotationComposer a) f,
  ) {
    final $$ConversationSegmentsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.conversationSegments,
          getReferencedColumn: (t) => t.conversationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationSegmentsTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationSegments,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> conversationAiCostEntriesRefs<T extends Object>(
    Expression<T> Function($$ConversationAiCostEntriesTableAnnotationComposer a)
    f,
  ) {
    final $$ConversationAiCostEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.conversationAiCostEntries,
          getReferencedColumn: (t) => t.conversationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ConversationAiCostEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.conversationAiCostEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> topicsRefs<T extends Object>(
    Expression<T> Function($$TopicsTableAnnotationComposer a) f,
  ) {
    final $$TopicsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.topics,
      getReferencedColumn: (t) => t.conversationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TopicsTableAnnotationComposer(
            $db: $db,
            $table: $db.topics,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ConversationsTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $ConversationsTable,
          Conversation,
          $$ConversationsTableFilterComposer,
          $$ConversationsTableOrderingComposer,
          $$ConversationsTableAnnotationComposer,
          $$ConversationsTableCreateCompanionBuilder,
          $$ConversationsTableUpdateCompanionBuilder,
          (Conversation, $$ConversationsTableReferences),
          Conversation,
          PrefetchHooks Function({
            bool conversationSegmentsRefs,
            bool conversationAiCostEntriesRefs,
            bool topicsRefs,
          })
        > {
  $$ConversationsTableTableManager(
    _$HelixDatabase db,
    $ConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int?> endedAt = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> sentiment = const Value.absent(),
                Value<String?> toneAnalysis = const Value.absent(),
                Value<bool> isProcessed = const Value.absent(),
                Value<bool> silenceEnded = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> audioFilePath = const Value.absent(),
                Value<int?> costSmartUsdMicros = const Value.absent(),
                Value<int?> costLightUsdMicros = const Value.absent(),
                Value<int?> costTranscriptionUsdMicros = const Value.absent(),
                Value<int?> costTotalUsdMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                mode: mode,
                title: title,
                summary: summary,
                sentiment: sentiment,
                toneAnalysis: toneAnalysis,
                isProcessed: isProcessed,
                silenceEnded: silenceEnded,
                source: source,
                audioFilePath: audioFilePath,
                costSmartUsdMicros: costSmartUsdMicros,
                costLightUsdMicros: costLightUsdMicros,
                costTranscriptionUsdMicros: costTranscriptionUsdMicros,
                costTotalUsdMicros: costTotalUsdMicros,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int startedAt,
                Value<int?> endedAt = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String?> sentiment = const Value.absent(),
                Value<String?> toneAnalysis = const Value.absent(),
                Value<bool> isProcessed = const Value.absent(),
                Value<bool> silenceEnded = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> audioFilePath = const Value.absent(),
                Value<int?> costSmartUsdMicros = const Value.absent(),
                Value<int?> costLightUsdMicros = const Value.absent(),
                Value<int?> costTranscriptionUsdMicros = const Value.absent(),
                Value<int?> costTotalUsdMicros = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationsCompanion.insert(
                id: id,
                startedAt: startedAt,
                endedAt: endedAt,
                mode: mode,
                title: title,
                summary: summary,
                sentiment: sentiment,
                toneAnalysis: toneAnalysis,
                isProcessed: isProcessed,
                silenceEnded: silenceEnded,
                source: source,
                audioFilePath: audioFilePath,
                costSmartUsdMicros: costSmartUsdMicros,
                costLightUsdMicros: costLightUsdMicros,
                costTranscriptionUsdMicros: costTranscriptionUsdMicros,
                costTotalUsdMicros: costTotalUsdMicros,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConversationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                conversationSegmentsRefs = false,
                conversationAiCostEntriesRefs = false,
                topicsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (conversationSegmentsRefs) db.conversationSegments,
                    if (conversationAiCostEntriesRefs)
                      db.conversationAiCostEntries,
                    if (topicsRefs) db.topics,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (conversationSegmentsRefs)
                        await $_getPrefetchedData<
                          Conversation,
                          $ConversationsTable,
                          ConversationSegment
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationsTableReferences
                              ._conversationSegmentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationsTableReferences(
                                db,
                                table,
                                p0,
                              ).conversationSegmentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.conversationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (conversationAiCostEntriesRefs)
                        await $_getPrefetchedData<
                          Conversation,
                          $ConversationsTable,
                          ConversationAiCostEntry
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationsTableReferences
                              ._conversationAiCostEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationsTableReferences(
                                db,
                                table,
                                p0,
                              ).conversationAiCostEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.conversationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (topicsRefs)
                        await $_getPrefetchedData<
                          Conversation,
                          $ConversationsTable,
                          Topic
                        >(
                          currentTable: table,
                          referencedTable: $$ConversationsTableReferences
                              ._topicsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ConversationsTableReferences(
                                db,
                                table,
                                p0,
                              ).topicsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.conversationId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $ConversationsTable,
      Conversation,
      $$ConversationsTableFilterComposer,
      $$ConversationsTableOrderingComposer,
      $$ConversationsTableAnnotationComposer,
      $$ConversationsTableCreateCompanionBuilder,
      $$ConversationsTableUpdateCompanionBuilder,
      (Conversation, $$ConversationsTableReferences),
      Conversation,
      PrefetchHooks Function({
        bool conversationSegmentsRefs,
        bool conversationAiCostEntriesRefs,
        bool topicsRefs,
      })
    >;
typedef $$ConversationSegmentsTableCreateCompanionBuilder =
    ConversationSegmentsCompanion Function({
      required String id,
      required String conversationId,
      required int segmentIndex,
      required String text_,
      Value<String?> speakerLabel,
      required int startedAt,
      Value<int?> endedAt,
      Value<String?> topicId,
      Value<int> rowid,
    });
typedef $$ConversationSegmentsTableUpdateCompanionBuilder =
    ConversationSegmentsCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<int> segmentIndex,
      Value<String> text_,
      Value<String?> speakerLabel,
      Value<int> startedAt,
      Value<int?> endedAt,
      Value<String?> topicId,
      Value<int> rowid,
    });

final class $$ConversationSegmentsTableReferences
    extends
        BaseReferences<
          _$HelixDatabase,
          $ConversationSegmentsTable,
          ConversationSegment
        > {
  $$ConversationSegmentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationsTable _conversationIdTable(_$HelixDatabase db) =>
      db.conversations.createAlias(
        $_aliasNameGenerator(
          db.conversationSegments.conversationId,
          db.conversations.id,
        ),
      );

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ConversationSegmentsTableFilterComposer
    extends Composer<_$HelixDatabase, $ConversationSegmentsTable> {
  $$ConversationSegmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get text_ => $composableBuilder(
    column: $table.text_,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speakerLabel => $composableBuilder(
    column: $table.speakerLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationSegmentsTableOrderingComposer
    extends Composer<_$HelixDatabase, $ConversationSegmentsTable> {
  $$ConversationSegmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get text_ => $composableBuilder(
    column: $table.text_,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speakerLabel => $composableBuilder(
    column: $table.speakerLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topicId => $composableBuilder(
    column: $table.topicId,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationSegmentsTableAnnotationComposer
    extends Composer<_$HelixDatabase, $ConversationSegmentsTable> {
  $$ConversationSegmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get segmentIndex => $composableBuilder(
    column: $table.segmentIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get text_ =>
      $composableBuilder(column: $table.text_, builder: (column) => column);

  GeneratedColumn<String> get speakerLabel => $composableBuilder(
    column: $table.speakerLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get topicId =>
      $composableBuilder(column: $table.topicId, builder: (column) => column);

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationSegmentsTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $ConversationSegmentsTable,
          ConversationSegment,
          $$ConversationSegmentsTableFilterComposer,
          $$ConversationSegmentsTableOrderingComposer,
          $$ConversationSegmentsTableAnnotationComposer,
          $$ConversationSegmentsTableCreateCompanionBuilder,
          $$ConversationSegmentsTableUpdateCompanionBuilder,
          (ConversationSegment, $$ConversationSegmentsTableReferences),
          ConversationSegment,
          PrefetchHooks Function({bool conversationId})
        > {
  $$ConversationSegmentsTableTableManager(
    _$HelixDatabase db,
    $ConversationSegmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationSegmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationSegmentsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConversationSegmentsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<int> segmentIndex = const Value.absent(),
                Value<String> text_ = const Value.absent(),
                Value<String?> speakerLabel = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int?> endedAt = const Value.absent(),
                Value<String?> topicId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationSegmentsCompanion(
                id: id,
                conversationId: conversationId,
                segmentIndex: segmentIndex,
                text_: text_,
                speakerLabel: speakerLabel,
                startedAt: startedAt,
                endedAt: endedAt,
                topicId: topicId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required int segmentIndex,
                required String text_,
                Value<String?> speakerLabel = const Value.absent(),
                required int startedAt,
                Value<int?> endedAt = const Value.absent(),
                Value<String?> topicId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationSegmentsCompanion.insert(
                id: id,
                conversationId: conversationId,
                segmentIndex: segmentIndex,
                text_: text_,
                speakerLabel: speakerLabel,
                startedAt: startedAt,
                endedAt: endedAt,
                topicId: topicId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConversationSegmentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (conversationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.conversationId,
                                referencedTable:
                                    $$ConversationSegmentsTableReferences
                                        ._conversationIdTable(db),
                                referencedColumn:
                                    $$ConversationSegmentsTableReferences
                                        ._conversationIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ConversationSegmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $ConversationSegmentsTable,
      ConversationSegment,
      $$ConversationSegmentsTableFilterComposer,
      $$ConversationSegmentsTableOrderingComposer,
      $$ConversationSegmentsTableAnnotationComposer,
      $$ConversationSegmentsTableCreateCompanionBuilder,
      $$ConversationSegmentsTableUpdateCompanionBuilder,
      (ConversationSegment, $$ConversationSegmentsTableReferences),
      ConversationSegment,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$ConversationAiCostEntriesTableCreateCompanionBuilder =
    ConversationAiCostEntriesCompanion Function({
      required String id,
      required String conversationId,
      required String operationType,
      required String providerId,
      required String modelId,
      Value<int> inputTokens,
      Value<int> outputTokens,
      Value<int> cachedInputTokens,
      Value<int> audioInputTokens,
      Value<int> audioOutputTokens,
      Value<double?> costUsd,
      Value<String> currency,
      Value<String> status,
      required int startedAt,
      Value<int?> completedAt,
      Value<String?> modelRole,
      Value<int> rowid,
    });
typedef $$ConversationAiCostEntriesTableUpdateCompanionBuilder =
    ConversationAiCostEntriesCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> operationType,
      Value<String> providerId,
      Value<String> modelId,
      Value<int> inputTokens,
      Value<int> outputTokens,
      Value<int> cachedInputTokens,
      Value<int> audioInputTokens,
      Value<int> audioOutputTokens,
      Value<double?> costUsd,
      Value<String> currency,
      Value<String> status,
      Value<int> startedAt,
      Value<int?> completedAt,
      Value<String?> modelRole,
      Value<int> rowid,
    });

final class $$ConversationAiCostEntriesTableReferences
    extends
        BaseReferences<
          _$HelixDatabase,
          $ConversationAiCostEntriesTable,
          ConversationAiCostEntry
        > {
  $$ConversationAiCostEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ConversationsTable _conversationIdTable(_$HelixDatabase db) =>
      db.conversations.createAlias(
        $_aliasNameGenerator(
          db.conversationAiCostEntries.conversationId,
          db.conversations.id,
        ),
      );

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ConversationAiCostEntriesTableFilterComposer
    extends Composer<_$HelixDatabase, $ConversationAiCostEntriesTable> {
  $$ConversationAiCostEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cachedInputTokens => $composableBuilder(
    column: $table.cachedInputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioInputTokens => $composableBuilder(
    column: $table.audioInputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get audioOutputTokens => $composableBuilder(
    column: $table.audioOutputTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costUsd => $composableBuilder(
    column: $table.costUsd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelRole => $composableBuilder(
    column: $table.modelRole,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationAiCostEntriesTableOrderingComposer
    extends Composer<_$HelixDatabase, $ConversationAiCostEntriesTable> {
  $$ConversationAiCostEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelId => $composableBuilder(
    column: $table.modelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cachedInputTokens => $composableBuilder(
    column: $table.cachedInputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioInputTokens => $composableBuilder(
    column: $table.audioInputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get audioOutputTokens => $composableBuilder(
    column: $table.audioOutputTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costUsd => $composableBuilder(
    column: $table.costUsd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currency => $composableBuilder(
    column: $table.currency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelRole => $composableBuilder(
    column: $table.modelRole,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationAiCostEntriesTableAnnotationComposer
    extends Composer<_$HelixDatabase, $ConversationAiCostEntriesTable> {
  $$ConversationAiCostEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operationType => $composableBuilder(
    column: $table.operationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelId =>
      $composableBuilder(column: $table.modelId, builder: (column) => column);

  GeneratedColumn<int> get inputTokens => $composableBuilder(
    column: $table.inputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get outputTokens => $composableBuilder(
    column: $table.outputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cachedInputTokens => $composableBuilder(
    column: $table.cachedInputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get audioInputTokens => $composableBuilder(
    column: $table.audioInputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get audioOutputTokens => $composableBuilder(
    column: $table.audioOutputTokens,
    builder: (column) => column,
  );

  GeneratedColumn<double> get costUsd =>
      $composableBuilder(column: $table.costUsd, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get modelRole =>
      $composableBuilder(column: $table.modelRole, builder: (column) => column);

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ConversationAiCostEntriesTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $ConversationAiCostEntriesTable,
          ConversationAiCostEntry,
          $$ConversationAiCostEntriesTableFilterComposer,
          $$ConversationAiCostEntriesTableOrderingComposer,
          $$ConversationAiCostEntriesTableAnnotationComposer,
          $$ConversationAiCostEntriesTableCreateCompanionBuilder,
          $$ConversationAiCostEntriesTableUpdateCompanionBuilder,
          (ConversationAiCostEntry, $$ConversationAiCostEntriesTableReferences),
          ConversationAiCostEntry,
          PrefetchHooks Function({bool conversationId})
        > {
  $$ConversationAiCostEntriesTableTableManager(
    _$HelixDatabase db,
    $ConversationAiCostEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationAiCostEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ConversationAiCostEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConversationAiCostEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> operationType = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String> modelId = const Value.absent(),
                Value<int> inputTokens = const Value.absent(),
                Value<int> outputTokens = const Value.absent(),
                Value<int> cachedInputTokens = const Value.absent(),
                Value<int> audioInputTokens = const Value.absent(),
                Value<int> audioOutputTokens = const Value.absent(),
                Value<double?> costUsd = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> startedAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<String?> modelRole = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationAiCostEntriesCompanion(
                id: id,
                conversationId: conversationId,
                operationType: operationType,
                providerId: providerId,
                modelId: modelId,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cachedInputTokens: cachedInputTokens,
                audioInputTokens: audioInputTokens,
                audioOutputTokens: audioOutputTokens,
                costUsd: costUsd,
                currency: currency,
                status: status,
                startedAt: startedAt,
                completedAt: completedAt,
                modelRole: modelRole,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String operationType,
                required String providerId,
                required String modelId,
                Value<int> inputTokens = const Value.absent(),
                Value<int> outputTokens = const Value.absent(),
                Value<int> cachedInputTokens = const Value.absent(),
                Value<int> audioInputTokens = const Value.absent(),
                Value<int> audioOutputTokens = const Value.absent(),
                Value<double?> costUsd = const Value.absent(),
                Value<String> currency = const Value.absent(),
                Value<String> status = const Value.absent(),
                required int startedAt,
                Value<int?> completedAt = const Value.absent(),
                Value<String?> modelRole = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationAiCostEntriesCompanion.insert(
                id: id,
                conversationId: conversationId,
                operationType: operationType,
                providerId: providerId,
                modelId: modelId,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cachedInputTokens: cachedInputTokens,
                audioInputTokens: audioInputTokens,
                audioOutputTokens: audioOutputTokens,
                costUsd: costUsd,
                currency: currency,
                status: status,
                startedAt: startedAt,
                completedAt: completedAt,
                modelRole: modelRole,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ConversationAiCostEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (conversationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.conversationId,
                                referencedTable:
                                    $$ConversationAiCostEntriesTableReferences
                                        ._conversationIdTable(db),
                                referencedColumn:
                                    $$ConversationAiCostEntriesTableReferences
                                        ._conversationIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ConversationAiCostEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $ConversationAiCostEntriesTable,
      ConversationAiCostEntry,
      $$ConversationAiCostEntriesTableFilterComposer,
      $$ConversationAiCostEntriesTableOrderingComposer,
      $$ConversationAiCostEntriesTableAnnotationComposer,
      $$ConversationAiCostEntriesTableCreateCompanionBuilder,
      $$ConversationAiCostEntriesTableUpdateCompanionBuilder,
      (ConversationAiCostEntry, $$ConversationAiCostEntriesTableReferences),
      ConversationAiCostEntry,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$TopicsTableCreateCompanionBuilder =
    TopicsCompanion Function({
      required String id,
      required String conversationId,
      required String label,
      Value<String> summary,
      Value<String> segmentRange,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$TopicsTableUpdateCompanionBuilder =
    TopicsCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> label,
      Value<String> summary,
      Value<String> segmentRange,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$TopicsTableReferences
    extends BaseReferences<_$HelixDatabase, $TopicsTable, Topic> {
  $$TopicsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ConversationsTable _conversationIdTable(_$HelixDatabase db) =>
      db.conversations.createAlias(
        $_aliasNameGenerator(db.topics.conversationId, db.conversations.id),
      );

  $$ConversationsTableProcessedTableManager get conversationId {
    final $_column = $_itemColumn<String>('conversation_id')!;

    final manager = $$ConversationsTableTableManager(
      $_db,
      $_db.conversations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_conversationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TopicsTableFilterComposer
    extends Composer<_$HelixDatabase, $TopicsTable> {
  $$TopicsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get segmentRange => $composableBuilder(
    column: $table.segmentRange,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$ConversationsTableFilterComposer get conversationId {
    final $$ConversationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableFilterComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TopicsTableOrderingComposer
    extends Composer<_$HelixDatabase, $TopicsTable> {
  $$TopicsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get segmentRange => $composableBuilder(
    column: $table.segmentRange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$ConversationsTableOrderingComposer get conversationId {
    final $$ConversationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableOrderingComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TopicsTableAnnotationComposer
    extends Composer<_$HelixDatabase, $TopicsTable> {
  $$TopicsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get segmentRange => $composableBuilder(
    column: $table.segmentRange,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$ConversationsTableAnnotationComposer get conversationId {
    final $$ConversationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.conversationId,
      referencedTable: $db.conversations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ConversationsTableAnnotationComposer(
            $db: $db,
            $table: $db.conversations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TopicsTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $TopicsTable,
          Topic,
          $$TopicsTableFilterComposer,
          $$TopicsTableOrderingComposer,
          $$TopicsTableAnnotationComposer,
          $$TopicsTableCreateCompanionBuilder,
          $$TopicsTableUpdateCompanionBuilder,
          (Topic, $$TopicsTableReferences),
          Topic,
          PrefetchHooks Function({bool conversationId})
        > {
  $$TopicsTableTableManager(_$HelixDatabase db, $TopicsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TopicsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TopicsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TopicsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> summary = const Value.absent(),
                Value<String> segmentRange = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TopicsCompanion(
                id: id,
                conversationId: conversationId,
                label: label,
                summary: summary,
                segmentRange: segmentRange,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String label,
                Value<String> summary = const Value.absent(),
                Value<String> segmentRange = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TopicsCompanion.insert(
                id: id,
                conversationId: conversationId,
                label: label,
                summary: summary,
                segmentRange: segmentRange,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TopicsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({conversationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (conversationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.conversationId,
                                referencedTable: $$TopicsTableReferences
                                    ._conversationIdTable(db),
                                referencedColumn: $$TopicsTableReferences
                                    ._conversationIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TopicsTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $TopicsTable,
      Topic,
      $$TopicsTableFilterComposer,
      $$TopicsTableOrderingComposer,
      $$TopicsTableAnnotationComposer,
      $$TopicsTableCreateCompanionBuilder,
      $$TopicsTableUpdateCompanionBuilder,
      (Topic, $$TopicsTableReferences),
      Topic,
      PrefetchHooks Function({bool conversationId})
    >;
typedef $$FactsTableCreateCompanionBuilder =
    FactsCompanion Function({
      required String id,
      Value<String?> conversationId,
      required String category,
      required String content,
      Value<String?> sourceQuote,
      Value<double> confidence,
      Value<String> status,
      Value<String?> dedupeKey,
      required int createdAt,
      Value<int?> confirmedAt,
      Value<int> rowid,
    });
typedef $$FactsTableUpdateCompanionBuilder =
    FactsCompanion Function({
      Value<String> id,
      Value<String?> conversationId,
      Value<String> category,
      Value<String> content,
      Value<String?> sourceQuote,
      Value<double> confidence,
      Value<String> status,
      Value<String?> dedupeKey,
      Value<int> createdAt,
      Value<int?> confirmedAt,
      Value<int> rowid,
    });

class $$FactsTableFilterComposer
    extends Composer<_$HelixDatabase, $FactsTable> {
  $$FactsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceQuote => $composableBuilder(
    column: $table.sourceQuote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get confirmedAt => $composableBuilder(
    column: $table.confirmedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FactsTableOrderingComposer
    extends Composer<_$HelixDatabase, $FactsTable> {
  $$FactsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceQuote => $composableBuilder(
    column: $table.sourceQuote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get confirmedAt => $composableBuilder(
    column: $table.confirmedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FactsTableAnnotationComposer
    extends Composer<_$HelixDatabase, $FactsTable> {
  $$FactsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get sourceQuote => $composableBuilder(
    column: $table.sourceQuote,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get confirmedAt => $composableBuilder(
    column: $table.confirmedAt,
    builder: (column) => column,
  );
}

class $$FactsTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $FactsTable,
          Fact,
          $$FactsTableFilterComposer,
          $$FactsTableOrderingComposer,
          $$FactsTableAnnotationComposer,
          $$FactsTableCreateCompanionBuilder,
          $$FactsTableUpdateCompanionBuilder,
          (Fact, BaseReferences<_$HelixDatabase, $FactsTable, Fact>),
          Fact,
          PrefetchHooks Function()
        > {
  $$FactsTableTableManager(_$HelixDatabase db, $FactsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FactsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FactsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FactsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> conversationId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> sourceQuote = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> confirmedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FactsCompanion(
                id: id,
                conversationId: conversationId,
                category: category,
                content: content,
                sourceQuote: sourceQuote,
                confidence: confidence,
                status: status,
                dedupeKey: dedupeKey,
                createdAt: createdAt,
                confirmedAt: confirmedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> conversationId = const Value.absent(),
                required String category,
                required String content,
                Value<String?> sourceQuote = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
                required int createdAt,
                Value<int?> confirmedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FactsCompanion.insert(
                id: id,
                conversationId: conversationId,
                category: category,
                content: content,
                sourceQuote: sourceQuote,
                confidence: confidence,
                status: status,
                dedupeKey: dedupeKey,
                createdAt: createdAt,
                confirmedAt: confirmedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FactsTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $FactsTable,
      Fact,
      $$FactsTableFilterComposer,
      $$FactsTableOrderingComposer,
      $$FactsTableAnnotationComposer,
      $$FactsTableCreateCompanionBuilder,
      $$FactsTableUpdateCompanionBuilder,
      (Fact, BaseReferences<_$HelixDatabase, $FactsTable, Fact>),
      Fact,
      PrefetchHooks Function()
    >;
typedef $$DailyMemoriesTableCreateCompanionBuilder =
    DailyMemoriesCompanion Function({
      required String id,
      required String date,
      required String narrative,
      Value<String> themes,
      Value<String> conversationIds,
      required int generatedAt,
      Value<int> rowid,
    });
typedef $$DailyMemoriesTableUpdateCompanionBuilder =
    DailyMemoriesCompanion Function({
      Value<String> id,
      Value<String> date,
      Value<String> narrative,
      Value<String> themes,
      Value<String> conversationIds,
      Value<int> generatedAt,
      Value<int> rowid,
    });

class $$DailyMemoriesTableFilterComposer
    extends Composer<_$HelixDatabase, $DailyMemoriesTable> {
  $$DailyMemoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get narrative => $composableBuilder(
    column: $table.narrative,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themes => $composableBuilder(
    column: $table.themes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationIds => $composableBuilder(
    column: $table.conversationIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyMemoriesTableOrderingComposer
    extends Composer<_$HelixDatabase, $DailyMemoriesTable> {
  $$DailyMemoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get narrative => $composableBuilder(
    column: $table.narrative,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themes => $composableBuilder(
    column: $table.themes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationIds => $composableBuilder(
    column: $table.conversationIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyMemoriesTableAnnotationComposer
    extends Composer<_$HelixDatabase, $DailyMemoriesTable> {
  $$DailyMemoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get narrative =>
      $composableBuilder(column: $table.narrative, builder: (column) => column);

  GeneratedColumn<String> get themes =>
      $composableBuilder(column: $table.themes, builder: (column) => column);

  GeneratedColumn<String> get conversationIds => $composableBuilder(
    column: $table.conversationIds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get generatedAt => $composableBuilder(
    column: $table.generatedAt,
    builder: (column) => column,
  );
}

class $$DailyMemoriesTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $DailyMemoriesTable,
          DailyMemory,
          $$DailyMemoriesTableFilterComposer,
          $$DailyMemoriesTableOrderingComposer,
          $$DailyMemoriesTableAnnotationComposer,
          $$DailyMemoriesTableCreateCompanionBuilder,
          $$DailyMemoriesTableUpdateCompanionBuilder,
          (
            DailyMemory,
            BaseReferences<_$HelixDatabase, $DailyMemoriesTable, DailyMemory>,
          ),
          DailyMemory,
          PrefetchHooks Function()
        > {
  $$DailyMemoriesTableTableManager(
    _$HelixDatabase db,
    $DailyMemoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyMemoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyMemoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyMemoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String> narrative = const Value.absent(),
                Value<String> themes = const Value.absent(),
                Value<String> conversationIds = const Value.absent(),
                Value<int> generatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyMemoriesCompanion(
                id: id,
                date: date,
                narrative: narrative,
                themes: themes,
                conversationIds: conversationIds,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String date,
                required String narrative,
                Value<String> themes = const Value.absent(),
                Value<String> conversationIds = const Value.absent(),
                required int generatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DailyMemoriesCompanion.insert(
                id: id,
                date: date,
                narrative: narrative,
                themes: themes,
                conversationIds: conversationIds,
                generatedAt: generatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyMemoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $DailyMemoriesTable,
      DailyMemory,
      $$DailyMemoriesTableFilterComposer,
      $$DailyMemoriesTableOrderingComposer,
      $$DailyMemoriesTableAnnotationComposer,
      $$DailyMemoriesTableCreateCompanionBuilder,
      $$DailyMemoriesTableUpdateCompanionBuilder,
      (
        DailyMemory,
        BaseReferences<_$HelixDatabase, $DailyMemoriesTable, DailyMemory>,
      ),
      DailyMemory,
      PrefetchHooks Function()
    >;
typedef $$VoiceNotesTableCreateCompanionBuilder =
    VoiceNotesCompanion Function({
      required String id,
      required int createdAt,
      Value<int> durationMs,
      Value<String?> transcript,
      Value<String?> summary,
      Value<String> tags,
      Value<int> rowid,
    });
typedef $$VoiceNotesTableUpdateCompanionBuilder =
    VoiceNotesCompanion Function({
      Value<String> id,
      Value<int> createdAt,
      Value<int> durationMs,
      Value<String?> transcript,
      Value<String?> summary,
      Value<String> tags,
      Value<int> rowid,
    });

class $$VoiceNotesTableFilterComposer
    extends Composer<_$HelixDatabase, $VoiceNotesTable> {
  $$VoiceNotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VoiceNotesTableOrderingComposer
    extends Composer<_$HelixDatabase, $VoiceNotesTable> {
  $$VoiceNotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tags => $composableBuilder(
    column: $table.tags,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VoiceNotesTableAnnotationComposer
    extends Composer<_$HelixDatabase, $VoiceNotesTable> {
  $$VoiceNotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<String> get transcript => $composableBuilder(
    column: $table.transcript,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);
}

class $$VoiceNotesTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $VoiceNotesTable,
          VoiceNote,
          $$VoiceNotesTableFilterComposer,
          $$VoiceNotesTableOrderingComposer,
          $$VoiceNotesTableAnnotationComposer,
          $$VoiceNotesTableCreateCompanionBuilder,
          $$VoiceNotesTableUpdateCompanionBuilder,
          (
            VoiceNote,
            BaseReferences<_$HelixDatabase, $VoiceNotesTable, VoiceNote>,
          ),
          VoiceNote,
          PrefetchHooks Function()
        > {
  $$VoiceNotesTableTableManager(_$HelixDatabase db, $VoiceNotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VoiceNotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VoiceNotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VoiceNotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoiceNotesCompanion(
                id: id,
                createdAt: createdAt,
                durationMs: durationMs,
                transcript: transcript,
                summary: summary,
                tags: tags,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int createdAt,
                Value<int> durationMs = const Value.absent(),
                Value<String?> transcript = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> tags = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VoiceNotesCompanion.insert(
                id: id,
                createdAt: createdAt,
                durationMs: durationMs,
                transcript: transcript,
                summary: summary,
                tags: tags,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VoiceNotesTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $VoiceNotesTable,
      VoiceNote,
      $$VoiceNotesTableFilterComposer,
      $$VoiceNotesTableOrderingComposer,
      $$VoiceNotesTableAnnotationComposer,
      $$VoiceNotesTableCreateCompanionBuilder,
      $$VoiceNotesTableUpdateCompanionBuilder,
      (VoiceNote, BaseReferences<_$HelixDatabase, $VoiceNotesTable, VoiceNote>),
      VoiceNote,
      PrefetchHooks Function()
    >;
typedef $$TodosTableCreateCompanionBuilder =
    TodosCompanion Function({
      required String id,
      Value<String?> conversationId,
      required String content,
      Value<bool> isCompleted,
      Value<int?> dueDate,
      required int createdAt,
      Value<int?> completedAt,
      Value<String> source,
      Value<int> rowid,
    });
typedef $$TodosTableUpdateCompanionBuilder =
    TodosCompanion Function({
      Value<String> id,
      Value<String?> conversationId,
      Value<String> content,
      Value<bool> isCompleted,
      Value<int?> dueDate,
      Value<int> createdAt,
      Value<int?> completedAt,
      Value<String> source,
      Value<int> rowid,
    });

class $$TodosTableFilterComposer
    extends Composer<_$HelixDatabase, $TodosTable> {
  $$TodosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TodosTableOrderingComposer
    extends Composer<_$HelixDatabase, $TodosTable> {
  $$TodosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodosTableAnnotationComposer
    extends Composer<_$HelixDatabase, $TodosTable> {
  $$TodosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$TodosTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $TodosTable,
          Todo,
          $$TodosTableFilterComposer,
          $$TodosTableOrderingComposer,
          $$TodosTableAnnotationComposer,
          $$TodosTableCreateCompanionBuilder,
          $$TodosTableUpdateCompanionBuilder,
          (Todo, BaseReferences<_$HelixDatabase, $TodosTable, Todo>),
          Todo,
          PrefetchHooks Function()
        > {
  $$TodosTableTableManager(_$HelixDatabase db, $TodosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> conversationId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<int?> dueDate = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> completedAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodosCompanion(
                id: id,
                conversationId: conversationId,
                content: content,
                isCompleted: isCompleted,
                dueDate: dueDate,
                createdAt: createdAt,
                completedAt: completedAt,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> conversationId = const Value.absent(),
                required String content,
                Value<bool> isCompleted = const Value.absent(),
                Value<int?> dueDate = const Value.absent(),
                required int createdAt,
                Value<int?> completedAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodosCompanion.insert(
                id: id,
                conversationId: conversationId,
                content: content,
                isCompleted: isCompleted,
                dueDate: dueDate,
                createdAt: createdAt,
                completedAt: completedAt,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TodosTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $TodosTable,
      Todo,
      $$TodosTableFilterComposer,
      $$TodosTableOrderingComposer,
      $$TodosTableAnnotationComposer,
      $$TodosTableCreateCompanionBuilder,
      $$TodosTableUpdateCompanionBuilder,
      (Todo, BaseReferences<_$HelixDatabase, $TodosTable, Todo>),
      Todo,
      PrefetchHooks Function()
    >;
typedef $$BuzzHistoryEntriesTableCreateCompanionBuilder =
    BuzzHistoryEntriesCompanion Function({
      required String id,
      required String question,
      required String answer,
      Value<String> citations,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$BuzzHistoryEntriesTableUpdateCompanionBuilder =
    BuzzHistoryEntriesCompanion Function({
      Value<String> id,
      Value<String> question,
      Value<String> answer,
      Value<String> citations,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$BuzzHistoryEntriesTableFilterComposer
    extends Composer<_$HelixDatabase, $BuzzHistoryEntriesTable> {
  $$BuzzHistoryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get citations => $composableBuilder(
    column: $table.citations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BuzzHistoryEntriesTableOrderingComposer
    extends Composer<_$HelixDatabase, $BuzzHistoryEntriesTable> {
  $$BuzzHistoryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get question => $composableBuilder(
    column: $table.question,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get citations => $composableBuilder(
    column: $table.citations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BuzzHistoryEntriesTableAnnotationComposer
    extends Composer<_$HelixDatabase, $BuzzHistoryEntriesTable> {
  $$BuzzHistoryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get question =>
      $composableBuilder(column: $table.question, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get citations =>
      $composableBuilder(column: $table.citations, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$BuzzHistoryEntriesTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $BuzzHistoryEntriesTable,
          BuzzHistoryEntry,
          $$BuzzHistoryEntriesTableFilterComposer,
          $$BuzzHistoryEntriesTableOrderingComposer,
          $$BuzzHistoryEntriesTableAnnotationComposer,
          $$BuzzHistoryEntriesTableCreateCompanionBuilder,
          $$BuzzHistoryEntriesTableUpdateCompanionBuilder,
          (
            BuzzHistoryEntry,
            BaseReferences<
              _$HelixDatabase,
              $BuzzHistoryEntriesTable,
              BuzzHistoryEntry
            >,
          ),
          BuzzHistoryEntry,
          PrefetchHooks Function()
        > {
  $$BuzzHistoryEntriesTableTableManager(
    _$HelixDatabase db,
    $BuzzHistoryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BuzzHistoryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BuzzHistoryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BuzzHistoryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> question = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String> citations = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BuzzHistoryEntriesCompanion(
                id: id,
                question: question,
                answer: answer,
                citations: citations,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String question,
                required String answer,
                Value<String> citations = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BuzzHistoryEntriesCompanion.insert(
                id: id,
                question: question,
                answer: answer,
                citations: citations,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BuzzHistoryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $BuzzHistoryEntriesTable,
      BuzzHistoryEntry,
      $$BuzzHistoryEntriesTableFilterComposer,
      $$BuzzHistoryEntriesTableOrderingComposer,
      $$BuzzHistoryEntriesTableAnnotationComposer,
      $$BuzzHistoryEntriesTableCreateCompanionBuilder,
      $$BuzzHistoryEntriesTableUpdateCompanionBuilder,
      (
        BuzzHistoryEntry,
        BaseReferences<
          _$HelixDatabase,
          $BuzzHistoryEntriesTable,
          BuzzHistoryEntry
        >,
      ),
      BuzzHistoryEntry,
      PrefetchHooks Function()
    >;
typedef $$KnowledgeEntitiesTableCreateCompanionBuilder =
    KnowledgeEntitiesCompanion Function({
      required String id,
      required String name,
      required String type,
      Value<String?> metadata,
      required int firstSeen,
      required int lastSeen,
      Value<int> mentionCount,
      Value<double> confidence,
      required String source,
      Value<int> rowid,
    });
typedef $$KnowledgeEntitiesTableUpdateCompanionBuilder =
    KnowledgeEntitiesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String?> metadata,
      Value<int> firstSeen,
      Value<int> lastSeen,
      Value<int> mentionCount,
      Value<double> confidence,
      Value<String> source,
      Value<int> rowid,
    });

class $$KnowledgeEntitiesTableFilterComposer
    extends Composer<_$HelixDatabase, $KnowledgeEntitiesTable> {
  $$KnowledgeEntitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mentionCount => $composableBuilder(
    column: $table.mentionCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KnowledgeEntitiesTableOrderingComposer
    extends Composer<_$HelixDatabase, $KnowledgeEntitiesTable> {
  $$KnowledgeEntitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metadata => $composableBuilder(
    column: $table.metadata,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mentionCount => $composableBuilder(
    column: $table.mentionCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KnowledgeEntitiesTableAnnotationComposer
    extends Composer<_$HelixDatabase, $KnowledgeEntitiesTable> {
  $$KnowledgeEntitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);

  GeneratedColumn<int> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<int> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<int> get mentionCount => $composableBuilder(
    column: $table.mentionCount,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$KnowledgeEntitiesTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $KnowledgeEntitiesTable,
          KnowledgeEntity,
          $$KnowledgeEntitiesTableFilterComposer,
          $$KnowledgeEntitiesTableOrderingComposer,
          $$KnowledgeEntitiesTableAnnotationComposer,
          $$KnowledgeEntitiesTableCreateCompanionBuilder,
          $$KnowledgeEntitiesTableUpdateCompanionBuilder,
          (
            KnowledgeEntity,
            BaseReferences<
              _$HelixDatabase,
              $KnowledgeEntitiesTable,
              KnowledgeEntity
            >,
          ),
          KnowledgeEntity,
          PrefetchHooks Function()
        > {
  $$KnowledgeEntitiesTableTableManager(
    _$HelixDatabase db,
    $KnowledgeEntitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KnowledgeEntitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KnowledgeEntitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KnowledgeEntitiesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> metadata = const Value.absent(),
                Value<int> firstSeen = const Value.absent(),
                Value<int> lastSeen = const Value.absent(),
                Value<int> mentionCount = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KnowledgeEntitiesCompanion(
                id: id,
                name: name,
                type: type,
                metadata: metadata,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                mentionCount: mentionCount,
                confidence: confidence,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                Value<String?> metadata = const Value.absent(),
                required int firstSeen,
                required int lastSeen,
                Value<int> mentionCount = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                required String source,
                Value<int> rowid = const Value.absent(),
              }) => KnowledgeEntitiesCompanion.insert(
                id: id,
                name: name,
                type: type,
                metadata: metadata,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                mentionCount: mentionCount,
                confidence: confidence,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KnowledgeEntitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $KnowledgeEntitiesTable,
      KnowledgeEntity,
      $$KnowledgeEntitiesTableFilterComposer,
      $$KnowledgeEntitiesTableOrderingComposer,
      $$KnowledgeEntitiesTableAnnotationComposer,
      $$KnowledgeEntitiesTableCreateCompanionBuilder,
      $$KnowledgeEntitiesTableUpdateCompanionBuilder,
      (
        KnowledgeEntity,
        BaseReferences<
          _$HelixDatabase,
          $KnowledgeEntitiesTable,
          KnowledgeEntity
        >,
      ),
      KnowledgeEntity,
      PrefetchHooks Function()
    >;
typedef $$KnowledgeRelationshipsTableCreateCompanionBuilder =
    KnowledgeRelationshipsCompanion Function({
      required String id,
      required String entityAId,
      required String entityBId,
      required String relationType,
      Value<String?> description,
      Value<double> confidence,
      required int firstSeen,
      required int lastSeen,
      Value<int> rowid,
    });
typedef $$KnowledgeRelationshipsTableUpdateCompanionBuilder =
    KnowledgeRelationshipsCompanion Function({
      Value<String> id,
      Value<String> entityAId,
      Value<String> entityBId,
      Value<String> relationType,
      Value<String?> description,
      Value<double> confidence,
      Value<int> firstSeen,
      Value<int> lastSeen,
      Value<int> rowid,
    });

class $$KnowledgeRelationshipsTableFilterComposer
    extends Composer<_$HelixDatabase, $KnowledgeRelationshipsTable> {
  $$KnowledgeRelationshipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityAId => $composableBuilder(
    column: $table.entityAId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityBId => $composableBuilder(
    column: $table.entityBId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relationType => $composableBuilder(
    column: $table.relationType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KnowledgeRelationshipsTableOrderingComposer
    extends Composer<_$HelixDatabase, $KnowledgeRelationshipsTable> {
  $$KnowledgeRelationshipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityAId => $composableBuilder(
    column: $table.entityAId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityBId => $composableBuilder(
    column: $table.entityBId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relationType => $composableBuilder(
    column: $table.relationType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstSeen => $composableBuilder(
    column: $table.firstSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KnowledgeRelationshipsTableAnnotationComposer
    extends Composer<_$HelixDatabase, $KnowledgeRelationshipsTable> {
  $$KnowledgeRelationshipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityAId =>
      $composableBuilder(column: $table.entityAId, builder: (column) => column);

  GeneratedColumn<String> get entityBId =>
      $composableBuilder(column: $table.entityBId, builder: (column) => column);

  GeneratedColumn<String> get relationType => $composableBuilder(
    column: $table.relationType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get firstSeen =>
      $composableBuilder(column: $table.firstSeen, builder: (column) => column);

  GeneratedColumn<int> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);
}

class $$KnowledgeRelationshipsTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $KnowledgeRelationshipsTable,
          KnowledgeRelationship,
          $$KnowledgeRelationshipsTableFilterComposer,
          $$KnowledgeRelationshipsTableOrderingComposer,
          $$KnowledgeRelationshipsTableAnnotationComposer,
          $$KnowledgeRelationshipsTableCreateCompanionBuilder,
          $$KnowledgeRelationshipsTableUpdateCompanionBuilder,
          (
            KnowledgeRelationship,
            BaseReferences<
              _$HelixDatabase,
              $KnowledgeRelationshipsTable,
              KnowledgeRelationship
            >,
          ),
          KnowledgeRelationship,
          PrefetchHooks Function()
        > {
  $$KnowledgeRelationshipsTableTableManager(
    _$HelixDatabase db,
    $KnowledgeRelationshipsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KnowledgeRelationshipsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$KnowledgeRelationshipsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$KnowledgeRelationshipsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entityAId = const Value.absent(),
                Value<String> entityBId = const Value.absent(),
                Value<String> relationType = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                Value<int> firstSeen = const Value.absent(),
                Value<int> lastSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KnowledgeRelationshipsCompanion(
                id: id,
                entityAId: entityAId,
                entityBId: entityBId,
                relationType: relationType,
                description: description,
                confidence: confidence,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entityAId,
                required String entityBId,
                required String relationType,
                Value<String?> description = const Value.absent(),
                Value<double> confidence = const Value.absent(),
                required int firstSeen,
                required int lastSeen,
                Value<int> rowid = const Value.absent(),
              }) => KnowledgeRelationshipsCompanion.insert(
                id: id,
                entityAId: entityAId,
                entityBId: entityBId,
                relationType: relationType,
                description: description,
                confidence: confidence,
                firstSeen: firstSeen,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KnowledgeRelationshipsTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $KnowledgeRelationshipsTable,
      KnowledgeRelationship,
      $$KnowledgeRelationshipsTableFilterComposer,
      $$KnowledgeRelationshipsTableOrderingComposer,
      $$KnowledgeRelationshipsTableAnnotationComposer,
      $$KnowledgeRelationshipsTableCreateCompanionBuilder,
      $$KnowledgeRelationshipsTableUpdateCompanionBuilder,
      (
        KnowledgeRelationship,
        BaseReferences<
          _$HelixDatabase,
          $KnowledgeRelationshipsTable,
          KnowledgeRelationship
        >,
      ),
      KnowledgeRelationship,
      PrefetchHooks Function()
    >;
typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      required String profileJson,
      required int lastUpdated,
      Value<int> version,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      Value<String> profileJson,
      Value<int> lastUpdated,
      Value<int> version,
    });

class $$UserProfilesTableFilterComposer
    extends Composer<_$HelixDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get profileJson => $composableBuilder(
    column: $table.profileJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$HelixDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get profileJson => $composableBuilder(
    column: $table.profileJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$HelixDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get profileJson => $composableBuilder(
    column: $table.profileJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastUpdated => $composableBuilder(
    column: $table.lastUpdated,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $UserProfilesTable,
          UserProfile,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfile,
            BaseReferences<_$HelixDatabase, $UserProfilesTable, UserProfile>,
          ),
          UserProfile,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$HelixDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> profileJson = const Value.absent(),
                Value<int> lastUpdated = const Value.absent(),
                Value<int> version = const Value.absent(),
              }) => UserProfilesCompanion(
                id: id,
                profileJson: profileJson,
                lastUpdated: lastUpdated,
                version: version,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String profileJson,
                required int lastUpdated,
                Value<int> version = const Value.absent(),
              }) => UserProfilesCompanion.insert(
                id: id,
                profileJson: profileJson,
                lastUpdated: lastUpdated,
                version: version,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $UserProfilesTable,
      UserProfile,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfile,
        BaseReferences<_$HelixDatabase, $UserProfilesTable, UserProfile>,
      ),
      UserProfile,
      PrefetchHooks Function()
    >;
typedef $$ProjectsTableCreateCompanionBuilder =
    ProjectsCompanion Function({
      required String id,
      required String name,
      Value<String?> description,
      required int createdAt,
      required int updatedAt,
      Value<int?> deletedAt,
      Value<int> chunkSizeTokens,
      Value<int> chunkOverlapTokens,
      Value<int> retrievalTopK,
      Value<double> retrievalMinSimilarity,
      Value<int> rowid,
    });
typedef $$ProjectsTableUpdateCompanionBuilder =
    ProjectsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> description,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> deletedAt,
      Value<int> chunkSizeTokens,
      Value<int> chunkOverlapTokens,
      Value<int> retrievalTopK,
      Value<double> retrievalMinSimilarity,
      Value<int> rowid,
    });

final class $$ProjectsTableReferences
    extends BaseReferences<_$HelixDatabase, $ProjectsTable, Project> {
  $$ProjectsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ProjectDocumentsTable, List<ProjectDocument>>
  _projectDocumentsRefsTable(_$HelixDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.projectDocuments,
        aliasName: $_aliasNameGenerator(
          db.projects.id,
          db.projectDocuments.projectId,
        ),
      );

  $$ProjectDocumentsTableProcessedTableManager get projectDocumentsRefs {
    final manager = $$ProjectDocumentsTableTableManager(
      $_db,
      $_db.projectDocuments,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _projectDocumentsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ProjectDocumentChunksTable,
    List<ProjectDocumentChunk>
  >
  _projectDocumentChunksRefsTable(_$HelixDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.projectDocumentChunks,
        aliasName: $_aliasNameGenerator(
          db.projects.id,
          db.projectDocumentChunks.projectId,
        ),
      );

  $$ProjectDocumentChunksTableProcessedTableManager
  get projectDocumentChunksRefs {
    final manager = $$ProjectDocumentChunksTableTableManager(
      $_db,
      $_db.projectDocumentChunks,
    ).filter((f) => f.projectId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _projectDocumentChunksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectsTableFilterComposer
    extends Composer<_$HelixDatabase, $ProjectsTable> {
  $$ProjectsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkSizeTokens => $composableBuilder(
    column: $table.chunkSizeTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkOverlapTokens => $composableBuilder(
    column: $table.chunkOverlapTokens,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retrievalTopK => $composableBuilder(
    column: $table.retrievalTopK,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get retrievalMinSimilarity => $composableBuilder(
    column: $table.retrievalMinSimilarity,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> projectDocumentsRefs(
    Expression<bool> Function($$ProjectDocumentsTableFilterComposer f) f,
  ) {
    final $$ProjectDocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectDocuments,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectDocumentsTableFilterComposer(
            $db: $db,
            $table: $db.projectDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> projectDocumentChunksRefs(
    Expression<bool> Function($$ProjectDocumentChunksTableFilterComposer f) f,
  ) {
    final $$ProjectDocumentChunksTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.projectDocumentChunks,
          getReferencedColumn: (t) => t.projectId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ProjectDocumentChunksTableFilterComposer(
                $db: $db,
                $table: $db.projectDocumentChunks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ProjectsTableOrderingComposer
    extends Composer<_$HelixDatabase, $ProjectsTable> {
  $$ProjectsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkSizeTokens => $composableBuilder(
    column: $table.chunkSizeTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkOverlapTokens => $composableBuilder(
    column: $table.chunkOverlapTokens,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retrievalTopK => $composableBuilder(
    column: $table.retrievalTopK,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get retrievalMinSimilarity => $composableBuilder(
    column: $table.retrievalMinSimilarity,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectsTableAnnotationComposer
    extends Composer<_$HelixDatabase, $ProjectsTable> {
  $$ProjectsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get chunkSizeTokens => $composableBuilder(
    column: $table.chunkSizeTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chunkOverlapTokens => $composableBuilder(
    column: $table.chunkOverlapTokens,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retrievalTopK => $composableBuilder(
    column: $table.retrievalTopK,
    builder: (column) => column,
  );

  GeneratedColumn<double> get retrievalMinSimilarity => $composableBuilder(
    column: $table.retrievalMinSimilarity,
    builder: (column) => column,
  );

  Expression<T> projectDocumentsRefs<T extends Object>(
    Expression<T> Function($$ProjectDocumentsTableAnnotationComposer a) f,
  ) {
    final $$ProjectDocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.projectDocuments,
      getReferencedColumn: (t) => t.projectId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectDocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> projectDocumentChunksRefs<T extends Object>(
    Expression<T> Function($$ProjectDocumentChunksTableAnnotationComposer a) f,
  ) {
    final $$ProjectDocumentChunksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.projectDocumentChunks,
          getReferencedColumn: (t) => t.projectId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ProjectDocumentChunksTableAnnotationComposer(
                $db: $db,
                $table: $db.projectDocumentChunks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ProjectsTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $ProjectsTable,
          Project,
          $$ProjectsTableFilterComposer,
          $$ProjectsTableOrderingComposer,
          $$ProjectsTableAnnotationComposer,
          $$ProjectsTableCreateCompanionBuilder,
          $$ProjectsTableUpdateCompanionBuilder,
          (Project, $$ProjectsTableReferences),
          Project,
          PrefetchHooks Function({
            bool projectDocumentsRefs,
            bool projectDocumentChunksRefs,
          })
        > {
  $$ProjectsTableTableManager(_$HelixDatabase db, $ProjectsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> chunkSizeTokens = const Value.absent(),
                Value<int> chunkOverlapTokens = const Value.absent(),
                Value<int> retrievalTopK = const Value.absent(),
                Value<double> retrievalMinSimilarity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                chunkSizeTokens: chunkSizeTokens,
                chunkOverlapTokens: chunkOverlapTokens,
                retrievalTopK: retrievalTopK,
                retrievalMinSimilarity: retrievalMinSimilarity,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> description = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> deletedAt = const Value.absent(),
                Value<int> chunkSizeTokens = const Value.absent(),
                Value<int> chunkOverlapTokens = const Value.absent(),
                Value<int> retrievalTopK = const Value.absent(),
                Value<double> retrievalMinSimilarity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectsCompanion.insert(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                chunkSizeTokens: chunkSizeTokens,
                chunkOverlapTokens: chunkOverlapTokens,
                retrievalTopK: retrievalTopK,
                retrievalMinSimilarity: retrievalMinSimilarity,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                projectDocumentsRefs = false,
                projectDocumentChunksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (projectDocumentsRefs) db.projectDocuments,
                    if (projectDocumentChunksRefs) db.projectDocumentChunks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (projectDocumentsRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          ProjectDocument
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._projectDocumentsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).projectDocumentsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (projectDocumentChunksRefs)
                        await $_getPrefetchedData<
                          Project,
                          $ProjectsTable,
                          ProjectDocumentChunk
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectsTableReferences
                              ._projectDocumentChunksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectsTableReferences(
                                db,
                                table,
                                p0,
                              ).projectDocumentChunksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.projectId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $ProjectsTable,
      Project,
      $$ProjectsTableFilterComposer,
      $$ProjectsTableOrderingComposer,
      $$ProjectsTableAnnotationComposer,
      $$ProjectsTableCreateCompanionBuilder,
      $$ProjectsTableUpdateCompanionBuilder,
      (Project, $$ProjectsTableReferences),
      Project,
      PrefetchHooks Function({
        bool projectDocumentsRefs,
        bool projectDocumentChunksRefs,
      })
    >;
typedef $$ProjectDocumentsTableCreateCompanionBuilder =
    ProjectDocumentsCompanion Function({
      required String id,
      required String projectId,
      required String filename,
      required String contentType,
      required int byteSize,
      Value<int?> pageCount,
      required int ingestedAt,
      Value<int?> deletedAt,
      required String ingestStatus,
      Value<String?> ingestError,
      Value<int> rowid,
    });
typedef $$ProjectDocumentsTableUpdateCompanionBuilder =
    ProjectDocumentsCompanion Function({
      Value<String> id,
      Value<String> projectId,
      Value<String> filename,
      Value<String> contentType,
      Value<int> byteSize,
      Value<int?> pageCount,
      Value<int> ingestedAt,
      Value<int?> deletedAt,
      Value<String> ingestStatus,
      Value<String?> ingestError,
      Value<int> rowid,
    });

final class $$ProjectDocumentsTableReferences
    extends
        BaseReferences<
          _$HelixDatabase,
          $ProjectDocumentsTable,
          ProjectDocument
        > {
  $$ProjectDocumentsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectsTable _projectIdTable(_$HelixDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(db.projectDocuments.projectId, db.projects.id),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $ProjectDocumentChunksTable,
    List<ProjectDocumentChunk>
  >
  _projectDocumentChunksRefsTable(_$HelixDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.projectDocumentChunks,
        aliasName: $_aliasNameGenerator(
          db.projectDocuments.id,
          db.projectDocumentChunks.documentId,
        ),
      );

  $$ProjectDocumentChunksTableProcessedTableManager
  get projectDocumentChunksRefs {
    final manager = $$ProjectDocumentChunksTableTableManager(
      $_db,
      $_db.projectDocumentChunks,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _projectDocumentChunksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectDocumentsTableFilterComposer
    extends Composer<_$HelixDatabase, $ProjectDocumentsTable> {
  $$ProjectDocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ingestStatus => $composableBuilder(
    column: $table.ingestStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ingestError => $composableBuilder(
    column: $table.ingestError,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> projectDocumentChunksRefs(
    Expression<bool> Function($$ProjectDocumentChunksTableFilterComposer f) f,
  ) {
    final $$ProjectDocumentChunksTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.projectDocumentChunks,
          getReferencedColumn: (t) => t.documentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ProjectDocumentChunksTableFilterComposer(
                $db: $db,
                $table: $db.projectDocumentChunks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ProjectDocumentsTableOrderingComposer
    extends Composer<_$HelixDatabase, $ProjectDocumentsTable> {
  $$ProjectDocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ingestStatus => $composableBuilder(
    column: $table.ingestStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ingestError => $composableBuilder(
    column: $table.ingestError,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectDocumentsTableAnnotationComposer
    extends Composer<_$HelixDatabase, $ProjectDocumentsTable> {
  $$ProjectDocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<int> get ingestedAt => $composableBuilder(
    column: $table.ingestedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get ingestStatus => $composableBuilder(
    column: $table.ingestStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ingestError => $composableBuilder(
    column: $table.ingestError,
    builder: (column) => column,
  );

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> projectDocumentChunksRefs<T extends Object>(
    Expression<T> Function($$ProjectDocumentChunksTableAnnotationComposer a) f,
  ) {
    final $$ProjectDocumentChunksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.projectDocumentChunks,
          getReferencedColumn: (t) => t.documentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ProjectDocumentChunksTableAnnotationComposer(
                $db: $db,
                $table: $db.projectDocumentChunks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ProjectDocumentsTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $ProjectDocumentsTable,
          ProjectDocument,
          $$ProjectDocumentsTableFilterComposer,
          $$ProjectDocumentsTableOrderingComposer,
          $$ProjectDocumentsTableAnnotationComposer,
          $$ProjectDocumentsTableCreateCompanionBuilder,
          $$ProjectDocumentsTableUpdateCompanionBuilder,
          (ProjectDocument, $$ProjectDocumentsTableReferences),
          ProjectDocument,
          PrefetchHooks Function({
            bool projectId,
            bool projectDocumentChunksRefs,
          })
        > {
  $$ProjectDocumentsTableTableManager(
    _$HelixDatabase db,
    $ProjectDocumentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectDocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectDocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectDocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> filename = const Value.absent(),
                Value<String> contentType = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<int?> pageCount = const Value.absent(),
                Value<int> ingestedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<String> ingestStatus = const Value.absent(),
                Value<String?> ingestError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectDocumentsCompanion(
                id: id,
                projectId: projectId,
                filename: filename,
                contentType: contentType,
                byteSize: byteSize,
                pageCount: pageCount,
                ingestedAt: ingestedAt,
                deletedAt: deletedAt,
                ingestStatus: ingestStatus,
                ingestError: ingestError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String projectId,
                required String filename,
                required String contentType,
                required int byteSize,
                Value<int?> pageCount = const Value.absent(),
                required int ingestedAt,
                Value<int?> deletedAt = const Value.absent(),
                required String ingestStatus,
                Value<String?> ingestError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectDocumentsCompanion.insert(
                id: id,
                projectId: projectId,
                filename: filename,
                contentType: contentType,
                byteSize: byteSize,
                pageCount: pageCount,
                ingestedAt: ingestedAt,
                deletedAt: deletedAt,
                ingestStatus: ingestStatus,
                ingestError: ingestError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectDocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({projectId = false, projectDocumentChunksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (projectDocumentChunksRefs) db.projectDocumentChunks,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable:
                                        $$ProjectDocumentsTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$ProjectDocumentsTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (projectDocumentChunksRefs)
                        await $_getPrefetchedData<
                          ProjectDocument,
                          $ProjectDocumentsTable,
                          ProjectDocumentChunk
                        >(
                          currentTable: table,
                          referencedTable: $$ProjectDocumentsTableReferences
                              ._projectDocumentChunksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectDocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).projectDocumentChunksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectDocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $ProjectDocumentsTable,
      ProjectDocument,
      $$ProjectDocumentsTableFilterComposer,
      $$ProjectDocumentsTableOrderingComposer,
      $$ProjectDocumentsTableAnnotationComposer,
      $$ProjectDocumentsTableCreateCompanionBuilder,
      $$ProjectDocumentsTableUpdateCompanionBuilder,
      (ProjectDocument, $$ProjectDocumentsTableReferences),
      ProjectDocument,
      PrefetchHooks Function({bool projectId, bool projectDocumentChunksRefs})
    >;
typedef $$ProjectDocumentChunksTableCreateCompanionBuilder =
    ProjectDocumentChunksCompanion Function({
      required String id,
      required String documentId,
      required String projectId,
      required int chunkIndex,
      required String text_,
      required int tokenCount,
      Value<int?> pageStart,
      Value<int?> pageEnd,
      Value<int> rowid,
    });
typedef $$ProjectDocumentChunksTableUpdateCompanionBuilder =
    ProjectDocumentChunksCompanion Function({
      Value<String> id,
      Value<String> documentId,
      Value<String> projectId,
      Value<int> chunkIndex,
      Value<String> text_,
      Value<int> tokenCount,
      Value<int?> pageStart,
      Value<int?> pageEnd,
      Value<int> rowid,
    });

final class $$ProjectDocumentChunksTableReferences
    extends
        BaseReferences<
          _$HelixDatabase,
          $ProjectDocumentChunksTable,
          ProjectDocumentChunk
        > {
  $$ProjectDocumentChunksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectDocumentsTable _documentIdTable(_$HelixDatabase db) =>
      db.projectDocuments.createAlias(
        $_aliasNameGenerator(
          db.projectDocumentChunks.documentId,
          db.projectDocuments.id,
        ),
      );

  $$ProjectDocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$ProjectDocumentsTableTableManager(
      $_db,
      $_db.projectDocuments,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ProjectsTable _projectIdTable(_$HelixDatabase db) =>
      db.projects.createAlias(
        $_aliasNameGenerator(
          db.projectDocumentChunks.projectId,
          db.projects.id,
        ),
      );

  $$ProjectsTableProcessedTableManager get projectId {
    final $_column = $_itemColumn<String>('project_id')!;

    final manager = $$ProjectsTableTableManager(
      $_db,
      $_db.projects,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_projectIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $ProjectDocumentChunkVectorsTable,
    List<ProjectDocumentChunkVector>
  >
  _projectDocumentChunkVectorsRefsTable(_$HelixDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.projectDocumentChunkVectors,
        aliasName: $_aliasNameGenerator(
          db.projectDocumentChunks.id,
          db.projectDocumentChunkVectors.chunkId,
        ),
      );

  $$ProjectDocumentChunkVectorsTableProcessedTableManager
  get projectDocumentChunkVectorsRefs {
    final manager = $$ProjectDocumentChunkVectorsTableTableManager(
      $_db,
      $_db.projectDocumentChunkVectors,
    ).filter((f) => f.chunkId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _projectDocumentChunkVectorsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ProjectDocumentChunksTableFilterComposer
    extends Composer<_$HelixDatabase, $ProjectDocumentChunksTable> {
  $$ProjectDocumentChunksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get text_ => $composableBuilder(
    column: $table.text_,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tokenCount => $composableBuilder(
    column: $table.tokenCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageStart => $composableBuilder(
    column: $table.pageStart,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageEnd => $composableBuilder(
    column: $table.pageEnd,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectDocumentsTableFilterComposer get documentId {
    final $$ProjectDocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.projectDocuments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectDocumentsTableFilterComposer(
            $db: $db,
            $table: $db.projectDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableFilterComposer get projectId {
    final $$ProjectsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableFilterComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> projectDocumentChunkVectorsRefs(
    Expression<bool> Function(
      $$ProjectDocumentChunkVectorsTableFilterComposer f,
    )
    f,
  ) {
    final $$ProjectDocumentChunkVectorsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.projectDocumentChunkVectors,
          getReferencedColumn: (t) => t.chunkId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ProjectDocumentChunkVectorsTableFilterComposer(
                $db: $db,
                $table: $db.projectDocumentChunkVectors,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ProjectDocumentChunksTableOrderingComposer
    extends Composer<_$HelixDatabase, $ProjectDocumentChunksTable> {
  $$ProjectDocumentChunksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get text_ => $composableBuilder(
    column: $table.text_,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tokenCount => $composableBuilder(
    column: $table.tokenCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageStart => $composableBuilder(
    column: $table.pageStart,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageEnd => $composableBuilder(
    column: $table.pageEnd,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectDocumentsTableOrderingComposer get documentId {
    final $$ProjectDocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.projectDocuments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectDocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.projectDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableOrderingComposer get projectId {
    final $$ProjectsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableOrderingComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProjectDocumentChunksTableAnnotationComposer
    extends Composer<_$HelixDatabase, $ProjectDocumentChunksTable> {
  $$ProjectDocumentChunksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get text_ =>
      $composableBuilder(column: $table.text_, builder: (column) => column);

  GeneratedColumn<int> get tokenCount => $composableBuilder(
    column: $table.tokenCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageStart =>
      $composableBuilder(column: $table.pageStart, builder: (column) => column);

  GeneratedColumn<int> get pageEnd =>
      $composableBuilder(column: $table.pageEnd, builder: (column) => column);

  $$ProjectDocumentsTableAnnotationComposer get documentId {
    final $$ProjectDocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.projectDocuments,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectDocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.projectDocuments,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ProjectsTableAnnotationComposer get projectId {
    final $$ProjectsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.projectId,
      referencedTable: $db.projects,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProjectsTableAnnotationComposer(
            $db: $db,
            $table: $db.projects,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> projectDocumentChunkVectorsRefs<T extends Object>(
    Expression<T> Function(
      $$ProjectDocumentChunkVectorsTableAnnotationComposer a,
    )
    f,
  ) {
    final $$ProjectDocumentChunkVectorsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.projectDocumentChunkVectors,
          getReferencedColumn: (t) => t.chunkId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ProjectDocumentChunkVectorsTableAnnotationComposer(
                $db: $db,
                $table: $db.projectDocumentChunkVectors,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ProjectDocumentChunksTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $ProjectDocumentChunksTable,
          ProjectDocumentChunk,
          $$ProjectDocumentChunksTableFilterComposer,
          $$ProjectDocumentChunksTableOrderingComposer,
          $$ProjectDocumentChunksTableAnnotationComposer,
          $$ProjectDocumentChunksTableCreateCompanionBuilder,
          $$ProjectDocumentChunksTableUpdateCompanionBuilder,
          (ProjectDocumentChunk, $$ProjectDocumentChunksTableReferences),
          ProjectDocumentChunk,
          PrefetchHooks Function({
            bool documentId,
            bool projectId,
            bool projectDocumentChunkVectorsRefs,
          })
        > {
  $$ProjectDocumentChunksTableTableManager(
    _$HelixDatabase db,
    $ProjectDocumentChunksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectDocumentChunksTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ProjectDocumentChunksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ProjectDocumentChunksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<int> chunkIndex = const Value.absent(),
                Value<String> text_ = const Value.absent(),
                Value<int> tokenCount = const Value.absent(),
                Value<int?> pageStart = const Value.absent(),
                Value<int?> pageEnd = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectDocumentChunksCompanion(
                id: id,
                documentId: documentId,
                projectId: projectId,
                chunkIndex: chunkIndex,
                text_: text_,
                tokenCount: tokenCount,
                pageStart: pageStart,
                pageEnd: pageEnd,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String documentId,
                required String projectId,
                required int chunkIndex,
                required String text_,
                required int tokenCount,
                Value<int?> pageStart = const Value.absent(),
                Value<int?> pageEnd = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectDocumentChunksCompanion.insert(
                id: id,
                documentId: documentId,
                projectId: projectId,
                chunkIndex: chunkIndex,
                text_: text_,
                tokenCount: tokenCount,
                pageStart: pageStart,
                pageEnd: pageEnd,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectDocumentChunksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                documentId = false,
                projectId = false,
                projectDocumentChunkVectorsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (projectDocumentChunkVectorsRefs)
                      db.projectDocumentChunkVectors,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (documentId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.documentId,
                                    referencedTable:
                                        $$ProjectDocumentChunksTableReferences
                                            ._documentIdTable(db),
                                    referencedColumn:
                                        $$ProjectDocumentChunksTableReferences
                                            ._documentIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (projectId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.projectId,
                                    referencedTable:
                                        $$ProjectDocumentChunksTableReferences
                                            ._projectIdTable(db),
                                    referencedColumn:
                                        $$ProjectDocumentChunksTableReferences
                                            ._projectIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (projectDocumentChunkVectorsRefs)
                        await $_getPrefetchedData<
                          ProjectDocumentChunk,
                          $ProjectDocumentChunksTable,
                          ProjectDocumentChunkVector
                        >(
                          currentTable: table,
                          referencedTable:
                              $$ProjectDocumentChunksTableReferences
                                  ._projectDocumentChunkVectorsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ProjectDocumentChunksTableReferences(
                                db,
                                table,
                                p0,
                              ).projectDocumentChunkVectorsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.chunkId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ProjectDocumentChunksTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $ProjectDocumentChunksTable,
      ProjectDocumentChunk,
      $$ProjectDocumentChunksTableFilterComposer,
      $$ProjectDocumentChunksTableOrderingComposer,
      $$ProjectDocumentChunksTableAnnotationComposer,
      $$ProjectDocumentChunksTableCreateCompanionBuilder,
      $$ProjectDocumentChunksTableUpdateCompanionBuilder,
      (ProjectDocumentChunk, $$ProjectDocumentChunksTableReferences),
      ProjectDocumentChunk,
      PrefetchHooks Function({
        bool documentId,
        bool projectId,
        bool projectDocumentChunkVectorsRefs,
      })
    >;
typedef $$ProjectDocumentChunkVectorsTableCreateCompanionBuilder =
    ProjectDocumentChunkVectorsCompanion Function({
      required String chunkId,
      required Uint8List embedding,
      required String embeddingModel,
      Value<int> rowid,
    });
typedef $$ProjectDocumentChunkVectorsTableUpdateCompanionBuilder =
    ProjectDocumentChunkVectorsCompanion Function({
      Value<String> chunkId,
      Value<Uint8List> embedding,
      Value<String> embeddingModel,
      Value<int> rowid,
    });

final class $$ProjectDocumentChunkVectorsTableReferences
    extends
        BaseReferences<
          _$HelixDatabase,
          $ProjectDocumentChunkVectorsTable,
          ProjectDocumentChunkVector
        > {
  $$ProjectDocumentChunkVectorsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ProjectDocumentChunksTable _chunkIdTable(_$HelixDatabase db) =>
      db.projectDocumentChunks.createAlias(
        $_aliasNameGenerator(
          db.projectDocumentChunkVectors.chunkId,
          db.projectDocumentChunks.id,
        ),
      );

  $$ProjectDocumentChunksTableProcessedTableManager get chunkId {
    final $_column = $_itemColumn<String>('chunk_id')!;

    final manager = $$ProjectDocumentChunksTableTableManager(
      $_db,
      $_db.projectDocumentChunks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chunkIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProjectDocumentChunkVectorsTableFilterComposer
    extends Composer<_$HelixDatabase, $ProjectDocumentChunkVectorsTable> {
  $$ProjectDocumentChunkVectorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get embeddingModel => $composableBuilder(
    column: $table.embeddingModel,
    builder: (column) => ColumnFilters(column),
  );

  $$ProjectDocumentChunksTableFilterComposer get chunkId {
    final $$ProjectDocumentChunksTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.chunkId,
          referencedTable: $db.projectDocumentChunks,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ProjectDocumentChunksTableFilterComposer(
                $db: $db,
                $table: $db.projectDocumentChunks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ProjectDocumentChunkVectorsTableOrderingComposer
    extends Composer<_$HelixDatabase, $ProjectDocumentChunkVectorsTable> {
  $$ProjectDocumentChunkVectorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<Uint8List> get embedding => $composableBuilder(
    column: $table.embedding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get embeddingModel => $composableBuilder(
    column: $table.embeddingModel,
    builder: (column) => ColumnOrderings(column),
  );

  $$ProjectDocumentChunksTableOrderingComposer get chunkId {
    final $$ProjectDocumentChunksTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.chunkId,
          referencedTable: $db.projectDocumentChunks,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ProjectDocumentChunksTableOrderingComposer(
                $db: $db,
                $table: $db.projectDocumentChunks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ProjectDocumentChunkVectorsTableAnnotationComposer
    extends Composer<_$HelixDatabase, $ProjectDocumentChunkVectorsTable> {
  $$ProjectDocumentChunkVectorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<Uint8List> get embedding =>
      $composableBuilder(column: $table.embedding, builder: (column) => column);

  GeneratedColumn<String> get embeddingModel => $composableBuilder(
    column: $table.embeddingModel,
    builder: (column) => column,
  );

  $$ProjectDocumentChunksTableAnnotationComposer get chunkId {
    final $$ProjectDocumentChunksTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.chunkId,
          referencedTable: $db.projectDocumentChunks,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ProjectDocumentChunksTableAnnotationComposer(
                $db: $db,
                $table: $db.projectDocumentChunks,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$ProjectDocumentChunkVectorsTableTableManager
    extends
        RootTableManager<
          _$HelixDatabase,
          $ProjectDocumentChunkVectorsTable,
          ProjectDocumentChunkVector,
          $$ProjectDocumentChunkVectorsTableFilterComposer,
          $$ProjectDocumentChunkVectorsTableOrderingComposer,
          $$ProjectDocumentChunkVectorsTableAnnotationComposer,
          $$ProjectDocumentChunkVectorsTableCreateCompanionBuilder,
          $$ProjectDocumentChunkVectorsTableUpdateCompanionBuilder,
          (
            ProjectDocumentChunkVector,
            $$ProjectDocumentChunkVectorsTableReferences,
          ),
          ProjectDocumentChunkVector,
          PrefetchHooks Function({bool chunkId})
        > {
  $$ProjectDocumentChunkVectorsTableTableManager(
    _$HelixDatabase db,
    $ProjectDocumentChunkVectorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectDocumentChunkVectorsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ProjectDocumentChunkVectorsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ProjectDocumentChunkVectorsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> chunkId = const Value.absent(),
                Value<Uint8List> embedding = const Value.absent(),
                Value<String> embeddingModel = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectDocumentChunkVectorsCompanion(
                chunkId: chunkId,
                embedding: embedding,
                embeddingModel: embeddingModel,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String chunkId,
                required Uint8List embedding,
                required String embeddingModel,
                Value<int> rowid = const Value.absent(),
              }) => ProjectDocumentChunkVectorsCompanion.insert(
                chunkId: chunkId,
                embedding: embedding,
                embeddingModel: embeddingModel,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProjectDocumentChunkVectorsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({chunkId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (chunkId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.chunkId,
                                referencedTable:
                                    $$ProjectDocumentChunkVectorsTableReferences
                                        ._chunkIdTable(db),
                                referencedColumn:
                                    $$ProjectDocumentChunkVectorsTableReferences
                                        ._chunkIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProjectDocumentChunkVectorsTableProcessedTableManager =
    ProcessedTableManager<
      _$HelixDatabase,
      $ProjectDocumentChunkVectorsTable,
      ProjectDocumentChunkVector,
      $$ProjectDocumentChunkVectorsTableFilterComposer,
      $$ProjectDocumentChunkVectorsTableOrderingComposer,
      $$ProjectDocumentChunkVectorsTableAnnotationComposer,
      $$ProjectDocumentChunkVectorsTableCreateCompanionBuilder,
      $$ProjectDocumentChunkVectorsTableUpdateCompanionBuilder,
      (
        ProjectDocumentChunkVector,
        $$ProjectDocumentChunkVectorsTableReferences,
      ),
      ProjectDocumentChunkVector,
      PrefetchHooks Function({bool chunkId})
    >;

class $HelixDatabaseManager {
  final _$HelixDatabase _db;
  $HelixDatabaseManager(this._db);
  $$ConversationsTableTableManager get conversations =>
      $$ConversationsTableTableManager(_db, _db.conversations);
  $$ConversationSegmentsTableTableManager get conversationSegments =>
      $$ConversationSegmentsTableTableManager(_db, _db.conversationSegments);
  $$ConversationAiCostEntriesTableTableManager get conversationAiCostEntries =>
      $$ConversationAiCostEntriesTableTableManager(
        _db,
        _db.conversationAiCostEntries,
      );
  $$TopicsTableTableManager get topics =>
      $$TopicsTableTableManager(_db, _db.topics);
  $$FactsTableTableManager get facts =>
      $$FactsTableTableManager(_db, _db.facts);
  $$DailyMemoriesTableTableManager get dailyMemories =>
      $$DailyMemoriesTableTableManager(_db, _db.dailyMemories);
  $$VoiceNotesTableTableManager get voiceNotes =>
      $$VoiceNotesTableTableManager(_db, _db.voiceNotes);
  $$TodosTableTableManager get todos =>
      $$TodosTableTableManager(_db, _db.todos);
  $$BuzzHistoryEntriesTableTableManager get buzzHistoryEntries =>
      $$BuzzHistoryEntriesTableTableManager(_db, _db.buzzHistoryEntries);
  $$KnowledgeEntitiesTableTableManager get knowledgeEntities =>
      $$KnowledgeEntitiesTableTableManager(_db, _db.knowledgeEntities);
  $$KnowledgeRelationshipsTableTableManager get knowledgeRelationships =>
      $$KnowledgeRelationshipsTableTableManager(
        _db,
        _db.knowledgeRelationships,
      );
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$ProjectsTableTableManager get projects =>
      $$ProjectsTableTableManager(_db, _db.projects);
  $$ProjectDocumentsTableTableManager get projectDocuments =>
      $$ProjectDocumentsTableTableManager(_db, _db.projectDocuments);
  $$ProjectDocumentChunksTableTableManager get projectDocumentChunks =>
      $$ProjectDocumentChunksTableTableManager(_db, _db.projectDocumentChunks);
  $$ProjectDocumentChunkVectorsTableTableManager
  get projectDocumentChunkVectors =>
      $$ProjectDocumentChunkVectorsTableTableManager(
        _db,
        _db.projectDocumentChunkVectors,
      );
}
