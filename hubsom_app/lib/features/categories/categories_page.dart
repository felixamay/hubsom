import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/hubsom_colors.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Text('Categories', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Shop every Hubsom category — same catalog as web.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        ...hubsomCategories.map((c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: HubsomColors.mint,
                foregroundColor: HubsomColors.forest,
                child: Text(c.name.characters.first),
              ),
              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(c.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/categories/${c.slug}'),
            )),
      ],
    );
  }
}
