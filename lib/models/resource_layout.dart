import 'ps5_station.dart';

/// The venue's physical capacity, as returned by the `tv_resource_layout()`
/// RPC.
///
/// The order of [ps5Stations] is significant: `ps5_station_indices` on an
/// active session are 0-based indices into this list.
class ResourceLayout {
  const ResourceLayout({
    this.ps5Stations = const [],
    this.vrUnits = 0,
    this.simulatorUnits = 0,
    this.theatreSeats = 0,
  });

  final List<Ps5Station> ps5Stations;
  final int vrUnits;
  final int simulatorUnits;
  final int theatreSeats;

  /// Stand-in for "the layout RPC returned no row", which is a valid state
  /// the board has to render rather than treat as an error.
  static const empty = ResourceLayout();

  bool get isEmpty =>
      ps5Stations.isEmpty &&
      vrUnits == 0 &&
      simulatorUnits == 0 &&
      theatreSeats == 0;

  factory ResourceLayout.fromJson(Map<String, dynamic> json) {
    final stations = (json['ps5_stations'] as List?) ?? const [];
    return ResourceLayout(
      ps5Stations: stations
          .whereType<Map>()
          .map((e) => Ps5Station.fromJson(e.cast<String, dynamic>()))
          .toList(),
      vrUnits: (json['vr_units'] as num?)?.toInt() ?? 0,
      simulatorUnits: (json['simulator_units'] as num?)?.toInt() ?? 0,
      theatreSeats: (json['theatre_seats'] as num?)?.toInt() ?? 0,
    );
  }
}
