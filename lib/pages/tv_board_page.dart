import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../data/tv_repository.dart';
import '../models/service_type.dart';
import '../state/tv_board_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/book_now_button.dart';
import '../widgets/gaming_backdrop.dart';
import '../widgets/live_pulse_dot.dart';
import '../widgets/glass_panel.dart';
import '../widgets/second_ticker.dart';
import '../widgets/squad_battle.dart';
import '../widgets/station_tile.dart';
import '../widgets/terms_footer.dart';
import '../widgets/upcoming_game_countdown.dart';

class TvBoardPage extends StatefulWidget {
  const TvBoardPage({super.key, TvBoardController? controller})
    : _controllerOverride = controller;

  /// Lets tests inject a fake controller instead of hitting the real
  /// Supabase client/realtime socket.
  final TvBoardController? _controllerOverride;

  @override
  State<TvBoardPage> createState() => _TvBoardPageState();
}

class _TvBoardPageState extends State<TvBoardPage> {
  late final TvBoardController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        widget._controllerOverride ??
        TvBoardController(TvRepository(Supabase.instance.client));
    _controller.addListener(_onUpdate);
    _controller.init();
  }

  void _onUpdate() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBase,
      body: Stack(
        children: [
          const Positioned.fill(child: GamingBackdrop()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isMobile = width < 600;
                final arenaFixed = width >= 900 && constraints.maxHeight >= 760;
                final isTablet = width >= 600 && width < 1024;
                final horizontalPadding = isMobile
                    ? 14.0
                    : (isTablet ? 20.0 : 28.0);
                final topPadding = isMobile ? 14.0 : (isTablet ? 18.0 : 22.0);
                final bottomPadding = isMobile
                    ? 16.0
                    : (isTablet ? 22.0 : 28.0);
                final sectionGap = isMobile ? 12.0 : (isTablet ? 16.0 : 18.0);
                final bodyGap = isMobile ? 14.0 : (isTablet ? 18.0 : 22.0);
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    topPadding,
                    horizontalPadding,
                    bottomPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(
                        sessionCount: _controller.sessions.length,
                        compact: width < 900,
                      ),
                      SizedBox(height: sectionGap),
                      UpcomingGameCountdown(),
                      SizedBox(height: bodyGap),
                      Expanded(child: _buildBody(arenaInList: !arenaFixed)),
                      // Big screens with height to spare keep the squad
                      // battle pinned above the footer; everything else
                      // gets it at the end of the scrolling board instead,
                      // so it never squeezes the stations.
                      if (arenaFixed) ...[
                        const SizedBox(height: 14),
                        const SquadBattle(),
                      ],
                      const TermsFooter(),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({required bool arenaInList}) {
    if (_controller.loading) {
      return const _StatusMessage(
        icon: Icons.sports_esports_outlined,
        title: 'Loading the board…',
        subtitle: 'Fetching live sessions from Rowzow',
        showSpinner: true,
      );
    }
    if (_controller.error != null) {
      return _pullToRefresh(
        const _ScrollableFill(
          child: _StatusMessage(
            icon: Icons.wifi_off_rounded,
            title: 'Unable to load live sessions',
            subtitle: 'Reconnecting automatically…',
            iconColor: AppColors.overtime,
          ),
        ),
      );
    }
    // No sessions is a normal "everything is free" state, not an empty
    // state — the grid below still draws every configured station. The
    // only genuinely empty case is a venue with no layout configured yet.
    if (_controller.layout.isEmpty && _controller.sessions.isEmpty) {
      return _pullToRefresh(
        const _ScrollableFill(
          child: _StatusMessage(
            icon: Icons.movie_filter_outlined,
            title: 'No stations configured',
            subtitle: 'Stations will appear here once the layout is set up',
          ),
        ),
      );
    }
    return _pullToRefresh(
      SecondTicker(
        builder: (context, now) => _StationBoard(
          controller: _controller,
          now: now,
          showArena: arenaInList,
        ),
      ),
    );
  }

  /// Pull down on the board to re-read sessions now instead of waiting for
  /// the next realtime ping. Touch-driven, so in practice a phone/tablet
  /// gesture; a TV or desktop mouse never triggers it.
  Widget _pullToRefresh(Widget child) => RefreshIndicator(
    onRefresh: _controller.refresh,
    color: AppColors.auroraCyan,
    backgroundColor: AppColors.cardBackground,
    child: child,
  );
}

/// Makes a non-scrolling message pullable: fills the available height
/// inside an always-scrollable view so [RefreshIndicator] has something to
/// drag.
class _ScrollableFill extends StatelessWidget {
  const _ScrollableFill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: constraints.maxHeight, child: child),
      ),
    );
  }
}

