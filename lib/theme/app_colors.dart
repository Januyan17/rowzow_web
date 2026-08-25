import 'package:flutter/material.dart';

import '../models/service_type.dart';

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

  /// Surface for an occupied station. Flatter and darker than
  /// [cardBackground] so busy tiles recede behind the free ones.
  static const occupiedSurface = Color(0xFF141626);

  // One hue per activity, used on the service badge and on the customer's
  // name so the activity is identifiable at a glance across the room.
  static const ps5 = Color(0xFF4D7CFE);
  static const vr = Color(0xFFB14EFF);

  /// Teal rather than green: [available] owns green on this board, and a
  /// simulator tile that happened to be free would otherwise read as two
  /// different greens meaning two different things.
  static const simulator = Color(0xFF2DD4BF);
  static const theatre = Color(0xFFFBBF24);
  /// "Nearly out of time" — deliberately not [overtime] red, so red on this
  /// board means one thing only: the session has actually run over.
  static const warning = Color(0xFFFB923C);

  static const overtime = Color(0xFFFF4D67);

  /// Surface for a tile that has run over — a red wash strong enough to spot
  /// from across the room without drowning the text on it.
  static const overtimeSurface = Color(0xFF2A1520);
  static const live = Color(0xFF34D399);

  /// Reserved for "this station is free" — used only on the edge bar, the
  /// FREE pill and the availability line, never as a surface or a glow.
  static const available = Color(0xFF34D399);

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
