import 'package:flutter/material.dart';

import '../models/ps5_station.dart';
import '../models/service_type.dart';
import '../models/tv_active_session.dart';
import '../theme/app_colors.dart';
import 'countdown_text.dart';
import 'live_pulse_dot.dart';
import 'glass_panel.dart';

/// Shared shell for every tile on the board.
///
/// The board is read by walk-in customers looking for somewhere to play, so
/// emphasis runs the opposite way to a staff dashboard. A **free** station
/// is left plain and clean — no glow, no tinted surface — and the contrast
/// comes from occupied tiles receding into a flatter, dimmer card instead.
/// The one thing that stays bright on an occupied tile is who is on it.
class _TileShell extends StatelessWidget {
  const _TileShell({
    required this.accent,
    required this.child,
    required this.free,
    required this.type,
    this.overtime = false,
  });

  final Color accent;
  final Widget child;
  final bool free;
  final ServiceType type;

  /// Ran past its planned end. Overrides the receded treatment entirely —
  /// this is the one state on the board that is meant to grab attention.
  final bool overtime;

  static const _radius = 22.0;

  @override
  Widget build(BuildContext context) {
    final edge = overtime
        ? AppColors.overtime
        : (free ? AppColors.available : accent.withValues(alpha: 0.40));
    final surface = overtime
        ? AppColors.overtimeSurface
        : (free ? AppColors.cardBackground : AppColors.occupiedSurface);
    final border = overtime
        ? AppColors.overtime.withValues(alpha: 0.6)
        : (free
              ? Color.lerp(Colors.white, accent, 0.5)!.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.06));
    final shape = panelShape(
      _radius,
      side: BorderSide(color: border, width: overtime ? 1.5 : 1),
    );

