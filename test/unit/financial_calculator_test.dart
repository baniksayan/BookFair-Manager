import 'package:bookfair_manager/core/utils/financial_calculator.dart';
import 'package:bookfair_manager/features/book_fairs/domain/entities/investment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinancialCalculator Unit Tests', () {
    final now = DateTime(2026, 11, 21);
    final List<Investment> investments = [
      Investment(
        id: 'inv-1',
        fairId: 'fair-1',
        partnerId: 'partner-1',
        amountPaise: 5000000, // ₹50,000.00
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.bankTransfer,
        contributionDate: now,
        notes: 'Initial tranche',
        createdAt: now,
        updatedAt: now,
      ),
      Investment(
        id: 'inv-2',
        fairId: 'fair-1',
        partnerId: 'partner-2',
        amountPaise: 2500000, // ₹25,000.00
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.upi,
        contributionDate: now,
        notes: 'Equity contribution',
        createdAt: now,
        updatedAt: now,
      ),
      Investment(
        id: 'inv-3',
        fairId: 'fair-1',
        partnerId: 'partner-1',
        amountPaise: 1500000, // ₹15,000.00
        contributionType: ContributionType.cash,
        paymentMethod: PaymentMethod.cash,
        contributionDate: now,
        notes: 'Secondary contribution',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    test(
      'calculateTotalInvestmentPaise calculates correct integer paise sum',
      () {
        final totalPaise = FinancialCalculator.calculateTotalInvestmentPaise(
          investments,
        );
        expect(totalPaise, equals(9000000)); // ₹90,000.00 in paise
      },
    );

    test('calculateTotalInvestment returns correct rupee representation', () {
      final totalRupees = FinancialCalculator.calculateTotalInvestment(
        investments,
      );
      expect(totalRupees, equals(90000.0));
    });

    test('calculatePartnerContributionPaise calculates per-partner sums accurately', () {
      final partner1Paise =
          FinancialCalculator.calculatePartnerContributionPaise(
            investments: investments,
            partnerId: 'partner-1',
          );
      final partner2Paise =
          FinancialCalculator.calculatePartnerContributionPaise(
            investments: investments,
            partnerId: 'partner-2',
          );
      final partner3Paise =
          FinancialCalculator.calculatePartnerContributionPaise(
            investments: investments,
            partnerId: 'partner-non-existent',
          );

      expect(partner1Paise, equals(6500000)); // ₹65,000.00
      expect(partner2Paise, equals(2500000)); // ₹25,000.00
      expect(partner3Paise, equals(0));
    });

    test(
      'calculatePartnerContribution returns correct rupee values for partners',
      () {
        final partner1Rupees = FinancialCalculator.calculatePartnerContribution(
          investments: investments,
          partnerId: 'partner-1',
        );
        expect(partner1Rupees, equals(65000.0));
      },
    );

    test('calculateRemainingPlannedBudgetPaise handles positive, zero, and deficit margins', () {
      // Planned: ₹1,00,000 (10000000 paise), Collected: ₹90,000 (9000000 paise) -> Remaining ₹10,000 (1000000 paise)
      expect(
        FinancialCalculator.calculateRemainingPlannedBudgetPaise(
          estimatedBudgetPaise: 10000000,
          recordedInvestmentPaise: 9000000,
        ),
        equals(1000000),
      );

      // Planned: ₹90,000, Collected: ₹90,000 -> 0 paise
      expect(
        FinancialCalculator.calculateRemainingPlannedBudgetPaise(
          estimatedBudgetPaise: 9000000,
          recordedInvestmentPaise: 9000000,
        ),
        equals(0),
      );

      // Planned: ₹80,000, Collected: ₹90,000 -> Deficit / Surplus -1000000 paise
      expect(
        FinancialCalculator.calculateRemainingPlannedBudgetPaise(
          estimatedBudgetPaise: 8000000,
          recordedInvestmentPaise: 9000000,
        ),
        equals(-1000000),
      );
    });

    test(
      'calculateRemainingPlannedBudget in rupees matches double expectations',
      () {
        expect(
          FinancialCalculator.calculateRemainingPlannedBudget(
            estimatedBudget: 150000.0,
            recordedInvestment: 90000.0,
          ),
          equals(60000.0),
        );
      },
    );

    test('parseToPaise parses various input formats correctly', () {
      expect(FinancialCalculator.parseToPaise('1000'), equals(100000));
      expect(FinancialCalculator.parseToPaise('1000.50'), equals(100050));
      expect(FinancialCalculator.parseToPaise('₹ 25,000.00'), equals(2500000));
      expect(FinancialCalculator.parseToPaise(''), equals(0));
      expect(FinancialCalculator.parseToPaise('abc'), equals(0));
      expect(FinancialCalculator.parseToPaise('0.75'), equals(75));
    });

    test('formatPaise generates formatted rupee strings without floating-point artifacts', () {
      expect(FinancialCalculator.formatPaise(10000000), contains('100,000'));
      expect(FinancialCalculator.formatPaise(50000), contains('500'));
      expect(FinancialCalculator.formatPaise(0), contains('0'));
    });
  });
}
