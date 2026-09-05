import 'dart:convert';

import '../../models/user.dart';
import 'ghana_places.dart';
import 'local_store.dart';

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

  static UserAddress fromAllowedGps(
    GeoLocation pin, {
    String? id,
    String? phone,
    bool isDefault = true,
  }) {
    final near = GhanaPlaces.nearest(pin.latitude, pin.longitude);
    return UserAddress.fromGps(
      id: id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
      location: pin,
      phone: phone,
      isDefault: isDefault,
      city: near.city,
      region: near.region,
    );
  }

  static Future<HubsomUser> saveAllowedGps({
    required HubsomUser user,
    required GeoLocation pin,
    String? phone,
  }) async {
    final nextAddress = fromAllowedGps(
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