    final tile = Container(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: free ? 0.12 : 0.04),
              surface.withValues(alpha: free ? 0.80 : 0.85),
            ),
            surface.withValues(alpha: free ? 0.62 : 0.80),
          ],
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: panelShape(_radius)),
        child: Stack(
          children: [
            // Soft light pooling in the top corner, tinted by the activity.
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accent.withValues(alpha: free ? 0.16 : 0.06),
                      accent.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            // Oversized activity icon fading off the corner — reads as key
            // art without needing a picture per station.
            Positioned(
              right: -14,
              bottom: -22,
              child: Icon(
                AppColors.iconForServiceType(type),
                size: 120,
                color: Colors.white.withValues(alpha: free ? 0.045 : 0.025),
              ),
            ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Slim status rail, inset and rounded rather than a hard
                  // edge stripe.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 18, 0, 18),
                    child: Container(
                      width: overtime ? 4 : 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [edge, edge.withValues(alpha: 0.15)],
                        ),
                        boxShadow: [
                          if (free || overtime)
                            BoxShadow(color: edge.withValues(alpha: 0.6), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 18, 18, 18),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return overtime ? _OvertimeHalo(child: tile) : tile;
  }
}

/// Breathing red halo around a tile that has run over.
///
/// Motion is the only channel left once colour is already in use across the
/// board, and an overrun is the one thing staff have to notice without
/// being at the screen. Only ever wraps overtime tiles, so at most a couple
/// animate at once.
class _OvertimeHalo extends StatefulWidget {
  const _OvertimeHalo({required this.child});

  final Widget child;

  @override
  State<_OvertimeHalo> createState() => _OvertimeHaloState();
}

class _OvertimeHaloState extends State<_OvertimeHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return DecoratedBox(
          decoration: ShapeDecoration(
            shape: panelShape(_TileShell._radius),
            shadows: [
              BoxShadow(
                color: AppColors.overtime.withValues(alpha: 0.14 + (t * 0.26)),
                blurRadius: 14 + (t * 22),
                spreadRadius: t * 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// One numbered PS5 station, rendered whether or not anyone is on it.
/// [session] is null for a free station.
class Ps5StationTile extends StatelessWidget {
  const Ps5StationTile({
    super.key,
    required this.station,
    required this.now,
    this.session,
  });

  final Ps5Station station;
  final DateTime now;
  final TvActiveSession? session;

  @override
  Widget build(BuildContext context) {
    final active = session;
    final free = active == null;
    final accent = AppColors.forServiceType(ServiceType.ps5);
    final controllers = station.maxControllers;
    // A paused session is frozen, so it cannot be accruing overtime — never
    // flash a halo at a clock that isn't moving.
    final overtime =
        active != null && !active.isPaused && active.isOvertimeAt(now);

    return _TileShell(
      accent: accent,
      type: ServiceType.ps5,
      free: free,
      overtime: overtime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TileHeader(
            type: ServiceType.ps5,
            title: station.label.isEmpty ? 'PS5' : station.label,
            subtitle: active?.customerName,
            free: free,
            status: free
                ? const StatusPill.free()
                : StatusPill.busy(paused: active.isPaused),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (controllers != null)
                InfoChip(
                  icon: Icons.sports_esports_outlined,
                  label:
                      '$controllers controller${controllers == 1 ? '' : 's'}',
                ),
              if (active != null)
                InfoChip(
                  icon: Icons.schedule_outlined,
                  label: 'Started ${formatClock(active.startTime)}',
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (free)
            const AvailableFootnote()
          else
            CountdownText(session: active, now: now, dimmed: true),
        ],
      ),
    );
  }
}

/// An active VR / simulator / theatre session, or a PS5 session whose
/// station index the layout does not cover.
class ServiceSessionTile extends StatelessWidget {
  const ServiceSessionTile({
    super.key,
    required this.session,
    required this.now,
    this.title,
  });

  final TvActiveSession session;
  final DateTime now;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.forServiceType(session.serviceType);
    final units = session.ps5Units;

    return _TileShell(
      accent: accent,
      type: session.serviceType,
      free: false,
      overtime: !session.isPaused && session.isOvertimeAt(now),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TileHeader(
            type: session.serviceType,
            title: title ?? _defaultTitle(session.serviceType),
            subtitle: session.customerName,
            free: false,
            status: StatusPill.busy(paused: session.isPaused),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (session.serviceType == ServiceType.ps5 && units > 0)
                InfoChip(
                  icon: Icons.tv,
                  label: '$units console${units == 1 ? '' : 's'}',
                ),
              InfoChip(
                icon: Icons.schedule_outlined,
                label: 'Started ${formatClock(session.startTime)}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          CountdownText(session: session, now: now, dimmed: true),
        ],
      ),
    );
  }

  static String _defaultTitle(ServiceType type) => switch (type) {
    ServiceType.ps5 => 'PS5',
    ServiceType.vr => 'VR',
    ServiceType.simulator => 'Simulator',
    ServiceType.theatre => 'Theatre',
  };
}

/// Spare VR / simulator capacity, so the board shows a complete picture of
/// the venue rather than only what happens to be busy.
class FreeServiceTile extends StatelessWidget {
  const FreeServiceTile({super.key, required this.type, required this.title});

  final ServiceType type;
  final String title;

  @override
  Widget build(BuildContext context) {
    return _TileShell(
      accent: AppColors.forServiceType(type),
      type: type,
      free: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _TileHeader(
            type: type,
            title: title,
            free: true,
            status: const StatusPill.free(),
          ),
          const SizedBox(height: 12),
          const AvailableFootnote(),
        ],
      ),
    );
  }
}

class _TileHeader extends StatelessWidget {
  const _TileHeader({
    required this.type,
    required this.title,
    required this.status,
    required this.free,
    this.subtitle,
  });

  final ServiceType type;
  final String title;
  final Widget status;
  final bool free;

  /// Who is on the station. Absent for a free station, and for a session
  /// with no name recorded.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forServiceType(type);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The badge keeps full activity colour even on a dimmed tile: it is
        // what tells you PS5 from VR from Theatre across the room.
        ServiceBadge(type: type),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: free ? Colors.white : Colors.white70,
                  letterSpacing: 0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                // The one thing that stays bright on an occupied tile, and
                // printed in the activity's own colour.
                Row(
                  children: [
                    Icon(Icons.person_rounded, size: 17, color: color),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.1,
                          shadows: softGlow(color, strength: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        status,
      ],
    );
  }
}

/// The payoff line on a free tile — deliberately the brightest text in the
/// card.
class AvailableFootnote extends StatelessWidget {
  const AvailableFootnote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.available.withValues(alpha: 0.12),
            AppColors.available.withValues(alpha: 0.02),
          ],
        ),
        shape: panelShape(
          12,
          side: BorderSide(color: AppColors.available.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 17,
            color: AppColors.available,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Available now',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.available,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                shadows: softGlow(AppColors.available, strength: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill.free({super.key})
    : _label = 'FREE',
      _color = AppColors.available,
      _loud = true,
      _pulse = true;
  const StatusPill.busy({super.key, bool paused = false})
    : _label = paused ? 'PAUSED' : 'IN USE',
      // Paused is an anomaly staff need to spot, so it keeps its colour even
      // on a receded tile. A plain in-use pill does not.
      _color = paused ? AppColors.theatre : Colors.white30,
      _loud = paused,
      _pulse = false;

  final String _label;
  final Color _color;
  final bool _loud;
  final bool _pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: ShapeDecoration(
        color: _color.withValues(alpha: _loud ? 0.14 : 0.07),
        shape: panelShape(
          20,
          side: BorderSide(color: _color.withValues(alpha: _loud ? 0.4 : 0.15)),
        ),
        shadows: [
          if (_loud) BoxShadow(color: _color.withValues(alpha: 0.15), blurRadius: 12),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pulse) ...[
            LivePulseDot(color: _color, size: 7),
            const SizedBox(width: 6),
          ],
          Text(
            _label,
            style: TextStyle(
              color: _loud ? _color : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceBadge extends StatelessWidget {
  const ServiceBadge({super.key, required this.type});

  final ServiceType type;

  @override
  Widget build(BuildContext context) {
    final icon = AppColors.iconForServiceType(type);
    final color = AppColors.forServiceType(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.30),
            color.withValues(alpha: 0.12),
          ],
        ),
        shape: panelShape(
          12,
          side: BorderSide(color: color.withValues(alpha: 0.45)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Color.lerp(color, Colors.white, 0.35)),
          const SizedBox(width: 5),
          Text(
            type.shortLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color.lerp(color, Colors.white, 0.55),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.bright = false,
  });

  final IconData icon;
  final String label;
  final bool bright;

  @override
  Widget build(BuildContext context) {
    final color = bright ? AppColors.available : Colors.white60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: ShapeDecoration(
        color: bright
            ? AppColors.available.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.05),
        shape: panelShape(
          10,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              color: bright ? AppColors.available : Colors.white54,
              fontWeight: bright ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

String formatClock(DateTime time) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}
