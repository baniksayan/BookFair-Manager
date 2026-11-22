import '../entities/investment.dart';

/// Abstract domain repository interface for investment ledger operations.
abstract interface class InvestmentRepository {
  Future<List<Investment>> getInvestmentsForFair(String fairId);
  Future<List<Investment>> getInvestmentsForPartner(
    String fairId,
    String partnerId,
  );
  Future<Investment?> getInvestmentById(String id);
  Future<void> addInvestment(Investment investment);
  Future<void> updateInvestment(Investment investment);
  Future<void> deleteInvestment(String id);
  Stream<List<Investment>> watchInvestmentsForFair(String fairId);
}
