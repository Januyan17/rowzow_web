import 'tv_session_line.dart';

class TvSession {
  const TvSession({
    required this.sessionId,
    required this.startTime,
    required this.status,
    required this.lines,
    this.customerName,
    this.endTime,
  });

  final String sessionId;
  final String? customerName;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final List<TvSessionLine> lines;

  /// Lines still in progress; falls back to all lines if every line has
  /// already been closed out (shouldn't normally happen for an active
  /// session, but keeps the card from rendering empty).
  List<TvSessionLine> get openLines {
    final open = lines.where((line) => line.endTime == null).toList();
    return open.isNotEmpty ? open : lines;
  }

  factory TvSession.fromJson(Map<String, dynamic> json) {
    final customer = json['customers'] as Map?;
    final lineRows = (json['session_service_lines'] as List?) ?? const [];
    return TvSession(
      sessionId: json['id'].toString(),
      customerName: customer?['name'] as String?,
      startTime: DateTime.parse(json['start_time'] as String).toLocal(),
      endTime: json['end_time'] == null
          ? null
          : DateTime.parse(json['end_time'] as String).toLocal(),
      status: json['status'] as String? ?? '',
      lines: lineRows
          .map(
            (row) => TvSessionLine.fromJson((row as Map).cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}
