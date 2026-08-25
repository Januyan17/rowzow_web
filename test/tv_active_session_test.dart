import 'package:flutter_test/flutter_test.dart';
import 'package:rowzow_web/models/resource_layout.dart';
import 'package:rowzow_web/models/service_type.dart';
import 'package:rowzow_web/models/tv_active_session.dart';

void main() {
  group('TvActiveSession.fromJson', () {
    test('parses the RPC payload', () {
      final session = TvActiveSession.fromJson({
        'service_type': 'ps5',
        'ps5_station_indices': [0, 2],
        'start_time': '2026-08-25T10:00:00+00:00',
        'planned_duration_minutes': 60,
        'paused_at': null,
        'total_paused_seconds': 120,
        'ps5_units': 2,
        'theatre_persons': 0,
      });

      expect(session.serviceType, ServiceType.ps5);
      expect(session.ps5StationIndices, [0, 2]);
      expect(session.ps5Units, 2);
      expect(session.totalPausedSeconds, 120);
      expect(session.plannedDurationMinutes, 60);
      expect(session.isPaused, isFalse);
      expect(session.isOpenEnded, isFalse);
      expect(session.startTime.toUtc(), DateTime.utc(2026, 8, 25, 10));
    });

    test('reads customer_name when the RPC returns it', () {
      final session = TvActiveSession.fromJson({
        'service_type': 'ps5',
        'start_time': '2026-08-25T10:00:00Z',
        'customer_name': 'Januyan Seralaghan',
      });

      expect(session.customerName, 'Januyan Seralaghan');
    });

    test('treats an absent or blank customer_name as no name', () {
      final absent = TvActiveSession.fromJson({
        'service_type': 'ps5',
        'start_time': '2026-08-25T10:00:00Z',
      });
      final blank = TvActiveSession.fromJson({
        'service_type': 'ps5',
        'start_time': '2026-08-25T10:00:00Z',
        'customer_name': '   ',
      });

      expect(absent.customerName, isNull);
      expect(blank.customerName, isNull);
    });

    test('treats an offset-less timestamp as UTC, not local', () {
      final session = TvActiveSession.fromJson({
        'service_type': 'vr',
        'start_time': '2026-08-25T10:00:00',
        'total_paused_seconds': 0,
      });

      expect(session.startTime.toUtc(), DateTime.utc(2026, 8, 25, 10));
    });

    test('tolerates missing optional fields', () {
      final session = TvActiveSession.fromJson({
        'service_type': 'theatre',
        'start_time': '2026-08-25T10:00:00Z',
      });

      expect(session.ps5StationIndices, isEmpty);
      expect(session.theatrePersons, 0);
      expect(session.totalPausedSeconds, 0);
      expect(session.plannedDurationMinutes, isNull);
      expect(session.isOpenEnded, isTrue);
    });
  });

  group('timing', () {
    final start = DateTime.utc(2026, 8, 25, 10);

    TvActiveSession sessionWith({
      int? plannedMinutes = 60,
      int totalPausedSeconds = 0,
      DateTime? pausedAt,
    }) {
      return TvActiveSession(
        serviceType: ServiceType.ps5,
        startTime: start,
        plannedDurationMinutes: plannedMinutes,
        totalPausedSeconds: totalPausedSeconds,
        pausedAt: pausedAt,
      );
    }

    test('elapsed subtracts already-banked pause time', () {
      final session = sessionWith(totalPausedSeconds: 300);
      final now = start.add(const Duration(minutes: 20));

      expect(session.elapsedAt(now), const Duration(minutes: 15));
    });

    test('remaining counts down against the planned duration', () {
      final session = sessionWith();
      final now = start.add(const Duration(minutes: 20));

      expect(session.remainingAt(now), const Duration(minutes: 40));
    });

    test('remaining goes negative once past the planned end (overtime)', () {
      final session = sessionWith();
      final now = start.add(const Duration(minutes: 75));

      expect(session.remainingAt(now), const Duration(minutes: -15));
    });

    test('an open-ended session has no countdown', () {
      final session = sessionWith(plannedMinutes: null);
      final now = start.add(const Duration(minutes: 20));

      expect(session.remainingAt(now), isNull);
      expect(session.progressAt(now), isNull);
      expect(session.elapsedAt(now), const Duration(minutes: 20));
    });

    test('a paused session freezes as wall-clock time advances', () {
      final session = sessionWith(
        pausedAt: start.add(const Duration(minutes: 10)),
      );

      final atPause = session.elapsedAt(start.add(const Duration(minutes: 10)));
      final muchLater = session.elapsedAt(
        start.add(const Duration(minutes: 90)),
      );

      expect(atPause, const Duration(minutes: 10));
      expect(muchLater, const Duration(minutes: 10));
      expect(
        session.remainingAt(start.add(const Duration(minutes: 90))),
        const Duration(minutes: 50),
      );
    });

    test('a pause in progress is not double-counted with banked pauses', () {
      // 5 minutes already banked from an earlier pause, then paused again
      // 20 minutes in: only the first pause has landed in the total.
      final session = sessionWith(
        totalPausedSeconds: 300,
        pausedAt: start.add(const Duration(minutes: 20)),
      );

      expect(
        session.elapsedAt(start.add(const Duration(hours: 3))),
        const Duration(minutes: 15),
      );
    });

    test('elapsed never goes negative for a not-yet-started session', () {
      final session = sessionWith();

      expect(
        session.elapsedAt(start.subtract(const Duration(minutes: 5))),
        Duration.zero,
      );
    });

    test('isOvertimeAt flips only once past the planned end', () {
      final session = sessionWith();

      expect(session.isOvertimeAt(start.add(const Duration(minutes: 59))), isFalse);
      expect(session.isOvertimeAt(start.add(const Duration(minutes: 61))), isTrue);
    });

    test('an open-ended session is never overtime', () {
      final session = sessionWith(plannedMinutes: null);

      expect(session.isOvertimeAt(start.add(const Duration(days: 1))), isFalse);
    });

    test('a paused session cannot drift into overtime', () {
      // Frozen 10 minutes into a 60 minute booking; hours of wall clock go by.
      final session = sessionWith(
        pausedAt: start.add(const Duration(minutes: 10)),
      );

      expect(session.isOvertimeAt(start.add(const Duration(hours: 5))), isFalse);
    });

    test('progress clamps to 0..1', () {
      final session = sessionWith();

      expect(session.progressAt(start.add(const Duration(minutes: 30))), 0.5);
      expect(session.progressAt(start.add(const Duration(minutes: 300))), 1.0);
    });
  });

  group('ResourceLayout', () {
    test('parses the layout payload, preserving station order', () {
      final layout = ResourceLayout.fromJson({
        'ps5_stations': [
          {'label': 'Alpha', 'max_controllers': 4},
          {'label': 'Beta', 'max_controllers': 4},
          {'label': 'Gama', 'max_controllers': 2},
        ],
        'vr_units': 1,
        'simulator_units': 1,
        'theatre_seats': 10,
      });

      expect(layout.ps5Stations.map((s) => s.label), ['Alpha', 'Beta', 'Gama']);
      expect(layout.ps5Stations[2].maxControllers, 2);
      expect(layout.theatreSeats, 10);
      expect(layout.isEmpty, isFalse);
    });

    test('an absent layout row is empty rather than an error', () {
      expect(ResourceLayout.empty.isEmpty, isTrue);
      expect(ResourceLayout.fromJson(const {}).isEmpty, isTrue);
    });
  });
}
