import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hud_widget.dart';

/// Displays a simple todo list on the HUD, persisted via SharedPreferences.
class TodosWidget extends HudWidget {
  static const _prefsKey = 'hud_todos';

  List<Map<String, dynamic>> _items = [];

  /// Expose cached items for the settings UI to display.
  static List<Map<String, dynamic>> get cachedTodos => _cachedItems;
  static List<Map<String, dynamic>> _cachedItems = [];

  /// Serializes mutations so concurrent add/toggle/remove calls don't race.
  static Future<void> _pending = Future.value();

  @override
  String get id => 'todos';
  @override
  String get displayName => 'Todos';
  @override
  IconData get icon => Icons.check_box;
  @override
  Duration get refreshInterval => const Duration(days: 365);
  @override
  int get maxLines => 3;

  @override
  Future<void> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        _items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        _items = [];
      }
    } catch (_) {
      // Keep cached data on failure.
    }
    _cachedItems = List.from(_items);
    lastRefreshed = DateTime.now();
  }

  @override
  List<String> renderLines() {
    try {
      if (_items.isEmpty) {
        return [HudWidget.truncate('No todos')];
      }
      return _items.take(maxLines).map((item) {
        final done = item['done'] as bool? ?? false;
        final text = item['text'] as String? ?? '';
        final prefix = done ? '[x]' : '[ ]';
        return HudWidget.truncate('$prefix $text');
      }).toList();
    } catch (_) {
      return [HudWidget.truncate('No todos')];
    }
  }

  // ---- Static mutation helpers (serialized via _pending) ----

  static Future<void> addTodo(String text) {
    return _pending = _pending.then((_) async {
      final items = await _loadItems();
      items.add({'text': text, 'done': false});
      await _saveItems(items);
      _cachedItems = List.from(items);
    });
  }

  static Future<void> toggleTodo(int index) {
    return _pending = _pending.then((_) async {
      final items = await _loadItems();
      if (index >= 0 && index < items.length) {
        items[index]['done'] = !(items[index]['done'] as bool? ?? false);
        await _saveItems(items);
        _cachedItems = List.from(items);
      }
    });
  }

  static Future<void> removeTodo(int index) {
    return _pending = _pending.then((_) async {
      final items = await _loadItems();
      if (index >= 0 && index < items.length) {
        items.removeAt(index);
        await _saveItems(items);
        _cachedItems = List.from(items);
      }
    });
  }

  static Future<List<Map<String, dynamic>>> _loadItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List;
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> _saveItems(List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(items));
    } catch (_) {}
  }
}
