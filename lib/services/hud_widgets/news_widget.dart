import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'hud_widget.dart';

/// Displays a top news headline on the HUD from an RSS feed.
class NewsWidget extends HudWidget {
  String feedUrl;
  String? _headline;

  NewsWidget({this.feedUrl = 'https://feeds.bbci.co.uk/news/world/rss.xml'});

  @override
  String get id => 'news';
  @override
  String get displayName => 'News';
  @override
  IconData get icon => Icons.article;
  @override
  Duration get refreshInterval => const Duration(minutes: 15);
  @override
  int get maxLines => 2;

  @override
  Future<void> refresh() async {
    try {
      final uri = Uri.parse(feedUrl);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10)
        ..idleTimeout = const Duration(seconds: 10);
      try {
        final request = await client.getUrl(uri);
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        _headline = _parseFirstHeadline(body);
      } finally {
        client.close();
      }
    } catch (_) {
      // Keep cached headline on failure.
    }
    lastRefreshed = DateTime.now();
  }

  @override
  List<String> renderLines() {
    try {
      if (_headline == null || _headline!.isEmpty) {
        return [HudWidget.truncate('NEWS:'), HudWidget.truncate('No headlines')];
      }
      return [
        HudWidget.truncate('NEWS:'),
        HudWidget.truncate(_headline!),
      ];
    } catch (_) {
      return [HudWidget.truncate('NEWS:'), HudWidget.truncate('Unavailable')];
    }
  }

  /// Extracts the first <title> inside an <item> from RSS XML using regex.
  String? _parseFirstHeadline(String xml) {
    // Match <item>...<title>...</title>...</item> — grab first item's title.
    final itemPattern = RegExp(r'<item[^>]*>([\s\S]*?)<\/item>', caseSensitive: false);
    final titlePattern = RegExp(r'<title[^>]*>([\s\S]*?)<\/title>', caseSensitive: false);

    final itemMatch = itemPattern.firstMatch(xml);
    if (itemMatch == null) return null;

    final itemContent = itemMatch.group(1) ?? '';
    final titleMatch = titlePattern.firstMatch(itemContent);
    if (titleMatch == null) return null;

    var title = titleMatch.group(1) ?? '';
    // Strip CDATA wrapper if present.
    title = title.replaceAll(RegExp(r'<!\[CDATA\[|\]\]>'), '').trim();
    // Decode common HTML entities.
    title = title
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
    // Decode numeric HTML entities (decimal &#NNN; and hex &#xHH;)
    title = title.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) => String.fromCharCode(int.parse(m.group(1)!)),
    );
    title = title.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);', caseSensitive: false),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
    return title;
  }
}
