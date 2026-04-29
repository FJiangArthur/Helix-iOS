import 'package:flutter/material.dart';

/// Typography scale for Helix.
///
/// Phase 1: serif/sans family is `SF Pro Display` (matches current theme).
/// Phase 2 swaps display/title to Fraunces and body to Inter.
class HelixType {
  HelixType._();

  // Phase 1 placeholders. Phase 2 changes _serifFamily to 'Fraunces' and
  // _sansFamily to 'Inter'.
  static const String _serifFamily = 'SF Pro Display';
  static const String _sansFamily = 'SF Pro Display';
  static const String _monoFamily = 'JetBrainsMono';

  static TextStyle display({Color? color}) => TextStyle(
        fontFamily: _serifFamily,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: color,
      );

  static TextStyle title1({Color? color}) => TextStyle(
        fontFamily: _serifFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.20,
        color: color,
      );

  static TextStyle title2({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.30,
        color: color,
      );

  static TextStyle title3({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: color,
      );

  static TextStyle bodyLg({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.50,
        color: color,
      );

  static TextStyle body({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.50,
        color: color,
      );

  static TextStyle bodySm({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: color,
      );

  static TextStyle caption({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.40,
        color: color,
      );

  static TextStyle label({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.30,
        letterSpacing: 0.6,
        color: color,
      );

  static TextStyle mono({Color? color}) => TextStyle(
        fontFamily: _monoFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.50,
        color: color,
      );
}
