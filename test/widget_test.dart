import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rowzow_web/config/app_config.dart';
import 'package:rowzow_web/data/tv_repository.dart';
import 'package:rowzow_web/models/ps5_station.dart';
import 'package:rowzow_web/models/resource_layout.dart';
import 'package:rowzow_web/models/service_type.dart';
import 'package:rowzow_web/models/tv_active_session.dart';
import 'package:rowzow_web/pages/tv_board_page.dart';
import 'package:rowzow_web/state/tv_board_controller.dart';
import 'package:rowzow_web/theme/app_colors.dart';

/// Stands in for [TvRepository] so the test never touches the real Supabase
/// client.
class _FakeTvRepository implements TvRepository {
  _FakeTvRepository({
    this.sessions = const [],
    this.layout = ResourceLayout.empty,
    Stream<void>? changes,
  }) : changes = changes ?? const Stream<void>.empty();

  final List<TvActiveSession> sessions;
  final ResourceLayout layout;
  final Stream<void> changes;

  @override
  Future<List<TvActiveSession>> fetchActiveSessions() async => sessions;

  @override
  Future<ResourceLayout> fetchResourceLayout() async => layout;

  @override
  Stream<void> watchBoardChanges() => changes;
}

const _layout = ResourceLayout(
  ps5Stations: [
    Ps5Station(label: 'Alpha', maxControllers: 4),
    Ps5Station(label: 'Beta', maxControllers: 2),
  ],
  vrUnits: 1,
  simulatorUnits: 1,
  theatreSeats: 10,
);

Future<void> _pumpBoard(WidgetTester tester, TvBoardController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: TvBoardPage(controller: controller),
    ),
  );
  await tester.pump();
}

/// Tears the tree down so the board's periodic timers are cancelled before
/// the test ends, otherwise the binding flags them as pending.
Future<void> _teardown(WidgetTester tester) => tester.pumpWidget(const SizedBox());

