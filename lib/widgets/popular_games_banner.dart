import 'dart:async';

import 'package:flutter/material.dart';

import '../models/popular_game.dart';
import '../theme/app_colors.dart';

/// Auto-advancing strip that cycles through featured games. Purely
/// decorative/ambient — does not affect data fetching or session state.
class PopularGamesBanner extends StatefulWidget {
  const PopularGamesBanner({super.key, this.games = popularGames});

  final List<PopularGame> games;

  @override
  State<PopularGamesBanner> createState() => _PopularGamesBannerState();
}

class _PopularGamesBannerState extends State<PopularGamesBanner> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    if (widget.games.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        setState(() => _index = (_index + 1) % widget.games.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.games.isEmpty) return const SizedBox.shrink();
    final game = widget.games[_index];

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.live.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'POPULAR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.live,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 450),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.4),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Row(
                key: ValueKey('${game.title}-$_index'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(game.icon, color: game.color, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    game.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          if (widget.games.length > 1)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(widget.games.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? game.color : Colors.white24,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}
