import 'package:intl/intl.dart';

final _ghs = NumberFormat.currency(locale: 'en_GH', symbol: 'GH₵', decimalDigits: 2);

String formatGhs(num amount) => _ghs.format(amount);
