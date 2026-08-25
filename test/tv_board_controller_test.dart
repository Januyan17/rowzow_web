import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rowzow_web/data/tv_repository.dart';
import 'package:rowzow_web/models/resource_layout.dart';
import 'package:rowzow_web/models/service_type.dart';
import 'package:rowzow_web/models/tv_active_session.dart';
import 'package:rowzow_web/state/tv_board_controller.dart';

/// Returns a different batch of sessions on each call, so a test can tell
/// whether the controller actually refetched.
class _SequenceRepository implements TvRepository {
  _SequenceRepository(this._batches, this._changes);

  final List<List<TvActiveSession>> _batches;
  final Stream<void> _changes;
  int calls = 0;

  @override
  Future<List<TvActiveSession>> fetchActiveSessions() async {
    final batch = _batches[calls < _batches.length ? calls : _batches.length - 1];
    calls++;
    return batch;
  }

  @override
  Future<ResourceLayout> fetchResourceLayout() async => const ResourceLayout(
    ps5Stations: [],
    vrUnits: 1,
  );

  @override
  Stream<void> watchBoardChanges() => _changes;
}

TvActiveSession _session() => TvActiveSession(
  serviceType: ServiceType.vr,
  startTime: DateTime.now(),
);

void main() {
  test('a broadcast ping triggers a refetch', () async {
    final changes = StreamController<void>.broadcast();
    final repo = _SequenceRepository([
      const <TvActiveSession>[],
      [_session()],
    ], changes.stream);
    final controller = TvBoardController(repo);

    await controller.init();
    expect(controller.sessions, isEmpty);

    changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(controller.sessions, hasLength(1));
    controller.dispose();
    await changes.close();
  });

  test('a burst of pings collapses into a single refetch', () async {
    final changes = StreamController<void>.broadcast();
    final repo = _SequenceRepository([const <TvActiveSession>[]], changes.stream);
    final controller = TvBoardController(repo);

    await controller.init();
    expect(repo.calls, 1);

    // One staff action can touch a session and several service lines at
    // once; the board should answer that with one refetch, not four.
    for (var i = 0; i < 4; i++) {
      changes.add(null);
    }
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(repo.calls, 2);
    controller.dispose();
    await changes.close();
  });

  test('no refetch happens after dispose', () async {
    final changes = StreamController<void>.broadcast();
    final repo = _SequenceRepository([const <TvActiveSession>[]], changes.stream);
    final controller = TvBoardController(repo);

    await controller.init();
    controller.dispose();

    changes.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    expect(repo.calls, 1);
    await changes.close();
  });
}
