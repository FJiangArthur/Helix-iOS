import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../utils/app_logger.dart';
import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';

/// Enhanced stock widget with large sparkline, day range bar, and watchlist.
class BmpEnhancedStockWidget extends BmpWidget {
  BmpEnhancedStockWidget({this.symbol = '^DJI', this.watchlist = const []});

  final String symbol;
  final List<String> watchlist;

  // Primary ticker data
  String? _companyName;
  double? _currentPrice;
  double? _changeAmount;
  double? _changePercent;
  double? _dayHigh;
  double? _dayLow;
  List<double> _intradayPrices = [];

  // Watchlist data
  final List<_WatchlistItem> _watchlistItems = [];

  @override
  String get id => 'enh_stock';

  @override
  String get displayName => 'Enhanced Stock';

  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  @override
  Future<void> refresh() async {
    try {
      await _fetchQuote();
    } catch (e) {
      appLogger.w('EnhStock: quote fetch failed: $e');
    }
    try {
      await _fetchIntraday();
    } catch (e) {
      appLogger.w('EnhStock: intraday fetch failed: $e');
    }
    for (final ticker in watchlist.take(3)) {
      try {
        await _fetchWatchlistItem(ticker);
      } catch (e) {
        appLogger.w('EnhStock: watchlist $ticker failed: $e');
      }
    }
    lastRefreshed = DateTime.now();
  }

  Future<Map?> _fetchChart(String ticker, String interval) async {
    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/$ticker'
      '?range=1d&interval=$interval',
    );
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return ((json['chart'] as Map?)?['result'] as List?)?.firstOrNull
          as Map?;
    } finally {
      client.close(force: false);
    }
  }

  Future<void> _fetchQuote() async {
    final result = await _fetchChart(symbol, '1d');
    if (result == null) return;
    final meta = result['meta'] as Map<String, dynamic>?;
    if (meta == null) return;

    _companyName =
        meta['shortName'] as String? ?? meta['symbol'] as String? ?? symbol;
    _currentPrice = (meta['regularMarketPrice'] as num?)?.toDouble();
    _dayHigh = (meta['regularMarketDayHigh'] as num?)?.toDouble();
    _dayLow = (meta['regularMarketDayLow'] as num?)?.toDouble();
    final prevClose = (meta['chartPreviousClose'] as num?)?.toDouble();
    if (_currentPrice != null && prevClose != null && prevClose != 0) {
      _changeAmount = _currentPrice! - prevClose;
      _changePercent = (_changeAmount! / prevClose) * 100;
    }
  }

  Future<void> _fetchIntraday() async {
    final result = await _fetchChart(symbol, '5m');
    if (result == null) return;
    final indicators = result['indicators'] as Map?;
    final quotes = (indicators?['quote'] as List?)?.firstOrNull as Map?;
    final closes = quotes?['close'] as List?;
    if (closes != null) {
      _intradayPrices = closes
          .where((e) => e != null)
          .map<double>((e) => (e as num).toDouble())
          .toList();
    }
  }

  Future<void> _fetchWatchlistItem(String ticker) async {
    final result = await _fetchChart(ticker, '1d');
    if (result == null) return;
    final meta = result['meta'] as Map<String, dynamic>?;
    if (meta == null) return;

    final price = (meta['regularMarketPrice'] as num?)?.toDouble();
    final prevClose = (meta['chartPreviousClose'] as num?)?.toDouble();
    double? changePct;
    if (price != null && prevClose != null && prevClose != 0) {
      changePct = ((price - prevClose) / prevClose) * 100;
    }

    // Update or add
    _watchlistItems.removeWhere((i) => i.symbol == ticker);
    _watchlistItems.add(_WatchlistItem(
      symbol: ticker,
      price: price,
      changePercent: changePct,
    ));
  }

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    final w = zone.width.toDouble();
    final h = zone.height.toDouble();

    // Row 1: Company name + arrow icon
    final name = _companyName ?? symbol;
    final arrowIcon =
        (_changeAmount ?? 0) >= 0 ? HudIcon.stockUp : HudIcon.stockDown;
    HudDraw.icon(canvas, const Offset(0, 0), arrowIcon, 14);
    HudDraw.text(canvas, name, const Offset(16, 0),
        fontSize: 14, weight: FontWeight.bold, maxWidth: w - 20);

    // Row 2: Large price + change
    final priceStr =
        _currentPrice != null ? _currentPrice!.toStringAsFixed(2) : '--';
    HudDraw.text(canvas, priceStr, const Offset(0, 18),
        fontSize: 22, weight: FontWeight.bold);

    final sign = (_changeAmount ?? 0) >= 0 ? '+' : '';
    final changeStr = _changeAmount != null
        ? '$sign${_changeAmount!.toStringAsFixed(2)} (${_changePercent!.toStringAsFixed(1)}%)'
        : '';
    final priceSize = HudDraw.measure(priceStr, fontSize: 22, weight: FontWeight.bold);
    HudDraw.text(canvas, changeStr, Offset(priceSize.width + 8, 24),
        fontSize: 12);

    // Day range progress bar
    if (_dayHigh != null && _dayLow != null && _currentPrice != null) {
      final range = _dayHigh! - _dayLow!;
      final progress = range > 0 ? (_currentPrice! - _dayLow!) / range : 0.5;
      HudDraw.text(canvas, 'L:${_dayLow!.toStringAsFixed(0)}', const Offset(0, 44),
          fontSize: 9);
      HudDraw.progressBar(
        canvas,
        ui.Rect.fromLTWH(50, 44, w - 120, 10),
        progress,
      );
      HudDraw.text(canvas, 'H:${_dayHigh!.toStringAsFixed(0)}',
          Offset(w - 64, 44), fontSize: 9);
    }

    // Sparkline chart
    if (_intradayPrices.length >= 2) {
      final chartTop = 58.0;
      final chartH = h - chartTop - (_watchlistItems.isNotEmpty ? 36 : 4);
      if (chartH > 10) {
        HudDraw.sparkline(
          canvas, ui.Rect.fromLTWH(0, chartTop, w, chartH), _intradayPrices);
      }
    }

    // Watchlist mini-table at bottom
    if (_watchlistItems.isNotEmpty) {
      final tableY = h - 32.0;
      HudDraw.dashedHLine(canvas, 0, tableY - 4, w, thickness: 1);
      final colW = w / 3;
      for (int i = 0; i < _watchlistItems.length && i < 3; i++) {
        final item = _watchlistItems[i];
        final x = i * colW;
        HudDraw.text(canvas, item.symbol, Offset(x, tableY),
            fontSize: 10, weight: FontWeight.bold, maxWidth: colW);
        final pStr = item.price != null
            ? item.price!.toStringAsFixed(1)
            : '--';
        final cStr = item.changePercent != null
            ? '${item.changePercent! >= 0 ? '+' : ''}${item.changePercent!.toStringAsFixed(1)}%'
            : '';
        HudDraw.text(canvas, '$pStr $cStr', Offset(x, tableY + 12),
            fontSize: 9, maxWidth: colW);
      }
    }
  }
}

class _WatchlistItem {
  final String symbol;
  final double? price;
  final double? changePercent;

  const _WatchlistItem({
    required this.symbol,
    this.price,
    this.changePercent,
  });
}
