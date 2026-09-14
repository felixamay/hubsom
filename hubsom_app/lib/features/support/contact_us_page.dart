import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/require_auth.dart';
import '../../core/providers/core_providers.dart';
import '../../core/support/support_chat.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../models/message.dart';

class ContactUsPage extends ConsumerStatefulWidget {
  const ContactUsPage({super.key});

  @override
  ConsumerState<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends ConsumerState<ContactUsPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  List<DirectMessage> _messages = const [];
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messages = _localThread();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<DirectMessage> _localThread() {
    final me = ref.read(authStateProvider).valueOrNull;
    if (me == null) return const [];
    return ref.read(messageRepositoryProvider).localThread(SupportChat.peerId);
  }

  Future<void> _refresh() async {
    final me = ref.read(authStateProvider).valueOrNull;
    if (me == null) return;
    final list =
        await ref.read(messageRepositoryProvider).thread(SupportChat.peerId);
    await ref.read(messageRepositoryProvider).markThreadRead(SupportChat.peerId);
    if (!mounted) return;
    setState(() => _messages = list);
    ref.read(messagesTickProvider.notifier).state++;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    if (!ensureSignedIn(context, ref, message: SupportChat.signInToChat)) {
      return;
    }
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(messageRepositoryProvider).send(
            SupportChat.peerId,
            text,
            toUserName: SupportChat.displayName,
          );
      _ctrl.clear();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meId = ref.watch(authStateProvider).valueOrNull?.id;
    return Scaffold(
      appBar: AppBar(title: const Text(SupportChat.pageTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              SupportChat.intro,
              style: TextStyle(
                color: HubsomColors.ink.withValues(alpha: 0.72),
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        SupportChat.emptyPrompt,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: HubsomColors.ink.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final mine = meId != null && m.fromUserId == meId;
                      return Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
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
                        hintText: SupportChat.composeHint,
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
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
