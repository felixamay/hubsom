/// Hubsom takes 6% of merchandise sales. Buyers pay Hubsom Admin;
/// admin later pays sellers the remaining 94%.
abstract final class HubsomCommission {
  static const rate = 0.06;
  static const sellerRate = 0.94;
  static const percentLabel = '6%';
  static const sellerPercentLabel = '94%';
  static const adminName = 'Hubsom Admin';

  static double roundGhs(double value) => (value * 100).round() / 100.0;

  static double commissionOn(double salesGhs) =>
      roundGhs(roundGhs(salesGhs) * rate);

  static double netOn(double salesGhs) {
    final sales = roundGhs(salesGhs);
    return roundGhs(sales - commissionOn(sales));
  }

  static String buyerNotice({
    required double merchandiseGhs,
    double shipmentGhs = 0,
  }) {
    final commission = commissionOn(merchandiseGhs);
    final net = netOn(merchandiseGhs);
    final ship = shipmentGhs > 0
        ? ' Shipment is also collected by $adminName for delivery.'
        : '';
    return 'Paid to $adminName. Hubsom keeps $percentLabel '
        '(${_ghs(commission)}) and pays the seller $sellerPercentLabel '
        '(${_ghs(net)}) after the sale.$ship';
  }

  static String sellerNotice({
    required double salesGhs,
    required double pendingGhs,
  }) {
    return 'Hubsom Admin holds your sales and pays $sellerPercentLabel '
        'after a $percentLabel commission. '
        'Pending ${pendingGhs <= 0 ? _ghs(netOn(salesGhs)) : _ghs(pendingGhs)}.';
  }

  static String _ghs(double value) => 'GH₵${value.toStringAsFixed(2)}';
}
