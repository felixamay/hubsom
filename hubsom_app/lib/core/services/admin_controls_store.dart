import 'dart:convert';

import 'cloud_store.dart';
import 'local_store.dart';

class AdminControls {
  const AdminControls({
    this.signupsOpen = true,
    this.shoppingOpen = true,
    this.sellingOpen = true,
    this.liveOpen = true,
    this.chatOpen = true,
    this.walletOpen = true,
    this.riderOpen = true,
    this.videosOpen = true,
  });

  final bool signupsOpen;
  final bool shoppingOpen;
  final bool sellingOpen;
  final bool liveOpen;
  final bool chatOpen;
  final bool walletOpen;
  final bool riderOpen;
  final bool videosOpen;

  factory AdminControls.fromJson(Map<String, dynamic> json) => AdminControls(
        signupsOpen: json['signupsOpen'] as bool? ?? true,
        shoppingOpen: json['shoppingOpen'] as bool? ?? true,
        sellingOpen: json['sellingOpen'] as bool? ?? true,
        liveOpen: json['liveOpen'] as bool? ?? true,
        chatOpen: json['chatOpen'] as bool? ?? true,
        walletOpen: json['walletOpen'] as bool? ?? true,
        riderOpen: json['riderOpen'] as bool? ?? true,
        videosOpen: json['videosOpen'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': 'platform',
        'signupsOpen': signupsOpen,
        'shoppingOpen': shoppingOpen,
        'sellingOpen': sellingOpen,
        'liveOpen': liveOpen,
        'chatOpen': chatOpen,
        'walletOpen': walletOpen,
        'riderOpen': riderOpen,
        'videosOpen': videosOpen,
      };

  AdminControls copyWith({
    bool? signupsOpen,
    bool? shoppingOpen,
    bool? sellingOpen,
    bool? liveOpen,
    bool? chatOpen,
    bool? walletOpen,
    bool? riderOpen,
    bool? videosOpen,
  }) =>
      AdminControls(
        signupsOpen: signupsOpen ?? this.signupsOpen,
        shoppingOpen: shoppingOpen ?? this.shoppingOpen,
        sellingOpen: sellingOpen ?? this.sellingOpen,
        liveOpen: liveOpen ?? this.liveOpen,
        chatOpen: chatOpen ?? this.chatOpen,
        walletOpen: walletOpen ?? this.walletOpen,
        riderOpen: riderOpen ?? this.riderOpen,
        videosOpen: videosOpen ?? this.videosOpen,
      );

  bool allows(String path) {
    if (path == '/checkout') return shoppingOpen;
    if (path.startsWith('/seller') || path == '/sell' || path.startsWith('/sell/')) {
      if (path.contains('go-live')) return liveOpen && sellingOpen;
      return sellingOpen;
    }
    if (path.startsWith('/messages')) return chatOpen;
    if (path.startsWith('/wallet') || path == '/gifts') return walletOpen;
    if (path.startsWith('/huber')) return riderOpen;
    if (path == '/videos/upload') return videosOpen;
    return true;
  }
}

abstract final class AdminControlsStore {
  static const _key = 'adminControls';
  static const _cloudId = 'platform';

  static AdminControls current() {
    final raw = LocalStore.getString(_key);
    if (raw == null || raw.isEmpty) return const AdminControls();
    try {
      return AdminControls.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const AdminControls();
    }
  }

  static Future<AdminControls> load() async {
    if (CloudStore.useNetwork) {
      try {
        final rows = await CloudStore.listDocs(CloudStore.adminControls);
        if (rows.isNotEmpty) {
          final row = rows.firstWhere(
            (e) => '${e['id']}' == _cloudId,
            orElse: () => rows.first,
          );
          final controls = AdminControls.fromJson(row);
          await LocalStore.setString(_key, jsonEncode(controls.toJson()));
          return controls;
        }
      } catch (_) {}
    }
    return current();
  }

  static Future<AdminControls> save(AdminControls controls) async {
    await LocalStore.setString(_key, jsonEncode(controls.toJson()));
    if (CloudStore.useNetwork) {
      try {
        await CloudStore.upsertDocs(CloudStore.adminControls, [controls.toJson()]);
      } catch (_) {}
    }
    return controls;
  }
}
