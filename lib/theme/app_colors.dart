import 'package:flutter/material.dart';

import '../models/tv_session_line.dart';

/// Shared palette for the TV board so the header, cards, and countdown all
/// agree on what "PS5 blue" / "overtime red" etc. look like.
class AppColors {
  AppColors._();

  static const background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A0E1A), Color(0xFF161229), Color(0xFF1B1030)],
  );

  static const cardBackground = Color(0xFF181A2B);
  static const cardBorder = Color(0xFF2A2D45);

  static const ps5 = Color(0xFF4D7CFE);
  static const vr = Color(0xFFB14EFF);
  static const simulator = Color(0xFF34D399);
  static const theatre = Color(0xFFFBBF24);
  static const overtime = Color(0xFFFF4D67);
  static const live = Color(0xFF34D399);

  static Color forServiceType(ServiceType type) {
    switch (type) {
      case ServiceType.ps5:
        return ps5;
      case ServiceType.vr:
        return vr;
      case ServiceType.simulator:
        return simulator;
      case ServiceType.theatre:
        return theatre;
    }
  }
}
