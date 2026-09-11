import 'dart:convert';

import '../../models/user.dart';
import 'local_store.dart';
import 'place_lookup.dart';

/// Persist the GPS pin the user allowed as their delivery address.
class UserAddressStore {
  UserAddressStore._();

  static UserAddress? defaultAddress(HubsomUser user) {
    UserAddress? withPin;
    for (final address in user.addresses) {
      if (address.location == null) continue;
      withPin ??= address;
      if (address.isDefault == true) return address;
    }
    return withPin ?? (user.addresses.isEmpty ? null : user.addresses.first);
  }

  static Future<UserAddress> fromAllowedGps(
    GeoLocation pin, {
    String? id,
    String? phone,
    bool isDefault = true,
  }) async {
    final place = await PlaceLookup.reverse(pin);
    return UserAddress.fromGps(
      id: id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
      location: pin,
      phone: phone,
      isDefault: isDefault,
      line1: place.line1,
      city: place.city,
      region: place.region,
    );
  }

  static Future<HubsomUser> saveAllowedGps({
    required HubsomUser user,
    required GeoLocation pin,
    String? phone,
  }) async {
    final nextAddress = await fromAllowedGps(
      pin,
      phone: phone ?? user.phone,
    );
    final existing = defaultAddress(user);
    final addresses = [
      if (existing != null)
        UserAddress.fromGps(
          id: existing.id,
          location: pin,
          label: existing.label,
          phone: phone ?? existing.phone ?? user.phone,
          isDefault: true,
          line1: nextAddress.line1,
          city: nextAddress.city,
          region: nextAddress.region,
        )
      else
        nextAddress,
      ...user.addresses.where((a) => a.id != existing?.id),
    ];
    final next = user.copyWith(addresses: addresses);
    await LocalStore.setUserJson(jsonEncode(next.toJson()));
    return next;
  }
}
