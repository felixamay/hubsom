import '../../models/user.dart';
import '../auth/afia_access.dart';

/// Direct chat target for Contact us. User-facing name is Hubsom Support.
abstract final class SupportChat {
  static const peerId = 'hubsom-support';
  static const displayName = 'Hubsom Support';
  static const pageTitle = 'Contact us';
  static const intro =
      'Questions about an order, a live show, or your account? '
      'Write here and Hubsom Support will reply on this chat.';
  static const emptyPrompt = 'Send a message. Replies show up here.';
  static const composeHint = 'Write a message…';
  static const signInToChat = 'Sign in to send a message';

  static bool isSupportPeer(String? id) =>
      id != null && id.trim() == peerId;

  static bool receivesInbox(HubsomUser? user) {
    if (user == null) return false;
    return user.id == peerId || AfiaAccess.isOwner(user);
  }

  static HubsomUser get asUser => const HubsomUser(
        id: peerId,
        email: '',
        name: displayName,
        role: 'buyer',
      );
}
