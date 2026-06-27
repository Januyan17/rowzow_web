import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'tv_session_line.dart';

class PopularGame {
  const PopularGame({required this.title, required this.icon, required this.serviceType});

  final String title;
  final IconData icon;
  final ServiceType serviceType;

  Color get color => AppColors.forServiceType(serviceType);
}

/// Catalog for the "Popular Games" banner.
const popularGames = <PopularGame>[
  PopularGame(title: 'A Way Out', icon: Icons.groups, serviceType: ServiceType.ps5),
  PopularGame(title: 'It Takes Two', icon: Icons.favorite, serviceType: ServiceType.ps5),
  PopularGame(title: 'Split Fiction', icon: Icons.call_split, serviceType: ServiceType.ps5),
  PopularGame(title: 'EA Sports FC 26', icon: Icons.sports_soccer, serviceType: ServiceType.ps5),
  PopularGame(title: 'Gran Turismo 7', icon: Icons.speed, serviceType: ServiceType.ps5),
  PopularGame(title: 'Tekken 8', icon: Icons.sports_mma, serviceType: ServiceType.ps5),
  PopularGame(
    title: 'Call of Duty: Black Ops 7',
    icon: Icons.gps_fixed,
    serviceType: ServiceType.ps5,
  ),
  PopularGame(title: "Marvel's Spider-Man 2", icon: Icons.web, serviceType: ServiceType.ps5),
  PopularGame(title: 'Grand Theft Auto V', icon: Icons.local_police, serviceType: ServiceType.ps5),
  PopularGame(title: 'God of War Ragnarök', icon: Icons.bolt, serviceType: ServiceType.ps5),
  PopularGame(
    title: "Ghost of Tsushima Director's Cut",
    icon: Icons.park,
    serviceType: ServiceType.ps5,
  ),
  PopularGame(title: 'Black Myth: Wukong', icon: Icons.auto_fix_high, serviceType: ServiceType.ps5),
  PopularGame(title: 'Astro Bot', icon: Icons.smart_toy, serviceType: ServiceType.ps5),
  PopularGame(title: 'Fortnite', icon: Icons.terrain, serviceType: ServiceType.ps5),
  PopularGame(title: 'Mortal Kombat 1', icon: Icons.whatshot, serviceType: ServiceType.ps5),
];
