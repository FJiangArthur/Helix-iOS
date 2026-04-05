import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../utils/app_logger.dart';
import '../bmp_widget.dart';
import '../display_constants.dart';
import '../draw_helpers.dart';
import '../enhanced_data_provider.dart';

/// Enhanced stock widget — reads from EnhancedDataProvider.
class BmpEnhancedStockWidget extends BmpWidget {
  BmpEnhancedStockWidget({this.symbol = '^DJI'});

  final String symbol;

  @override
  String get id => 'enh_stock';

  @override
  String get displayName => 'Enhanced Stock';

  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  @override
  Future<void> refresh() async {
    final data = EnhancedDataProvider.instance;
    try {
      await _fetchQuote(data);
    } catch (e) {
      appLogger.w('EnhStock: quote fetch failed: $e');
    }
    try {
      await _fetchIntraday(data);
    } catch (e) {
      appLogger.w('EnhStock: intraday fetch failed: $e');
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

  Future<void> _fetchQuote(EnhancedDataProvider data) async {
    final result = await _fetchChart(symbol, '1d');
    if (result == null) return;
    final meta = result['meta'] as Map<String, dynamic>?;
    if (meta == null) return;

    data.stockTicker =
        meta['shortName'] as String? ?? meta['symbol'] as String? ?? symbol;
    data.stockPrice = (meta['regularMarketPrice'] as num?)?.toDouble();
    final prevClose = (meta['chartPreviousClose'] as num?)?.toDouble();
    if (data.stockPrice != null && prevClose != null && prevClose != 0) {
      data.stockChange = data.stockPrice! - prevClose;
      data.stockChangePercent = (data.stockChange! / prevClose) * 100;
    }
  }

  Future<void> _fetchIntraday(EnhancedDataProvider data) async {
    final result = await _fetchChart(symbol, '5m');
    if (result == null) return;
    final indicators = result['indicators'] as Map?;
    final quotes = (indicators?['quote'] as List?)?.firstOrNull as Map?;
    final closes = quotes?['close'] as List?;
    if (closes != null) {
      data.stockIntradayPrices = closes
          .where((e) => e != null)
          .map<double>((e) => (e as num).toDouble())
          .toList();
    }
  }

  @override
  void renderToCanvas(ui.Canvas canvas, HudZone zone) {
    final w = zone.width.toDouble();
    final h = zone.height.toDouble();
    final data = EnhancedDataProvider.instance;

    HudDraw.icon(canvas, Offset.zero, HudIcon.trending, 10);
    HudDraw.text(canvas, 'STOCK', const Offset(12, 0), fontSize: 10, weight: FontWeight.bold);

    final ticker = data.stockTicker ?? '---';
    final tickerSize = HudDraw.measure(ticker, fontSize: 10);
    HudDraw.text(canvas, ticker, Offset(w - tickerSize.width - 2, 0), fontSize: 10);

    final priceStr = data.stockPrice != null ? data.stockPrice!.toStringAsFixed(2) : '--';
    HudDraw.text(canvas, priceStr, const Offset(2, 12), fontSize: 12, weight: FontWeight.bold);

    final change = data.stockChange;
    if (change != null) {
      final sign = change >= 0 ? '+' : '';
      final pctStr = data.stockChangePercent != null
          ? ' (${data.stockChangePercent!.toStringAsFixed(1)}%)'
          : '';
      HudDraw.text(canvas, '$sign${change.toStringAsFixed(2)}$pctStr', const Offset(2, 26), fontSize: 10);
    }

    if (data.stockIntradayPrices.length >= 2) {
      final chartTop = 38.0;
      final chartHeight = h - chartTop - 2;
      if (chartHeight > 4) {
        HudDraw.sparkline(canvas, ui.Rect.fromLTWH(2, chartTop, w - 4, chartHeight), data.stockIntradayPrices);
      }
    }
  }
}
