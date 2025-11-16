/// Coverage Helper Test
///
/// This file imports all source files to ensure complete coverage tracking.
/// It helps the coverage tool discover all files in the project.

// Models
import 'package:flutter_helix/models/audio_chunk.dart';
import 'package:flutter_helix/models/ble_transaction.dart';

// Services - AI
import 'package:flutter_helix/services/ai/ai_coordinator.dart';
import 'package:flutter_helix/services/ai/base_ai_provider.dart';
import 'package:flutter_helix/services/ai/openai_provider.dart';

// Services - Transcription
import 'package:flutter_helix/services/transcription/native_transcription_service.dart';
import 'package:flutter_helix/services/transcription/transcription_coordinator.dart';
import 'package:flutter_helix/services/transcription/transcription_models.dart';
import 'package:flutter_helix/services/transcription/transcription_service.dart';
import 'package:flutter_helix/services/transcription/whisper_transcription_service.dart';

// Services - Core
import 'package:flutter_helix/services/audio_buffer_manager.dart';
import 'package:flutter_helix/services/conversation_insights.dart';

void main() {
  // This test file is intentionally empty.
  // It exists to help the coverage tool discover all source files.
  //
  // The imports above ensure that all files are included in coverage reports,
  // even if they don't have direct test coverage yet.
}