/// The board proper: every configured station, busy or free, plus any
/// active session that does not map onto a numbered station.
class _StationBoard extends StatelessWidget {
  const _StationBoard({
    required this.controller,
    required this.now,
    required this.showArena,
  });

  final TvBoardController controller;
  final DateTime now;

  /// Append the squad battle after the last section (small screens).
  final bool showArena;

  @override
  Widget build(BuildContext context) {
    final layout = controller.layout;
    final others = controller.otherServices;

    final vrSessions = others
        .where((s) => s.serviceType == ServiceType.vr)
        .toList();
    final simSessions = others
        .where((s) => s.serviceType == ServiceType.simulator)
        .toList();
    final theatreSessions = others
        .where((s) => s.serviceType == ServiceType.theatre)
        .toList();

    final ps5Tiles = <Widget>[
      for (var i = 0; i < layout.ps5Stations.length; i++)
        Ps5StationTile(
          station: layout.ps5Stations[i],
          session: controller.ps5ByStation[i],
          now: now,
        ),
      // A PS5 session the layout can't place still has to show up.
      for (final session in controller.unplacedPs5)
        ServiceSessionTile(session: session, now: now),
    ];

    final otherTiles = <Widget>[
      for (final session in vrSessions)
        ServiceSessionTile(session: session, now: now, title: 'VR'),
      for (var i = 0; i < _free(layout.vrUnits, vrSessions.length); i++)
        const FreeServiceTile(type: ServiceType.vr, title: 'VR'),
      for (final session in simSessions)
        ServiceSessionTile(session: session, now: now, title: 'Simulator'),
      for (var i = 0; i < _free(layout.simulatorUnits, simSessions.length); i++)
        const FreeServiceTile(type: ServiceType.simulator, title: 'Simulator'),
      // The theatre is a single room, so it gets exactly one tile: the
      // running session while it is in use, a plain free tile when it is
      // not. Seat counts and headcount are deliberately not shown.
      for (final session in theatreSessions)
        ServiceSessionTile(session: session, now: now, title: 'Theatre'),
      if (theatreSessions.isEmpty && layout.theatreSeats > 0)
        const FreeServiceTile(type: ServiceType.theatre, title: 'Theatre'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final columns = (constraints.maxWidth / 380).floor().clamp(1, 6);
        final spacing = isMobile ? 14.0 : 22.0;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        Widget grid(List<Widget> tiles) => Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );

        return SingleChildScrollView(
          // Scrollable even when every tile fits, so pull-to-refresh
          // still works on a short board.
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (ps5Tiles.isNotEmpty) ...[
                const _SectionLabel(
                  'PS5 Stations',
                  icon: Icons.sports_esports,
                  color: AppColors.ps5,
                ),
                const SizedBox(height: 10),
                grid(ps5Tiles),
              ],
              if (ps5Tiles.isNotEmpty && otherTiles.isNotEmpty)
                SizedBox(height: spacing),
              if (otherTiles.isNotEmpty) ...[
                const _SectionLabel(
                  'VR · Simulator · Theatre',
                  icon: Icons.vrpano,
                  color: AppColors.vr,
                ),
                const SizedBox(height: 10),
                grid(otherTiles),
              ],
              if (showArena) ...[
                SizedBox(height: spacing),
                SquadBattle(height: isMobile ? 96 : 110),
              ],
            ],
          ),
        );
      },
    );
  }

  static int _free(int total, int busy) {
    final free = total - busy;
    return free < 0 ? 0 : free;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.icon, required this.color});

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: ShapeDecoration(
              color: color.withValues(alpha: 0.15),
              shape: panelShape(
                9,
                side: BorderSide(color: color.withValues(alpha: 0.6)),
              ),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          // Long labels ("VR · Simulator · Theatre") shrink on phones instead
          // of pushing the row off screen.
          ConstrainedBox(
            // Icon chip, gap and a stub of the trailing rule.
            constraints: BoxConstraints(maxWidth: constraints.maxWidth - 70),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                text.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.6),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = AppColors.auroraCyan,
    this.showSpinner = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    // Scales down rather than overflowing when the banners above leave
    // little room (small windows, phones in landscape).
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: ShapeDecoration(
                color: iconColor.withValues(alpha: 0.08),
                shape: panelShape(
                  16,
                  side: BorderSide(color: iconColor.withValues(alpha: 0.4)),
                ),
                shadows: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.2),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: showSpinner
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: AppColors.ps5,
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(icon, size: 40, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                shadows: softGlow(iconColor, strength: 0.5),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatefulWidget {
  const _Header({required this.sessionCount, this.compact = false});

  final int sessionCount;
  final bool compact;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hour12 = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final period = _now.hour < 12 ? 'AM' : 'PM';
    final time =
        '$hour12:'
        '${_now.minute.toString().padLeft(2, '0')}:'
        '${_now.second.toString().padLeft(2, '0')} $period';
    final date =
        '${_now.year}-${_now.month.toString().padLeft(2, '0')}-'
        '${_now.day.toString().padLeft(2, '0')}';

    final logo = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.auroraCyan.withValues(alpha: 0.30),
            blurRadius: 24,
          ),
        ],
      ),
      child: Image.asset(
        'assets/logo.png',
        height: widget.compact ? 44 : 54,
        fit: BoxFit.contain,
      ),
    );

    // FittedBox scales the whole logo+title down to fit the available
    // width instead of ellipsis-truncating long app names (e.g. the prod
    // "Rowzow Gaming Center" name on small phones).
    final titleRow = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logo,
          SizedBox(width: widget.compact ? 4 : 6),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Colors.white,
                AppColors.auroraCyan,
                AppColors.auroraViolet,
              ],
              stops: [0.2, 0.65, 1],
            ).createShader(bounds),
            child: Text(
              AppConfig.appName,
              style: TextStyle(
                fontSize: widget.compact ? 22 : 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.4,
                shadows: softGlow(AppColors.auroraCyan, strength: 0.6),
              ),
            ),
          ),
        ],
      ),
    );

    final liveBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: ShapeDecoration(
        color: AppColors.live.withValues(alpha: 0.12),
        shape: panelShape(
          24,
          side: BorderSide(color: AppColors.live.withValues(alpha: 0.55)),
        ),
        shadows: [
          BoxShadow(
            color: AppColors.live.withValues(alpha: 0.2),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LivePulseDot(),
          const SizedBox(width: 8),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              color: AppColors.live,
            ),
          ),
          Container(
            width: 1,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: AppColors.live.withValues(alpha: 0.4),
          ),
          Text(
            '${widget.sessionCount} active',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );

    final timeBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          time,
          style: TextStyle(
            fontSize: widget.compact ? 17 : 26,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 1,
            fontFeatures: const [FontFeature.tabularFigures()],
            shadows: softGlow(AppColors.auroraCyan),
          ),
        ),
        Text(
          date,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: AppColors.auroraCyan.withValues(alpha: 0.6),
          ),
        ),
      ],
    );

    if (!widget.compact) {
      return SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Centered logo + title, regardless of how wide the left/right
            // content below ends up being.
            titleRow,
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  liveBadge,
                  const SizedBox(width: 12),
                  const BookNowButton(),
                ],
              ),
            ),
            Align(alignment: Alignment.centerRight, child: timeBlock),
          ],
        ),
      );
    }

    // Small screens: the centered/edge-aligned stack overlaps once the
    // title, badge, and time block can't all fit on one row, so stack
    // them vertically instead.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        titleRow,
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            liveBadge,
            const SizedBox(width: 12),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: timeBlock,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const BookNowButton(expand: true),
      ],
    );
  }
}
