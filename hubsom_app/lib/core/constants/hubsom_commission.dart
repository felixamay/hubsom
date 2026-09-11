/// Hubsom keeps 6% of merchandise. Product payments settle on the admin
/// receive account. Seller and user accounts are withdraw-only.
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
}
