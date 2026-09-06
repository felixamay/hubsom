import 'dart:convert';

import '../../core/auth/afia_access.dart';
import '../../core/constants/hubsom_commission.dart';
import '../../models/payment_account.dart';
import '../../models/user.dart';
import 'admin_account_store.dart';
import 'cloud_store.dart';
import 'local_store.dart';

/// Admin receive account + withdraw-only seller/user accounts.
abstract final class PaymentAccountStore {
  static const _key = 'paymentAccounts';

  static PaymentAccount adminCached() {
    final existing = _byId()[PaymentAccount.adminId];
    return existing ??
        PaymentAccount.admin(
          ownerUserId: AfiaAccess.ownerEmail,
          email: AfiaAccess.ownerEmail,
          name: HubsomCommission.adminName,
        );
  }

  static PaymentAccount? cachedForUser(HubsomUser user) =>
      _byId()[PaymentAccount.userIdFor(user.id)];

  static Future<PaymentAccount> adminAccount() async {
    final byId = _byId();
    final current = byId[PaymentAccount.adminId];
    if (current != null) return current;
    final created = PaymentAccount.admin(
      ownerUserId: AfiaAccess.ownerEmail,
      email: AfiaAccess.ownerEmail,
      name: HubsomCommission.adminName,
    );
    await _save(created);
    return created;
  }

  /// Seller/user account: withdraw product earnings. Cannot receive payments.
  static Future<PaymentAccount> withdrawAccountFor(HubsomUser user) async {
    final id = PaymentAccount.userIdFor(user.id);
    final byId = _byId();
    final current = byId[id];
    if (current != null) {
      if (current.canReceive) {
        throw StateError('This payment account cannot receive customer payments');
      }
      return current;
    }
    final created = PaymentAccount.withdrawOnly(
      ownerUserId: user.id,
      email: user.email,
      name: user.name,
      balanceGhs: user.walletBalanceGhs,
    );
    await _save(created);
    return created;
  }

  /// Product checkout money may only land on the admin receive account.
  static Future<PaymentAccount> receiveProductPayment({
    required String orderId,
    required double amountGhs,
    String? destinationAccountId,
  }) async {
    if (destinationAccountId != null &&
        destinationAccountId.isNotEmpty &&
        destinationAccountId != PaymentAccount.adminId) {
      throw StateError(
        'Product payments can only be made to the admin payment account',
      );
    }
    final amount = HubsomCommission.roundGhs(amountGhs);
    if (amount <= 0) return adminAccount();
    final admin = await adminAccount();
    if (!admin.canReceive) {
      throw StateError('Admin payment account cannot receive');
    }
    final ref = 'order_$orderId';
    if (admin.creditedRefs.contains(ref)) return admin;
    final next = admin.copyWith(
      balanceGhs: HubsomCommission.roundGhs(admin.balanceGhs + amount),
      creditedRefs: [ref, ...admin.creditedRefs],
    );
    await _save(next);
    return next;
  }

  /// Admin pays a seller/user withdraw account. This is not a customer receive.
  static Future<({PaymentAccount admin, PaymentAccount user, HubsomUser userProfile})>
      creditWithdrawPayout({
    required HubsomUser user,
    required double netGhs,
    required String payoutId,
  }) async {
    final net = HubsomCommission.roundGhs(netGhs);
    if (net <= 0) {
      throw StateError('Payout must be greater than zero');
    }
    final dest = await withdrawAccountFor(user);
    if (dest.canReceive) {
      throw StateError('Seller payment accounts cannot receive product payments');
    }
    if (dest.creditedRefs.contains(payoutId)) {
      return (
        admin: await adminAccount(),
        user: dest,
        userProfile: user,
      );
    }
    final admin = await adminAccount();
    if (admin.balanceGhs + 0.001 < net) {
      throw StateError(
        'Admin payment account needs ${net.toStringAsFixed(2)} GHS to pay this seller',
      );
    }
    final nextAdmin = admin.copyWith(
      balanceGhs: HubsomCommission.roundGhs(admin.balanceGhs - net),
    );
    final nextUser = dest.copyWith(
      balanceGhs: HubsomCommission.roundGhs(dest.balanceGhs + net),
      creditedRefs: [payoutId, ...dest.creditedRefs],
    );
    final profile = user.copyWith(walletBalanceGhs: nextUser.balanceGhs);
    await _save(nextAdmin);
    await _save(nextUser);
    await AdminAccountStore.save(profile);
    await _mirrorSession(profile);
    return (admin: nextAdmin, user: nextUser, userProfile: profile);
  }

  static Future<({PaymentAccount account, HubsomUser user})> withdraw({
    required HubsomUser user,
    required double amountGhs,
    required String rail,
    required String handle,
  }) async {
    final account = await withdrawAccountFor(user);
    if (account.canReceive) {
      throw StateError('The admin receive account is not a user withdraw account');
    }
    final amount = HubsomCommission.roundGhs(amountGhs);
    if (amount <= 0) throw StateError('Enter an amount to withdraw');
    if (account.balanceGhs + 0.001 < amount) {
      throw StateError(
        'Payment account needs ${amount.toStringAsFixed(2)} GHS to withdraw',
      );
    }
    final next = account.copyWith(
      balanceGhs: HubsomCommission.roundGhs(account.balanceGhs - amount),
      withdrawRail: rail,
      withdrawHandle: handle,
    );
    final profile = user.copyWith(walletBalanceGhs: next.balanceGhs);
    await _save(next);
    await AdminAccountStore.save(profile);
    await _mirrorSession(profile);
    return (account: next, user: profile);
  }

  static Future<PaymentAccount> spendFromWithdrawAccount({
    required HubsomUser user,
    required double amountGhs,
    required String ref,
  }) async {
    final account = await withdrawAccountFor(user);
    final amount = HubsomCommission.roundGhs(amountGhs);
    if (account.balanceGhs + 0.001 < amount) {
      throw StateError(
        'Payment account needs ${amount.toStringAsFixed(2)} GHS for this payment',
      );
    }
    final next = account.copyWith(
      balanceGhs: HubsomCommission.roundGhs(account.balanceGhs - amount),
      creditedRefs: ['spend_$ref', ...account.creditedRefs],
    );
    final profile = user.copyWith(walletBalanceGhs: next.balanceGhs);
    await _save(next);
    await AdminAccountStore.save(profile);
    await _mirrorSession(profile);
    return next;
  }

  static Map<String, PaymentAccount> _byId() {
    final raw = LocalStore.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List;
      final map = <String, PaymentAccount>{};
      for (final row in list) {
        if (row is! Map) continue;
        final account = PaymentAccount.fromJson(Map<String, dynamic>.from(row));
        if (account.id.isNotEmpty) map[account.id] = account;
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  static Future<void> _save(PaymentAccount account) async {
    final byId = _byId()..[account.id] = account;
    final rows = byId.values.map((e) => e.toJson()).toList();
    await LocalStore.setString(_key, jsonEncode(rows));
    try {
      await CloudStore.upsertDocs(CloudStore.paymentAccounts, rows);
    } catch (_) {}
  }

  static Future<void> _mirrorSession(HubsomUser user) async {
    final raw = LocalStore.userJson;
    if (raw == null || raw.isEmpty) return;
    try {
      final session = HubsomUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (session.id != user.id &&
          AfiaAccess.normalizeEmail(session.email) !=
              AfiaAccess.normalizeEmail(user.email)) {
        return;
      }
      await LocalStore.setUserJson(jsonEncode(user.toJson()));
    } catch (_) {}
  }
}
