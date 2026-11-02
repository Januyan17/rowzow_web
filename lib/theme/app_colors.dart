import 'package:flutter/material.dart';

import '../models/service_type.dart';

/// Shared palette for the TV board so the header, cards, and countdown all
/// agree on what "PS5 blue" / "overtime red" etc. look like.
class AppColors {
  AppColors._();

  static const backgroundBase = Color(0xFF04070F);

  static const background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF04070F), Color(0xFF070D1F), Color(0xFF0B1230)],
  );

  static const cardBackground = Color(0xFF0E1428);
  static const cardBorder = Color(0xFF263150);

  /// Surface for an occupied station. Flatter and darker than
  /// [cardBackground] so busy tiles recede behind the free ones.
  static const occupiedSurface = Color(0xFF090D1C);

  // Cool accents used only for chrome (header, banners, backdrop) — never to
  // carry a status, so they cannot be mistaken for one.
  static const auroraCyan = Color(0xFF5EE7FF);
  static const auroraViolet = Color(0xFF8B7BFF);
  static const sunsetOrange = Color(0xFFFF9F5A);

  // One hue per activity, used on the service badge and on the customer's
  // name so the activity is identifiable at a glance across the room.
  static const ps5 = Color(0xFF4D8DFF);
  static const vr = Color(0xFFC05CFF);

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
  static const overtimeSurface = Color(0xFF2A0F1C);
  static const live = Color(0xFF3CF0A0);

  /// Reserved for "this station is free" — used only on the edge bar, the
  /// FREE pill and the availability line, never as a surface or a glow.
  static const available = Color(0xFF3CF0A0);

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

  static IconData iconForServiceType(ServiceType type) => switch (type) {
    ServiceType.ps5 => Icons.sports_esports,
    ServiceType.vr => Icons.vrpano,
    ServiceType.simulator => Icons.directions_car,
    ServiceType.theatre => Icons.theaters,
  };
}
