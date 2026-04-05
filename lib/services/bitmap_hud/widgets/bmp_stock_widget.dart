import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../utils/app_logger.dart';
import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';

/// Displays a stock ticker with price, change, and a sparkline chart.
/// Uses Yahoo Finance v8 free endpoint.
class BmpStockWidget extends BmpWidget {
  BmpStockWidget({this.symbol = '^DJI'});

  final String symbol;

  // Cached data ---------------------------------------------------------------
  String? _companyName;
  double? _currentPrice;
  double? _changeAmount;
  double? _changePercent;
  List<double> _intradayPrices = [];

  // BmpWidget -----------------------------------------------------------------

  @override
  String get id => 'bmp_stock';

  @override
  String get displayName => 'Stock ($symbol)';

  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  @override
  Future<void> refresh() async {
    try {
      await _fetchQuote();
    } catch (e) {
      appLogger.w('BmpStock: quote fetch failed for $symbol: $e');
    }
    try {
      await _fetchIntraday();
    } catch (e) {
      appLogger.w('BmpStock: intraday fetch failed for $symbol: $e');
    }
    lastRefreshed = DateTime.now();
  }

  // Network -------------------------------------------------------------------

  /// Fetch the first chart result for [interval] from Yahoo Finance.
  Future<Map?> _fetchChart(String interval) async {
    final uri = Uri.parse(
      'https://query1.finance.yahoo.com/v8/finance/chart/$symbol'
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
    final result = await _fetchChart('1d');
    if (result == null) return;

    final meta = result['meta'] as Map<String, dynamic>?;
    if (meta == null) return;

    _companyName =
        meta['shortName'] as String? ?? meta['symbol'] as String? ?? symbol;
    _currentPrice = (meta['regularMarketPrice'] as num?)?.toDouble();
    final prevClose = (meta['chartPreviousClose'] as num?)?.toDouble();
    if (_currentPrice != null && prevClose != null && prevClose != 0) {
      _changeAmount = _currentPrice! - prevClose;
      _changePercent = (_changeAmount! / prevClose) * 100;
    }
  }

  Future<void> _fetchIntraday() async {
    final result = await _fetchChart('5m');
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

  // Rendering -----------------------------------------------------------------

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    final w = zone.width.toDouble();
    final h = zone.height.toDouble();

    final name = _companyName ?? symbol;
    HudDraw.text(canvas, name, Offset.zero,
        fontSize: 10, weight: FontWeight.bold, maxWidth: w);

    final priceStr = _currentPrice != null ? _currentPrice!.toStringAsFixed(2) : '--';
    final sign = (_changeAmount ?? 0) >= 0 ? '+' : '';
    final changeStr = _changeAmount != null
        ? '$sign${_changeAmount!.toStringAsFixed(2)} (${_changePercent!.toStringAsFixed(1)}%)'
        : '';

    const arrowSize = 10.0;
    final arrowIcon = (_changeAmount ?? 0) >= 0 ? HudIcon.stockUp : HudIcon.stockDown;
    HudDraw.icon(canvas, const Offset(0, 12), arrowIcon, arrowSize);
    HudDraw.text(canvas, '$priceStr $changeStr', const Offset(arrowSize + 2, 12),
        fontSize: 10, maxWidth: w - arrowSize - 4);

    if (_intradayPrices.length >= 2) {
      const chartTop = 26.0;
      final chartHeight = h - chartTop - 2;
      if (chartHeight > 4) {
        final bounds = ui.Rect.fromLTWH(0, chartTop, w, chartHeight);
        HudDraw.sparkline(canvas, bounds, _intradayPrices);
      }
    }
  }
}
