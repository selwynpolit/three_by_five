import 'package:flutter/material.dart';

abstract final class AppShadows {
  // Strong directional shadows so cards visibly float on the dark
  // casino-green background.  Opacity is deliberately high because
  // semi-transparent black shadows are hard to see on a dark canvas.
  static const List<BoxShadow> card = [
    // Hard bottom-right drop shadow
    BoxShadow(
      color: Color(0x70000000),
      blurRadius: 8,
      offset: Offset(4, 6),
    ),
    // Softer right-edge accent
    BoxShadow(
      color: Color(0x48000000),
      blurRadius: 5,
      offset: Offset(6, 2),
      spreadRadius: -2,
    ),
    // Wide ambient halo
    BoxShadow(
      color: Color(0x28000000),
      blurRadius: 20,
      offset: Offset(3, 10),
      spreadRadius: -6,
    ),
  ];

  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color(0x88000000),
      blurRadius: 12,
      offset: Offset(6, 9),
    ),
    BoxShadow(
      color: Color(0x58000000),
      blurRadius: 7,
      offset: Offset(8, 3),
      spreadRadius: -3,
    ),
    BoxShadow(
      color: Color(0x30000000),
      blurRadius: 30,
      offset: Offset(4, 16),
      spreadRadius: -8,
    ),
  ];

  static const List<BoxShadow> dropdown = [
    BoxShadow(
      color: Color(0x28000000),
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
  ];
}
