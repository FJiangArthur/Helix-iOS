// ABOUTME: Holds the currently-active-for-live project id. Persisted in prefs.

import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'activeProjectId';

class ActiveProjectController {
  ActiveProjectController._(this._prefs, this._activeProjectId);

  static ActiveProjectController? _instance;
  static ActiveProjectController get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('ActiveProjectController.load() must be awaited first');
    }
    return i;
  }

  static Future<ActiveProjectController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    final c = ActiveProjectController._(prefs, raw);
    _instance = c;
    return c;
  }

  static void resetForTesting() {
    _instance = null;
  }

  final SharedPreferences _prefs;
  String? _activeProjectId;
  final _controller = StreamController<String?>.broadcast();

  String? get activeProjectId => _activeProjectId;
  Stream<String?> get activeProjectStream => _controller.stream;

  Future<void> setActive(String? projectId) async {
    _activeProjectId = projectId;
    if (projectId == null) {
      await _prefs.remove(_prefsKey);
    } else {
      await _prefs.setString(_prefsKey, projectId);
    }
    _controller.add(projectId);
  }
}
