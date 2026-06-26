import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../data/tv_repository.dart';
import '../state/tv_board_controller.dart';
import '../widgets/session_card.dart';

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
      backgroundColor: const Color(0xFF0E0E11),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(sessionCount: _controller.sessions.length),
              const SizedBox(height: 24),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_controller.loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }
    if (_controller.error != null) {
      return const Center(
        child: Text(
          'Unable to load live sessions.',
          style: TextStyle(color: Colors.white70, fontSize: 20),
        ),
      );
    }
    if (_controller.sessions.isEmpty) {
      return const Center(
        child: Text(
          'No active sessions',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 28,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 360).floor().clamp(1, 6);
        return GridView.builder(
          itemCount: _controller.sessions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 220,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
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
    return Row(
      children: [
        Text(
          AppConfig.appName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 16),
        Text(
          '${widget.sessionCount} active',
          style: const TextStyle(fontSize: 16, color: Colors.white54),
        ),
        const Spacer(),
        Text(
          time,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
