import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/message.dart';
import '../../widgets/hubsom_image.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  List<ConversationPreview> _list = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await ref.read(messageRepositoryProvider).listConversations();
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
      ref.read(messagesTickProvider.notifier).state++;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(child: Text(_error!)),
                      ],
                    )
                  : _list.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 48),
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 56,
                              color: HubsomColors.forest.withValues(alpha: 0.45),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'When someone messages you — or you message a store — the conversation shows up here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: HubsomColors.ink.withValues(alpha: 0.65),
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () => context.push('/marketplace'),
                              child: const Text('Browse stores to message'),
                            ),
                          ],
                        )
                      : ListView.separated(
                          itemCount: _list.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final c = _list[i];
                            final initial =
                                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: HubsomColors.mint,
                                child: (c.avatar ?? '').isNotEmpty
                                    ? ClipOval(
                                        child: HubsomImage(
                                          url: c.avatar!,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Text(
                                        initial,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: HubsomColors.forest,
                                        ),
                                      ),
                              ),
                              title: Text(
                                c.name,
                                style: TextStyle(
                                  fontWeight: c.unreadCount > 0
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                c.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: c.unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _relative(c.updatedAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                  if (c.unreadCount > 0) ...[
                                    const SizedBox(height: 6),
                                    Badge(label: Text('${c.unreadCount}')),
                                  ],
                                ],
                              ),
                              onTap: () async {
                                await context.push('/messages/${c.userId}');
                                if (mounted) await _load();
                              },
                            );
                          },
                        ),
            ),
    );
  }
}
