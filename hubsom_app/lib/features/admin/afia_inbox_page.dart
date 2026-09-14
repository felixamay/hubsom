import 'package:flutter/material.dart';

import '../../core/services/local_message_store.dart';
import '../../core/support/support_chat.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/message.dart';

/// Inbox for Contact us threads. Replies are sent as Hubsom Support.
class AfiaInboxPage extends StatefulWidget {
  const AfiaInboxPage({super.key});

  @override
  State<AfiaInboxPage> createState() => _AfiaInboxPageState();
}

class _AfiaInboxPageState extends State<AfiaInboxPage> {
  List<ConversationPreview> _list = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await LocalMessageStore.mergeCloud();
    if (!mounted) return;
    setState(() {
      _list = LocalMessageStore.conversationsFor(SupportChat.peerId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          'Inbox',
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Messages people send from Contact us.',
          style: text.bodyMedium?.copyWith(
            color: HubsomColors.ink.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ),
        if (_list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text('No Contact us messages yet'),
          )
        else
          for (final c in _list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.name),
              subtitle: Text(c.lastMessage),
              trailing: c.unreadCount > 0
                  ? Badge(label: Text('${c.unreadCount}'))
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _AfiaThreadPage(peerId: c.userId),
                  ),
                );
                _reload();
              },
            ),
      ],
    );
  }
}

class _AfiaThreadPage extends StatefulWidget {
  const _AfiaThreadPage({required this.peerId});

  final String peerId;

  @override
  State<_AfiaThreadPage> createState() => _AfiaThreadPageState();
}

class _AfiaThreadPageState extends State<_AfiaThreadPage> {
  final _ctrl = TextEditingController();
  List<DirectMessage> _messages = const [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages = LocalMessageStore.thread(SupportChat.peerId, widget.peerId);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await LocalMessageStore.send(
        from: SupportChat.asUser,
        toUserId: widget.peerId,
        text: text,
        toUserName: LocalMessageStore.resolvePeerName(widget.peerId),
      );
      _ctrl.clear();
      if (!mounted) return;
      setState(() {
        _messages = LocalMessageStore.thread(SupportChat.peerId, widget.peerId);
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = LocalMessageStore.resolvePeerName(widget.peerId);
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final mine = SupportChat.isSupportPeer(m.fromUserId);
                return Align(
                  alignment:
                      mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: mine ? HubsomColors.forest : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      m.text,
                      style: TextStyle(
                        color: mine ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Reply…',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
