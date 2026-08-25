import 'service_type.dart';

/// One in-progress service line, as returned by the `tv_active_sessions()`
/// RPC.
///
/// SAFETY: this mirrors that function's allow-listed column set exactly.
/// [customerName] is displayed by explicit owner decision, in full, on a
/// board that is public to the internet. Everything else stays out: no
/// phone numbers, staff names, prices, or payment amounts — `metadata` on
/// the underlying line carries `planned_price`, which must never reach this
/// screen. Never read the underlying tables directly either; the anon role
/// has no grant on them by design, so a table query returns 42501 rather
/// than data.
class TvActiveSession {
  const TvActiveSession({
    required this.serviceType,
    required this.startTime,
    this.customerName,
    this.ps5StationIndices = const [],
    this.ps5Units = 1,
    this.theatrePersons = 0,
    this.totalPausedSeconds = 0,
    this.plannedDurationMinutes,
    this.pausedAt,
  });

  final ServiceType serviceType;

  /// Null until `tv_active_sessions()` is updated to return
  /// `customer_name`, and null for a walk-in with no name on the session.
  /// The board falls back to the station label alone in both cases.
  final String? customerName;

  /// UTC instant converted to local time for display.
  final DateTime startTime;

  /// 0-based indices into [ResourceLayout.ps5Stations]. Empty for any
  /// service that does not occupy a numbered PS5 station.
  final List<int> ps5StationIndices;

  final int ps5Units;
  final int theatrePersons;

  /// Pause time that has already been banked. The pause currently in
  /// progress (if any) is *not* included here — see [elapsedAt].
  final int totalPausedSeconds;

  /// null means open-ended: no planned end, so no countdown.
  final int? plannedDurationMinutes;

  /// Non-null while the session is paused right now.
  final DateTime? pausedAt;

  bool get isPaused => pausedAt != null;
  bool get isOpenEnded => plannedDurationMinutes == null;

  factory TvActiveSession.fromJson(Map<String, dynamic> json) {
    return TvActiveSession(
      serviceType: ServiceType.fromString(json['service_type'] as String?),
      startTime: _parseUtc(json['start_time'] as String),
      customerName: _trimToNull(json['customer_name']),
      ps5StationIndices: (json['ps5_station_indices'] as List?)
              ?.whereType<num>()
              .map((e) => e.toInt())
              .toList() ??
          const [],
      ps5Units: (json['ps5_units'] as num?)?.toInt() ?? 1,
      theatrePersons: (json['theatre_persons'] as num?)?.toInt() ?? 0,
      totalPausedSeconds: (json['total_paused_seconds'] as num?)?.toInt() ?? 0,
      plannedDurationMinutes: (json['planned_duration_minutes'] as num?)?.toInt(),
      pausedAt: json['paused_at'] == null
          ? null
          : _parseUtc(json['paused_at'] as String),
    );
  }

  /// Playing time so far, with paused time removed.
  ///
  /// `total_paused_seconds` only covers pauses that have already ended. A
  /// pause that is still running has not been banked into it yet, so while
  /// [pausedAt] is set we measure up to that instant instead of to [now] —
  /// which both accounts for the open pause and freezes the readout for as
  /// long as it lasts.
  Duration elapsedAt(DateTime now) {
    final reference = pausedAt ?? now;
    final raw =
        reference.difference(startTime) - Duration(seconds: totalPausedSeconds);
    return raw.isNegative ? Duration.zero : raw;
  }

  /// Time left against the planned duration; null when open-ended.
  /// Negative once the session runs past its planned end (overtime).
  Duration? remainingAt(DateTime now) {
    final planned = plannedDurationMinutes;
    if (planned == null) return null;
    return Duration(minutes: planned) - elapsedAt(now);
  }

  /// Whether this session has run past its planned end. Always false for an
  /// open-ended session, which has no end to run past.
  bool isOvertimeAt(DateTime now) {
    final left = remainingAt(now);
    return left != null && left.isNegative;
  }

  /// Fraction of the planned duration consumed, 0..1; null when open-ended.
  double? progressAt(DateTime now) {
    final planned = plannedDurationMinutes;
    if (planned == null || planned <= 0) return null;
    return (elapsedAt(now).inSeconds / (planned * 60)).clamp(0.0, 1.0);
  }

  /// Treats an absent, null, or blank name as "no name", so the board never
  /// renders an empty subtitle or a stray "null".
  static String? _trimToNull(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  static DateTime _parseUtc(String raw) {
    final parsed = DateTime.parse(raw);
    if (parsed.isUtc) return parsed.toLocal();
    // A value carrying no UTC offset parses as local time. The RPC
    // documents UTC, so re-pin the same wall-clock reading to UTC before
    // converting, otherwise every countdown is off by the TV's offset.
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
  }
}
