import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/resource_layout.dart';
import '../models/tv_active_session.dart';

/// Reads the TV board's data from Supabase.
///
/// SAFETY: this board runs on a public screen with the **anon key only**.
/// The anon role has no grant on any table — a direct `.from('sessions')`
/// or `.from('resource_config')` read returns
/// `42501 permission denied for table`, by design. The two RPCs below are
/// the only sanctioned way in; each allow-lists exactly the columns this
/// screen needs. Customer names are shown here by explicit owner decision;
/// staff names, phone numbers, prices and payment amounts are not, and must
/// stay out of the RPC's column list.
///
/// Never reintroduce a table query here, never fetch a field the RPCs do
/// not return, and never use the service_role key — this page ships its
/// key to every browser that opens it.
class TvRepository {
  TvRepository(this._client);

  final SupabaseClient _client;

  /// Every service line currently in progress. An empty list is a normal
  /// "nothing running right now" state, not an error.
  Future<List<TvActiveSession>> fetchActiveSessions() async {
    final rows = await _client.rpc('tv_active_sessions') as List?;
    return (rows ?? const [])
        .whereType<Map>()
        .map((row) => TvActiveSession.fromJson(row.cast<String, dynamic>()))
        .toList();
  }

  /// The venue's station layout and capacity.
  ///
  /// `tv_resource_layout()` is a RETURNS TABLE function, so it always comes
  /// back as an array of 0 or 1 rows. No row means the layout has not been
  /// configured yet; the board renders that as "no stations" rather than
  /// failing.
  Future<ResourceLayout> fetchResourceLayout() async {
    final rows = await _client.rpc('tv_resource_layout') as List?;
    final layoutRows = (rows ?? const []).whereType<Map>().toList();
    if (layoutRows.isEmpty) return ResourceLayout.empty;
    return ResourceLayout.fromJson(layoutRows.first.cast<String, dynamic>());
  }

  /// Ticks whenever the staff app changes a session, so the board knows to
  /// refetch. Carries no row data itself.
  ///
  /// Deliberately Realtime **Broadcast**, not `postgres_changes`:
  /// postgres_changes evaluates RLS as the *subscribing* role, and anon has
  /// no SELECT grant on `sessions` / `session_service_lines`, so the
  /// subscription would join happily and then never deliver a row. Instead a
  /// database trigger broadcasts a contentless ping on the `tv-board` topic
  /// and the board answers it by re-calling the allow-listed RPC. Because
  /// the ping carries no session data, the public topic leaks nothing — keep
  /// it that way and never move real fields into the payload.
  Stream<void> watchBoardChanges() {
    final controller = StreamController<void>.broadcast();
    final channel = _client.channel(_boardTopic);

    channel
        .onBroadcast(
          event: _changeEvent,
          callback: (_) => controller.add(null),
        )
        .subscribe((status, error) {
          // A fresh subscribe — including an automatic reconnect after the
          // socket drops — may have missed pings while it was down, so treat
          // it as a change and resync.
          if (status == RealtimeSubscribeStatus.subscribed) {
            controller.add(null);
          }
          debugPrint(
            '[tv-board] $status${error != null ? ' — $error' : ''}',
          );
        });

    controller.onCancel = () => _client.removeChannel(channel);

    return controller.stream;
  }

  /// Topic and event the database trigger broadcasts on. Changing either
  /// means changing the SQL trigger to match.
  static const _boardTopic = 'tv-board';
  static const _changeEvent = 'change';
}
