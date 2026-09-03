import '../../models/huber.dart';
import '../../models/shipment.dart';
import '../../models/user.dart';
import '../services/cloud_store.dart';
import '../services/local_huber_store.dart';

class HuberRepository {
  Future<void> refreshFromCloud() => CloudStore.hydrateLocalCache();

  HuberProfile? profileFor(HubsomUser user) =>
      LocalHuberStore.profileForUser(user.id) ??
      (user.huberId != null ? LocalHuberStore.profileById(user.huberId!) : null);

  List<HuberOffer> openOffers(HuberProfile driver) =>
      LocalHuberStore.openOffersForDriver(driver.id);

  HuberDelivery? activeDelivery(HuberProfile driver) =>
      LocalHuberStore.activeDeliveryFor(driver.id);

  HuberDelivery? deliveryById(String id) => LocalHuberStore.deliveryById(id);

  List<HuberDelivery> completed(HuberProfile driver) =>
      LocalHuberStore.completedFor(driver.id);

  Future<HuberProfile> setOnline(HuberProfile driver, bool online) =>
      LocalHuberStore.setOnline(driver.id, online);

  Future<HuberProfile> verifyIdentity({
    required HuberProfile driver,
    required String idType,
    required String idNumber,
  }) =>
      LocalHuberStore.verifyIdentity(
        huberId: driver.id,
        idType: idType,
        idNumber: idNumber,
      );

  Future<HuberDelivery> acceptOffer(String offerId, HuberProfile driver) =>
      LocalHuberStore.acceptOffer(offerId: offerId, driver: driver);

  Future<void> declineOffer(String offerId, HuberProfile driver) =>
      LocalHuberStore.declineOffer(offerId: offerId, driver: driver);

  Future<HuberDelivery> advanceDelivery(String deliveryId) =>
      LocalHuberStore.advanceDelivery(deliveryId);

  Future<HuberDelivery> completeDelivery(String deliveryId) =>
      LocalHuberStore.completeWithPod(deliveryId);

  Future<({Shipment shipment, List<HuberOffer> offers})> dispatch(
    Shipment shipment, {
    double? preferredFeeGhs,
  }) =>
      LocalHuberStore.dispatchToHubers(
        shipment,
        preferredFeeGhs: preferredFeeGhs,
      );
}
