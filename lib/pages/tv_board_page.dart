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
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.background),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(sessionCount: _controller.sessions.length),
                const SizedBox(height: 18),
                const PopularGamesBanner(),
                const SizedBox(height: 22),
                Expanded(child: _buildBody()),
                const TermsFooter(),
              ],
            ),
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
        final columns = (constraints.maxWidth / 380).floor().clamp(1, 6);
        return GridView.builder(
          itemCount: _controller.sessions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 230,
            crossAxisSpacing: 22,
            mainAxisSpacing: 22,
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white38, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatefulWidget {
  const _Header({required this.sessionCount});

  final int sessionCount;

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

    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered logo + title, regardless of how wide the left/right
          // content below ends up being.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.ps5, AppColors.vr],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ps5.withValues(alpha: 0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sports_esports,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                AppConfig.appName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.live.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.live.withValues(alpha: 0.4),
                ),
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
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  date,
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
