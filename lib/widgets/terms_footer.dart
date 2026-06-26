import 'package:flutter/material.dart';

import '../config/app_config.dart';

// TODO: swap with Rowzow's real terms & conditions copy once provided.
const _placeholderTerms =
    'Management reserves the right to manage session time, station '
    'allocation, and to refuse service. Please handle all equipment with '
    'care and report any issues to staff immediately. Decisions on '
    'disputes by management are final.';

class TermsFooter extends StatelessWidget {
  const TermsFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        '${AppConfig.appName} · Terms & Conditions: $_placeholderTerms',
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11.5,
          color: Colors.white38,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
