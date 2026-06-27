import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../data/tv_repository.dart';
import '../state/tv_board_controller.dart';
import '../theme/app_colors.dart';
import '../widgets/live_pulse_dot.dart';
import '../widgets/popular_games_banner.dart';
import '../widgets/session_card.dart';
import '../widgets/terms_footer.dart';

class TvBoardPage extends StatefulWidget {
  const TvBoardPage({super.key, TvBoardController? controller}) : _controllerOverride = controller;

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
        widget._controllerOverride ?? TvBoardController(TvRepository(Supabase.instance.client));
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
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.background),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isMobile = width < 600;
              final isTablet = width >= 600 && width < 1024;
              final horizontalPadding = isMobile ? 14.0 : (isTablet ? 20.0 : 28.0);
              final topPadding = isMobile ? 14.0 : (isTablet ? 18.0 : 22.0);
              final bottomPadding = isMobile ? 16.0 : (isTablet ? 22.0 : 28.0);
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
                    _Header(sessionCount: _controller.sessions.length, compact: width < 700),
                    SizedBox(height: sectionGap),
                    const PopularGamesBanner(),
                    SizedBox(height: bodyGap),
                    Expanded(child: _buildBody()),
                    const TermsFooter(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading) {
      return const _StatusMessage(
        icon: Icons.sports_esports_outlined,
        title: 'Loading the board…',
        subtitle: 'Fetching live sessions from Rowzow',
        showSpinner: true,
      );
    }
    if (_controller.error != null) {
      return const _StatusMessage(
        icon: Icons.wifi_off_rounded,
        title: 'Unable to load live sessions',
        subtitle: 'Reconnecting automatically…',
        iconColor: AppColors.overtime,
      );
    }
    if (_controller.sessions.isEmpty) {
      return const _StatusMessage(
        icon: Icons.movie_filter_outlined,
        title: 'No active sessions',
        subtitle: 'New sessions will appear here automatically',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final columns = (constraints.maxWidth / 380).floor().clamp(1, 6);
        final spacing = isMobile ? 14.0 : 22.0;
        return GridView.builder(
          itemCount: _controller.sessions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: isMobile ? 250 : 230,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemBuilder: (context, index) => SessionCard(
            session: _controller.sessions[index],
            ps5Stations: _controller.ps5Stations,
          ),
        );
      },
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = Colors.white38,
    this.showSpinner = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final bool showSpinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.08),
            ),
            child: showSpinner
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(color: AppColors.ps5, strokeWidth: 3),
                  )
                : Icon(icon, size: 40, color: iconColor),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 15)),
        ],
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
    final time =
        '${_now.hour.toString().padLeft(2, '0')}:'
        '${_now.minute.toString().padLeft(2, '0')}:'
        '${_now.second.toString().padLeft(2, '0')}';
    final date =
        '${_now.year}-${_now.month.toString().padLeft(2, '0')}-'
        '${_now.day.toString().padLeft(2, '0')}';

    final logo = Container(
      padding: EdgeInsets.all(widget.compact ? 8 : 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.ps5, AppColors.vr]),
        borderRadius: BorderRadius.circular(widget.compact ? 12 : 14),
        boxShadow: [BoxShadow(color: AppColors.ps5.withValues(alpha: 0.4), blurRadius: 16)],
      ),
      child: Icon(Icons.sports_esports, color: Colors.white, size: widget.compact ? 20 : 26),
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
          SizedBox(width: widget.compact ? 10 : 14),
          Text(
            AppConfig.appName,
            style: TextStyle(
              fontSize: widget.compact ? 22 : 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    final liveBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.live.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.live.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LivePulseDot(),
          const SizedBox(width: 8),
          Text(
            '${widget.sessionCount} active',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.live,
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
            fontSize: widget.compact ? 20 : 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(date, style: const TextStyle(fontSize: 12, color: Colors.white38)),
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
            Align(alignment: Alignment.centerLeft, child: liveBadge),
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
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [liveBadge, timeBlock]),
      ],
    );
  }
}
