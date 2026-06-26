enum ServiceType {
  ps5,
  vr,
  simulator,
  theatre;

  static ServiceType fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'vr':
        return ServiceType.vr;
      case 'simulator':
        return ServiceType.simulator;
      case 'theatre':
      case 'theater':
        return ServiceType.theatre;
      default:
        return ServiceType.ps5;
    }
  }
}

/// One service line within a session, e.g. a PS5 slot or a theatre booking.
/// Parsed strictly from the explicit, non-financial column list documented
/// in the TV board query — never widen this to a `select('*')` result.
class TvSessionLine {
  const TvSessionLine({
    required this.lineId,
    required this.serviceType,
    required this.startTime,
    this.endTime,
    this.quantity,
    this.ps5Units,
    this.ps5ControllersByUnit,
    this.ps5StationIndices,
    this.plannedDurationMinutes,
    this.gracePeriodMinutes,
    this.totalPausedSeconds,
    this.theatrePersons,
    this.theatreHours,
    this.games,
  });

  final String lineId;
  final ServiceType serviceType;
  final DateTime startTime;
  final DateTime? endTime;
  final int? quantity;

  final int? ps5Units;
  final List<int>? ps5ControllersByUnit;
  final List<int>? ps5StationIndices;

  final int? plannedDurationMinutes;
  final int? gracePeriodMinutes;
  final int? totalPausedSeconds;

  final int? theatrePersons;
  final num? theatreHours;

  final String? games;

  factory TvSessionLine.fromJson(Map<String, dynamic> json) {
    final metadata =
        (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
    return TvSessionLine(
      lineId: json['id'].toString(),
      serviceType: ServiceType.fromString(json['service_type'] as String?),
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: json['end_time'] == null
          ? null
          : DateTime.parse(json['end_time'] as String).toLocal(),
      quantity: (json['quantity'] as num?)?.toInt(),
      ps5Units: (metadata['ps5_units'] as num?)?.toInt(),
      ps5ControllersByUnit: (metadata['ps5_controllers_by_unit'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      ps5StationIndices: (metadata['ps5_station_indices'] as List?)
          ?.map((e) => (e as num).toInt())
          .toList(),
      plannedDurationMinutes: (metadata['planned_duration_minutes'] as num?)
          ?.toInt(),
      gracePeriodMinutes: (metadata['grace_period_minutes'] as num?)?.toInt(),
      totalPausedSeconds: (metadata['total_paused_seconds'] as num?)?.toInt(),
      theatrePersons: (metadata['theatre_persons'] as num?)?.toInt(),
      theatreHours: metadata['theatre_hours'] as num?,
      games: metadata['games']?.toString(),
    );
  }
}
