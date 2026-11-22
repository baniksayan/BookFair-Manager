import '../../features/book_fairs/domain/entities/investment.dart';
import 'currency_formatter.dart';

/// Dedicated utility for precision financial calculations and budget analysis.
///
/// Implements exact integer-paise math (1 INR = 100 paise) to prevent
/// floating-point rounding errors across partner equity and fair ledgers.
abstract final class FinancialCalculator {
  /// Calculates the total recorded investment in paise for a given list of investments.
  static int calculateTotalInvestmentPaise(List<Investment> investments) {
    var sum = 0;
    for (final inv in investments) {
      sum += inv.amountPaise;
    }
    return sum;
  }

  /// Calculates total recorded investment in INR currency units.
  static double calculateTotalInvestment(List<Investment> investments) {
    return calculateTotalInvestmentPaise(investments) / 100.0;
  }

  /// Calculates the sum of contributions in paise for a specific partner and fair.
  static int calculatePartnerContributionPaise({
    required List<Investment> investments,
    required String partnerId,
  }) {
    var sum = 0;
    for (final inv in investments) {
      if (inv.partnerId == partnerId) {
        sum += inv.amountPaise;
      }
    }
    return sum;
  }

  /// Calculates the sum of contributions in INR for a specific partner.
  static double calculatePartnerContribution({
    required List<Investment> investments,
    required String partnerId,
  }) {
    return calculatePartnerContributionPaise(
          investments: investments,
          partnerId: partnerId,
        ) /
        100.0;
  }

  /// Calculates remaining planned budget in paise:
  /// (Estimated Budget Paise) - (Total Recorded Investment Paise)
  ///
  /// NOTE: This is an upfront capital planning metric comparing target budget
  /// to collected partner capital. It does NOT represent current cash in hand.
  static int calculateRemainingPlannedBudgetPaise({
    required int estimatedBudgetPaise,
    required int recordedInvestmentPaise,
  }) {
    return estimatedBudgetPaise - recordedInvestmentPaise;
  }

  /// Calculates remaining planned budget in INR.
  static double calculateRemainingPlannedBudget({
    required double estimatedBudget,
    required double recordedInvestment,
  }) {
    final budgetPaise = (estimatedBudget * 100).round();
    final investmentPaise = (recordedInvestment * 100).round();
    return calculateRemainingPlannedBudgetPaise(
          estimatedBudgetPaise: budgetPaise,
          recordedInvestmentPaise: investmentPaise,
        ) /
        100.0;
  }

  /// Formats an amount in paise directly into a standard formatted INR string (e.g. ₹ 1,85,000).
  static String formatPaise(int paise) {
    return CurrencyFormatter.format(paise / 100.0);
  }

  /// Parses user-entered currency string into exact integer paise.
  static int parseToPaise(String input) {
    final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
    final val = double.tryParse(cleaned) ?? 0.0;
    return (val * 100).round();
  }
}