void main() {
  testWidgets('renders every station as free when nothing is running', (
    tester,
  ) async {
    await _pumpBoard(
      tester,
      TvBoardController(_FakeTvRepository(layout: _layout)),
    );

    expect(find.text(AppConfig.appName), findsOneWidget);
    expect(find.text('All stations free'), findsOneWidget);
    // Idle stations are rendered, not hidden.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('FREE'), findsWidgets);

    await _teardown(tester);
  });

  testWidgets('an active theatre renders one tile, not two', (tester) async {
    final session = TvActiveSession(
      serviceType: ServiceType.theatre,
      startTime: DateTime.now().subtract(const Duration(minutes: 10)),
      plannedDurationMinutes: 120,
      theatrePersons: 4,
      customerName: 'Januyan_17',
    );

    await _pumpBoard(
      tester,
      TvBoardController(
        _FakeTvRepository(layout: _layout, sessions: [session]),
      ),
    );

    // One theatre card carrying both the session and the seat pool — the
    // standalone "Theatre seats" tile must not double up alongside it.
    expect(find.text('Theatre'), findsOneWidget);
    expect(find.text('Theatre seats'), findsNothing);
    expect(find.text('Januyan_17'), findsOneWidget);
    // Headcount and seating are deliberately not on this board.
    expect(find.text('4 / 10 seats taken'), findsNothing);
    expect(find.text('6 free'), findsNothing);
    expect(find.text('4 persons'), findsNothing);
    expect(find.text('REMAINING'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('an empty theatre renders a single free tile', (tester) async {
    await _pumpBoard(
      tester,
      TvBoardController(_FakeTvRepository(layout: _layout)),
    );

    expect(find.text('Theatre'), findsOneWidget);
    expect(find.text('Theatre seats'), findsNothing);
    expect(find.text('10 seats'), findsNothing);

    await _teardown(tester);
  });

  testWidgets('an empty layout does not crash the page', (tester) async {
    await _pumpBoard(tester, TvBoardController(_FakeTvRepository()));

    expect(tester.takeException(), isNull);
    expect(find.text('No stations configured'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('marks the busy station and leaves the other free', (
    tester,
  ) async {
    final session = TvActiveSession(
      serviceType: ServiceType.ps5,
      startTime: DateTime.now().subtract(const Duration(minutes: 10)),
      ps5StationIndices: const [0],
      plannedDurationMinutes: 60,
    );

    await _pumpBoard(
      tester,
      TvBoardController(
        _FakeTvRepository(layout: _layout, sessions: [session]),
      ),
    );

    expect(find.text('All stations free'), findsNothing);
    expect(find.text('IN USE'), findsOneWidget);
    expect(find.text('REMAINING'), findsOneWidget);
    expect(find.text('1 active'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('shows the customer name on the busy station', (tester) async {
    final session = TvActiveSession(
      serviceType: ServiceType.ps5,
      startTime: DateTime.now().subtract(const Duration(minutes: 5)),
      ps5StationIndices: const [0],
      plannedDurationMinutes: 60,
      customerName: 'Januyan Seralaghan',
    );

    await _pumpBoard(
      tester,
      TvBoardController(
        _FakeTvRepository(layout: _layout, sessions: [session]),
      ),
    );

    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Januyan Seralaghan'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('a session with no name shows the station label alone', (
    tester,
  ) async {
    final session = TvActiveSession(
      serviceType: ServiceType.ps5,
      startTime: DateTime.now().subtract(const Duration(minutes: 5)),
      ps5StationIndices: const [0],
      plannedDurationMinutes: 60,
    );

    await _pumpBoard(
      tester,
      TvBoardController(
        _FakeTvRepository(layout: _layout, sessions: [session]),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('IN USE'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('prints the customer name in the activity colour', (
    tester,
  ) async {
    final ps5 = TvActiveSession(
      serviceType: ServiceType.ps5,
      startTime: DateTime.now().subtract(const Duration(minutes: 5)),
      ps5StationIndices: const [0],
      customerName: 'Januyan Seralaghan',
    );
    final theatre = TvActiveSession(
      serviceType: ServiceType.theatre,
      startTime: DateTime.now().subtract(const Duration(minutes: 5)),
      theatrePersons: 3,
      customerName: 'Priya Raveendran',
    );

    await _pumpBoard(
      tester,
      TvBoardController(
        _FakeTvRepository(layout: _layout, sessions: [ps5, theatre]),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Januyan Seralaghan')).style?.color,
      AppColors.ps5,
    );
    expect(
      tester.widget<Text>(find.text('Priya Raveendran')).style?.color,
      AppColors.theatre,
    );

    await _teardown(tester);
  });

  testWidgets('a free station is highlighted, an in-use one is not', (
    tester,
  ) async {
    final session = TvActiveSession(
      serviceType: ServiceType.ps5,
      startTime: DateTime.now().subtract(const Duration(minutes: 5)),
      ps5StationIndices: const [0],
      customerName: 'Januyan Seralaghan',
    );

    await _pumpBoard(
      tester,
      TvBoardController(
        _FakeTvRepository(layout: _layout, sessions: [session]),
      ),
    );

    // Alpha is taken, Beta is not: the free one carries the availability
    // treatment, the occupied one is receded.
    expect(find.text('IN USE'), findsOneWidget);
    expect(find.text('FREE'), findsWidgets);
    final available = tester.widget<Text>(find.text('Available now').first);
    expect(available.style?.color, AppColors.available);
    expect(available.style?.fontWeight, FontWeight.w600);

    await _teardown(tester);
  });

  testWidgets('a paused session shows PAUSED and a frozen countdown', (
    tester,
  ) async {
    final now = DateTime.now();
    final session = TvActiveSession(
      serviceType: ServiceType.ps5,
      startTime: now.subtract(const Duration(minutes: 30)),
      pausedAt: now.subtract(const Duration(minutes: 20)),
      ps5StationIndices: const [0],
      plannedDurationMinutes: 60,
    );

    await _pumpBoard(
      tester,
      TvBoardController(
        _FakeTvRepository(layout: _layout, sessions: [session]),
      ),
    );

    expect(find.text('PAUSED'), findsOneWidget);
    // Elapsed froze at paused_at - start_time = 10m, and stays there as the
    // ticker advances.
    expect(find.text('10m 00s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('10m 00s'), findsOneWidget);
    expect(find.text('50m 00s'), findsOneWidget);

    await _teardown(tester);
  });

  testWidgets('an overrun session is flagged in red, not dimmed', (
    tester,
  ) async {
    final session = TvActiveSession(
      serviceType: ServiceType.ps5,
      startTime: DateTime.now().subtract(const Duration(minutes: 75)),
      ps5StationIndices: const [0],
      plannedDurationMinutes: 60,
      customerName: 'Arun K',
    );

    await _pumpBoard(
      tester,
      TvBoardController(
        _FakeTvRepository(layout: _layout, sessions: [session]),
      ),
    );

    expect(find.text('OVERTIME'), findsOneWidget);
    expect(find.text('REMAINING'), findsNothing);
    final value = tester.widget<Text>(find.textContaining('+15m'));
    expect(value.style?.color, AppColors.overtime);

    await _teardown(tester);
  });

  testWidgets('a running timer keeps its urgency colour while in use', (
    tester,
  ) async {
    final session = TvActiveSession(
      serviceType: ServiceType.ps5,
      startTime: DateTime.now().subtract(const Duration(minutes: 5)),
      ps5StationIndices: const [0],
      plannedDurationMinutes: 60,
    );

    await _pumpBoard(
      tester,
      TvBoardController(
        _FakeTvRepository(layout: _layout, sessions: [session]),
      ),
    );

    // 5 of 60 minutes gone: plenty of time, so the live timer reads green
    // rather than being greyed out with the rest of the occupied tile.
    final remaining = tester.widget<Text>(find.textContaining('54m'));
    expect(remaining.style?.color, AppColors.live);

    await _teardown(tester);
  });

  testWidgets('an open-ended session shows no countdown', (tester) async {
    final session = TvActiveSession(
      serviceType: ServiceType.vr,
      startTime: DateTime.now().subtract(const Duration(minutes: 5)),
    );

    await _pumpBoard(
      tester,
      TvBoardController(
        _FakeTvRepository(layout: _layout, sessions: [session]),
      ),
    );

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('NO LIMIT'), findsOneWidget);
    expect(find.text('REMAINING'), findsNothing);

    await _teardown(tester);
  });
}
