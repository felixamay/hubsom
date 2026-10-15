import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/auth/afia_access.dart';
import '../../core/constants/hubsom_commission.dart';
import '../../models/payment_account.dart';
import '../../models/user.dart';
import '../../models/withdrawal_request.dart';
import 'admin_account_store.dart';
import 'cloud_store.dart';
import 'local_store.dart';
import 'withdrawal_store.dart';

/// Admin receive account + withdraw-only seller/user accounts.
abstract final class PaymentAccountStore {
  static const _key = 'paymentAccounts';

  /// Other-device snapshot used by [withdraw] / [spendFromWithdrawAccount].
  /// Tests inject this so a stale laptop cache cannot cash out twice.
  @visibleForTesting
  static PaymentAccount? debugIncomingAccount;

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

  /// Undo [receiveProductPayment] when a paid order is cancelled.
  static Future<PaymentAccount> reverseProductPayment({
    required String orderId,
    required double amountGhs,
  }) async {
    final admin = await adminAccount();
    final ref = 'order_$orderId';
    if (!admin.creditedRefs.contains(ref)) return admin;
    final amount = HubsomCommission.roundGhs(amountGhs);
    final next = admin.copyWith(
      balanceGhs: HubsomCommission.roundGhs(admin.balanceGhs - amount),
      creditedRefs: admin.creditedRefs.where((e) => e != ref).toList(),
    );
    await _save(next);
    return next;
  }

  /// Put a wallet checkout back on the buyer's withdraw account.
  static Future<PaymentAccount> refundToWithdrawAccount({
    required HubsomUser user,
    required double amountGhs,
    required String orderId,
  }) async {
    final account = await withdrawAccountFor(user);
    final amount = HubsomCommission.roundGhs(amountGhs);
    if (amount <= 0) return account;
    final ref = 'refund_$orderId';
    if (account.creditedRefs.contains(ref)) return account;
    final next = account.copyWith(
      balanceGhs: HubsomCommission.roundGhs(account.balanceGhs + amount),
      creditedRefs: [ref, ...account.creditedRefs],
    );
    final profile = user.copyWith(walletBalanceGhs: next.balanceGhs);
    await _save(next);
    await AdminAccountStore.save(profile);
    await _mirrorSession(profile);
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

  /// Hold the amount and send a pending withdrawal for review.
  static Future<
      ({
        PaymentAccount account,
        HubsomUser user,
        WithdrawalRequest request,
      })> withdraw({
    required HubsomUser user,
    required double amountGhs,
    required String rail,
    required String handle,
  }) async {
    final account = await _latestWithdrawAccount(user);
    if (account.canReceive) {
      throw StateError('The admin receive account is not a user withdraw account');
    }
    final number = handle.replaceAll(RegExp(r'\s+'), '');
    if (number.replaceAll(RegExp(r'\D'), '').length < 9) {
      throw StateError('Enter the MoMo number to receive this withdrawal');
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
      withdrawHandle: number,
    );
    final profile = user.copyWith(walletBalanceGhs: next.balanceGhs);
    final request = WithdrawalRequest(
      id: 'wd-${DateTime.now().microsecondsSinceEpoch}',
      userId: user.id,
      userName: user.name,
      userEmail: user.email,
      amountGhs: amount,
      rail: rail,
      handle: number,
      status: 'pending',
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await _save(next);
    await AdminAccountStore.save(profile);
    await _mirrorSession(profile);
    await WithdrawalStore.upsert(request);
    return (account: next, user: profile, request: request);
  }

  static Future<WithdrawalRequest> processWithdrawal(String id) {
    return WithdrawalStore.markProcessed(id);
  }

  static Future<PaymentAccount> spendFromWithdrawAccount({
    required HubsomUser user,
    required double amountGhs,
    required String ref,
  }) async {
    final account = await _latestWithdrawAccount(user);
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

  /// Prefer the cloud row when another phone already spent or cashed out.
  ///
  /// A laptop that stayed signed in keeps the pre-withdraw balance. Using that
  /// cache let the same 94 GHS be submitted twice — admin would pay both.
  @visibleForTesting
  static PaymentAccount resolveAgainstCloud({
    required PaymentAccount local,
    PaymentAccount? remote,
  }) {
    if (remote == null) return local;
    final preferred = PaymentAccount.fromJson(
      CloudStore.preferFresherPaymentAccount(
        local: local.toJson(),
        incoming: remote.toJson(),
      ),
    );
    // A spend on the other phone may lose the updatedAt race. Never debit
    // against a balance Firestore already reduced.
    if (remote.balanceGhs + 0.001 < preferred.balanceGhs) {
      return remote;
    }
    return preferred;
  }

  static Future<PaymentAccount> _latestWithdrawAccount(HubsomUser user) async {
    final local = await withdrawAccountFor(user);
    var remote = debugIncomingAccount;
    if (remote == null && CloudStore.useNetwork) {
      try {
        final row = await CloudStore.getDoc(
          CloudStore.paymentAccounts,
          local.id,
        );
        if (row != null && row.isNotEmpty) {
          remote = PaymentAccount.fromJson(row);
        }
      } catch (_) {}
    }
    final latest = resolveAgainstCloud(local: local, remote: remote);
    if (latest.balanceGhs + 0.001 < local.balanceGhs) {
      await _writeLocal(latest);
    }
    return latest;
  }

  static Future<void> _writeLocal(PaymentAccount account) async {
    final byId = _byId()..[account.id] = account;
    await LocalStore.setString(
      _key,
      jsonEncode(byId.values.map((e) => e.toJson()).toList()),
    );
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
    final stamped = account.copyWith(
      updatedAt: DateTime.now().toUtc().toIso8601String(),
    );
    final byId = _byId()..[stamped.id] = stamped;
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
