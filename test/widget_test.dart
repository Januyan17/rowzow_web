import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rowzow_web/config/app_config.dart';
import 'package:rowzow_web/data/tv_repository.dart';
import 'package:rowzow_web/models/ps5_station.dart';
import 'package:rowzow_web/models/tv_session.dart';
import 'package:rowzow_web/pages/tv_board_page.dart';
import 'package:rowzow_web/state/tv_board_controller.dart';

/// Stands in for [TvRepository] so the test never touches the real Supabase
/// client or its realtime socket.
class _FakeTvRepository implements TvRepository {
  @override
  Future<List<TvSession>> fetchActiveSessions() async => const [];

  @override
  Future<List<Ps5Station>> fetchPs5Stations() async => const [];

  @override
  Stream<void> watchSessionChanges() => const Stream<void>.empty();
}

void main() {
  testWidgets('shows the header and an empty state when there are no sessions', (
    WidgetTester tester,
  ) async {
    final controller = TvBoardController(_FakeTvRepository());

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: TvBoardPage(controller: controller),
      ),
    );
    await tester.pump();

    expect(find.text(AppConfig.appName), findsOneWidget);
    expect(find.text('No active sessions'), findsOneWidget);

    // Dispose the widget tree so the header clock's Timer.periodic is
    // cancelled before the test ends (otherwise the binding flags it as a
    // pending timer).
    await tester.pumpWidget(const SizedBox());
  });
}
