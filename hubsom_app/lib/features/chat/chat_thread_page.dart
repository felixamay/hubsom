import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/message.dart';

class ChatThreadPage extends ConsumerStatefulWidget {
  const ChatThreadPage({super.key, required this.userId});
  final String userId;

  @override
  ConsumerState<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends ConsumerState<ChatThreadPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<DirectMessage> messages = [];
  bool loading = true;
  bool sending = false;
  String peerName = '';
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(messageRepositoryProvider);
    setState(() {
      loading = true;
      error = null;
      peerName = repo.peerName(widget.userId);
    });
    try {
      final list = await repo.thread(widget.userId);
      await repo.markThreadRead(widget.userId);
      ref.read(messagesTickProvider.notifier).state++;
      if (!mounted) return;
      setState(() {
        messages = list;
        loading = false;
        if (list.isNotEmpty) {
          final last = list.last;
          final me = ref.read(authStateProvider).valueOrNull?.id;
          if (me != null) {
            peerName = last.fromUserId == me
                ? (last.toUserName.isNotEmpty
                    ? last.toUserName
                    : peerName)
                : (last.fromUserName.isNotEmpty
                    ? last.fromUserName
                    : peerName);
          }
        }
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = '$e';
      });
    }
  }

  Future<void> _send() async {
    if (!ensureSignedIn(context, ref, message: 'Sign in to send messages')) {
      return;
    }
    final text = _ctrl.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await ref.read(messageRepositoryProvider).send(
            widget.userId,
            text,
            toUserName: peerName,
          );
      _ctrl.clear();
      ref.read(messagesTickProvider.notifier).state++;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meId = ref.watch(authStateProvider).valueOrNull?.id;
    return Scaffold(
      appBar: AppBar(
        title: Text(peerName.isEmpty ? 'Chat' : peerName),
      ),
      body: Column(
        children: [
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? Center(child: Text(error!))
                    : messages.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Say hello to $peerName',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      HubsomColors.ink.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.all(16),
                            itemCount: messages.length,
                            itemBuilder: (_, i) {
                              final m = messages[i];
                              final mine = meId != null && m.fromUserId == meId;
                              return Align(
                                alignment: mine
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width * 0.78,
                                  ),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: mine
                                        ? HubsomColors.forest
                                        : Colors.grey.shade200,
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
                        hintText: 'Message…',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: sending ? null : _send,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
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
