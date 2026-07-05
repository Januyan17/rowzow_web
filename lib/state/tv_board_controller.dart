import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/tv_repository.dart';
import '../models/ps5_station.dart';
import '../models/tv_session.dart';

class TvBoardController extends ChangeNotifier {
  TvBoardController(this._repository);

  final TvRepository _repository;

  List<TvSession> sessions = [];
  List<Ps5Station> ps5Stations = [];
  bool loading = true;
  Object? error;

  StreamSubscription<void>? _changesSub;
  Timer? _debounce;
  bool _refreshing = false;

  Future<void> init() async {
    // Station labels are static config (not session data) — fetch once
    // up front rather than on every session refresh.
    await Future.wait([_loadPs5Stations(), _refreshSessions()]);
    _changesSub = _repository.watchSessionChanges().listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), _refreshSessions);
    });
  }

  Future<void> _loadPs5Stations() async {
    try {
      ps5Stations = await _repository.fetchPs5Stations();
    } catch (_) {
      // Station labels are a display nicety; a failure here shouldn't
      // block the board from showing live session data.
    }
  }

  Future<void> _refreshSessions() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      sessions = await _repository.fetchActiveSessions();
      error = null;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      _refreshing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _changesSub?.cancel();
    super.dispose();
  }
}
