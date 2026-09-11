import 'package:flutter/material.dart';

import '../../widgets/gift_points_sheet.dart';

/// Full-page buy flow for live gift points (Dashboard + header menu).
class GiftPointsPage extends StatelessWidget {
  const GiftPointsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy gift points')),
      body: ListView(
        children: const [
          GiftPointsSheet(popOnSuccess: false),
        ],
      ),
    );
  }
}
