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

  Future<void> init() async {
    await _refresh();
    _changesSub = _repository.watchSessionChanges().listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), _refresh);
    });
  }

  Future<void> _refresh() async {
    try {
      final results = await Future.wait([
        _repository.fetchActiveSessions(),
        _repository.fetchPs5Stations(),
      ]);
      sessions = results[0] as List<TvSession>;
      ps5Stations = results[1] as List<Ps5Station>;
      error = null;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
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
