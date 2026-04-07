import 'dart:async';

import 'package:flutter_helix/services/proto.dart';
import 'package:flutter_helix/services/text_paginator.dart';

abstract class HudPacketSink {
  Future<void> send({
    required int screenStatus,
    required int pageIndex,
    required int totalPages,
    required String pageText,
  });
}

class HudStreamSession {
  HudStreamSession({required this.sink});
  final HudPacketSink sink;
}
