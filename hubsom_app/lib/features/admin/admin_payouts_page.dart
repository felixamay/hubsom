import 'package:flutter/material.dart';

import '../../core/constants/hubsom_commission.dart';
import '../../core/services/admin_treasury_store.dart';
import '../../core/services/payment_account_store.dart';
import '../../core/services/withdrawal_store.dart';
import '../../core/theme/hubsom_colors.dart';
import '../../core/utils/money.dart';
import '../../models/seller_payout.dart';
import '../../models/withdrawal_request.dart';

class AdminPayoutsPage extends StatefulWidget {
  const AdminPayoutsPage({super.key});

  @override
  State<AdminPayoutsPage> createState() => _AdminPayoutsPageState();
}

class _AdminPayoutsPageState extends State<AdminPayoutsPage> {
  List<SellerPayout> _payouts = const [];
  List<WithdrawalRequest> _withdrawals = const [];
  TreasurySnapshot _snap = const TreasurySnapshot();
  bool _loading = true;
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AdminTreasuryStore.syncFromOrders();
      await WithdrawalStore.mergeCloud();
      final payouts = await AdminTreasuryStore.listPayouts();
      if (!mounted) return;
      setState(() {
        _payouts = payouts;
        _withdrawals = WithdrawalStore.listAll();
        _snap = AdminTreasuryStore.snapshot(payouts: payouts);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _pay(SellerPayout payout) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay seller from admin'),
        content: Text(
          'Send ${formatGhs(payout.netGhs)} to ${payout.sellerName} '
          '(${HubsomCommission.sellerPercentLabel} of ${formatGhs(payout.salesGhs)}). '
          'Hubsom keeps ${formatGhs(payout.commissionGhs)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Pay seller'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = payout.id);
    try {
      await AdminTreasuryStore.paySeller(payout.id);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Paid ${formatGhs(payout.netGhs)} to ${payout.sellerName}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e'.replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _processWithdrawal(WithdrawalRequest row) async {
    setState(() => _busyId = row.id);
    try {
      await PaymentAccountStore.processWithdrawal(row.id);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked ${formatGhs(row.amountGhs)} as processed'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e'.replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pending = _payouts.where((p) => p.isPending).toList();
    final paid = _payouts.where((p) => p.isPaid).toList();
    final pendingWithdrawals = _withdrawals.where((w) => w.isPending).toList();
    final processedWithdrawals =
        _withdrawals.where((w) => w.isProcessed).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Text(
          'Payouts',
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'The Hubsom Admin payment account is the only '
          'account that receives product payments. Pay sellers into their '
          'withdraw accounts at ${HubsomCommission.sellerPercentLabel} after a '
          '${HubsomCommission.percentLabel} commission.',
          style: text.bodyMedium?.copyWith(
            color: HubsomColors.ink.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MoneyChip(
              label: 'Admin account',
              value: PaymentAccountStore.adminCached().balanceGhs,
            ),
            _MoneyChip(label: 'Collected', value: _snap.collectedGhs),
            _MoneyChip(label: 'Commission 6%', value: _snap.commissionGhs),
            _MoneyChip(label: 'Pending sellers', value: _snap.pendingPayoutsGhs),
            _MoneyChip(label: 'Paid out', value: _snap.paidOutGhs),
            _MoneyChip(label: 'Shipment held', value: _snap.shipmentHeldGhs),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh from orders'),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          Text(
            'Pending withdrawals',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (pendingWithdrawals.isEmpty)
            const Text('No withdrawal submissions waiting')
          else
            for (final row in pendingWithdrawals)
              _WithdrawalAdminTile(
                request: row,
                busy: _busyId == row.id,
                onProcess: () => _processWithdrawal(row),
              ),
          const SizedBox(height: 24),
          Text(
            'Processed withdrawals',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (processedWithdrawals.isEmpty)
            const Text('No processed withdrawals yet')
          else
            for (final row in processedWithdrawals.take(40))
              _WithdrawalAdminTile(request: row),
          const SizedBox(height: 24),
          Text(
            'Pending seller payouts',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (pending.isEmpty)
            const Text('No seller payouts waiting')
          else
            for (final payout in pending) _PayoutTile(
              payout: payout,
              busy: _busyId == payout.id,
              onPay: () => _pay(payout),
            ),
          const SizedBox(height: 24),
          Text(
            'Paid',
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (paid.isEmpty)
            const Text('No admin payouts yet')
          else
            for (final payout in paid.take(40))
              _PayoutTile(payout: payout),
        ],
      ],
    );
  }
}

class _WithdrawalAdminTile extends StatelessWidget {
  const _WithdrawalAdminTile({
    required this.request,
    this.onProcess,
    this.busy = false,
  });

  final WithdrawalRequest request;
  final VoidCallback? onProcess;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(request.userName.isEmpty ? request.userEmail : request.userName),
      subtitle: Text(
        [
          formatGhs(request.amountGhs),
          request.handle,
          request.rail,
          if (request.userEmail.isNotEmpty) request.userEmail,
        ].join(' · '),
      ),
      trailing: request.isProcessed
          ? const Chip(label: Text('Processed'))
          : FilledButton(
              onPressed: busy || onProcess == null ? null : onProcess,
              child: Text(busy ? 'Updating…' : 'Mark processed'),
            ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({
    required this.payout,
    this.onPay,
    this.busy = false,
  });

  final SellerPayout payout;
  final VoidCallback? onPay;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(payout.sellerName),
      subtitle: Text(
        [
          payout.orderId,
          'Sales ${formatGhs(payout.salesGhs)}',
          'Fee ${formatGhs(payout.commissionGhs)}',
          'Net ${formatGhs(payout.netGhs)}',
          if (payout.sellerEmail.isNotEmpty) payout.sellerEmail,
        ].join(' · '),
      ),
      trailing: payout.isPaid
          ? const Chip(label: Text('Paid'))
          : FilledButton(
              onPressed: busy || onPay == null ? null : onPay,
              child: Text(busy ? 'Paying…' : 'Pay 94%'),
            ),
    );
  }
}

class _MoneyChip extends StatelessWidget {
  const _MoneyChip({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HubsomColors.forest.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatGhs(value),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: HubsomColors.forest,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
