import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ps5_station.dart';
import '../models/tv_session.dart';

/// Reads the TV board's data from Supabase.
///
/// SAFETY: every select below is an explicit, exhaustive column list.
/// Never change these to `select('*')` and never add any amount/price/
/// payment/phone column — there is no RLS on these tables, so this
/// allow-list is the only thing keeping financial/contact data off the
/// public lounge TV.
class TvRepository {
  TvRepository(this._client);

  final SupabaseClient _client;

  static const _activeSessionsSelect = '''
      id,
      start_time,
      end_time,
      status,
      customers ( name ),
      session_service_lines (
        id,
        service_type,
        start_time,
        end_time,
        quantity,
        metadata
      )
  ''';

  Future<List<TvSession>> fetchActiveSessions() async {
    final rows = await _client
        .from('sessions')
        .select(_activeSessionsSelect)
        .eq('status', 'active');
    return rows.map(TvSession.fromJson).toList();
  }

  Future<List<Ps5Station>> fetchPs5Stations() async {
    final row = await _client
        .from('resource_config')
        .select('ps5_stations')
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final stations = (row?['ps5_stations'] as List?) ?? const [];
    return stations
        .map((e) => Ps5Station.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Emits a tick whenever `sessions` or `session_service_lines` changes,
  /// so the board knows to refetch. Does not push row data itself.
  Stream<void> watchSessionChanges() {
    final controller = StreamController<void>.broadcast();
    final channel = _client.channel('tv-board-changes');

    void emit(PostgresChangePayload _) => controller.add(null);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sessions',
          callback: emit,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'session_service_lines',
          callback: emit,
        )
        .subscribe((status, error) {
          debugPrint('[tv-board-changes] $status${error != null ? ' — $error' : ''}');
        });

    controller.onCancel = () => _client.removeChannel(channel);

    return controller.stream;
  }
}
