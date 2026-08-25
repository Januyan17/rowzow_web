import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/tv_repository.dart';
import '../models/resource_layout.dart';
import '../models/service_type.dart';
import '../models/tv_active_session.dart';

class TvBoardController extends ChangeNotifier {
  TvBoardController(this._repository);

  final TvRepository _repository;

  /// Coalesces the burst of pings a single staff action can produce (a
  /// session row plus its service lines all change at once) into one
  /// refetch.
  static const _debounce = Duration(milliseconds: 300);

  List<TvActiveSession> sessions = const [];
  ResourceLayout layout = ResourceLayout.empty;
  bool loading = true;
  Object? error;

  StreamSubscription<void>? _changes;
  Timer? _debounceTimer;
  bool _refreshing = false;
  bool _disposed = false;

  /// Sessions that occupy a numbered PS5 station, keyed by station index.
  /// Built once per refresh so the grid does not rescan the list per tile.
  Map<int, TvActiveSession> _ps5ByStation = const {};
  Map<int, TvActiveSession> get ps5ByStation => _ps5ByStation;

  /// PS5 sessions we could not place on a station — either the RPC gave no
  /// indices, or an index falls outside the configured layout. Shown as
  /// their own tiles so a live session is never silently dropped.
  List<TvActiveSession> unplacedPs5 = const [];

  /// Everything that isn't a numbered PS5 station: VR, simulator, theatre.
  List<TvActiveSession> otherServices = const [];

  Future<void> init() async {
    await _refresh();
    // Push, not poll: a database trigger broadcasts on the `tv-board` topic
    // whenever a session changes, and we answer each ping by re-reading the
    // RPC. The ping carries no data, so nothing sensitive rides the public
    // channel. Countdowns tick locally in between, so the numbers stay
    // smooth without any network traffic at all.
    _changes = _repository.watchBoardChanges().listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounce, _refresh);
    });
  }

  Future<void> _refresh() async {
    if (_refreshing || _disposed) return;
    _refreshing = true;
    try {
      // Layout is near-static, so fetch it once and then only retry while
      // we still have nothing — a cold start that failed shouldn't leave
      // the board with no stations forever.
      if (layout.isEmpty) {
        try {
          layout = await _repository.fetchResourceLayout();
        } catch (_) {
          // Station labels are a display nicety; active sessions still
          // render without them.
        }
      }
      sessions = await _repository.fetchActiveSessions();
      _partition();
      error = null;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      _refreshing = false;
      if (!_disposed) notifyListeners();
    }
  }

  void _partition() {
    final byStation = <int, TvActiveSession>{};
    final unplaced = <TvActiveSession>[];
    final others = <TvActiveSession>[];
    final stationCount = layout.ps5Stations.length;

    for (final session in sessions) {
      if (session.serviceType != ServiceType.ps5) {
        others.add(session);
        continue;
      }
      final valid = session.ps5StationIndices
          .where((i) => i >= 0 && i < stationCount)
          .toList();
      if (valid.isEmpty) {
        unplaced.add(session);
        continue;
      }
      for (final index in valid) {
        byStation[index] = session;
      }
    }

    _ps5ByStation = byStation;
    unplacedPs5 = unplaced;
    otherServices = others;
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _changes?.cancel();
    super.dispose();
  }
}
