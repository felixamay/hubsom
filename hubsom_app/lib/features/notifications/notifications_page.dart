import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/services/local_notification_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/app_notification.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  List<HubsomNotification> _list = const [];

  @override
  void initState() {
    super.initState();
    _list = _forSession();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  List<HubsomNotification> _forSession() {
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null) return const [];
    return LocalNotificationStore.forUser(user.id);
  }

  Future<void> _refresh() async {
    await LocalNotificationStore.mergeCloud();
    if (!mounted) return;
    setState(() => _list = _forSession());
    ref.read(notificationsTickProvider.notifier).state++;
  }

  String _relative(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }

  Future<void> _open(HubsomNotification note) async {
    await LocalNotificationStore.markRead(note.id);
    if (!mounted) return;
    setState(() => _list = _forSession());
    ref.read(notificationsTickProvider.notifier).state++;
    final route = note.route;
    if (route != null && route.startsWith('/')) {
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _list.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 48),
                  Icon(
                    Icons.notifications_outlined,
                    size: 56,
                    color: HubsomColors.forest.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'When a store you follow goes live, the alert shows up here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: HubsomColors.ink.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                itemCount: _list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final n = _list[i];
                  return ListTile(
                    onTap: () => _open(n),
                    leading: CircleAvatar(
                      backgroundColor: HubsomColors.mint,
                      child: Icon(
                        n.isLiveAlert
                            ? Icons.videocam
                            : Icons.notifications_outlined,
                        color: HubsomColors.forest,
                      ),
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(n.body),
                    trailing: Text(
                      _relative(n.createdAt),
                      style: TextStyle(
                        color: HubsomColors.ink.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
