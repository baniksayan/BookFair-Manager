import '../entities/partner.dart';

/// Abstract domain repository interface for partner management operations.
abstract interface class PartnerRepository {
  Future<List<Partner>> getPartnersForFair(String fairId);
  Future<Partner?> getPartnerById(String id);
  Future<void> addPartner(Partner partner);
  Future<void> updatePartner(Partner partner);
  Future<void> deletePartner(String id, {bool force = false});
  Stream<List<Partner>> watchPartnersForFair(String fairId);
}
