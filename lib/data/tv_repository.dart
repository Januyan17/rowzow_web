import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ps5_station.dart';
import '../models/tv_session.dart';

/// Reads the TV board's data from Supabase.
///
/// SAFETY: active sessions are read through the `tv_active_sessions()`
/// Postgres RPC, which allow-lists exactly the metadata keys this board
/// needs. Never change this back to a raw `.from('sessions').select(...)`
/// — there is no RLS on these tables, and `session_service_lines.metadata`
/// contains price fields (e.g. `planned_price`) that must never reach the
/// public lounge TV. The allow-list lives in the SQL function itself, not
/// in this file.
class TvRepository {
  TvRepository(this._client);

  final SupabaseClient _client;

  Future<List<TvSession>> fetchActiveSessions() async {
    final rows = await _client.rpc('tv_active_sessions') as List;
    return rows
        .map((row) => TvSession.fromJson((row as Map).cast<String, dynamic>()))
        .toList();
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
