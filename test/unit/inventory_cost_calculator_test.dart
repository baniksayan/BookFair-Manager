import 'package:bookfair_manager/features/inventory/domain/entities/book.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/purchase_item.dart';
import 'package:bookfair_manager/features/inventory/domain/entities/stock_movement.dart';
import 'package:bookfair_manager/features/inventory/domain/services/inventory_cost_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InventoryCostCalculator Unit Tests', () {
    test('calculateAvailableStock sums ledger deltas correctly', () {
      final now = DateTime(2026, 11, 21);
      final movements = [
        StockMovement(
          id: 'm1',
          fairId: 'fair-1',
          bookId: 'book-1',
          quantity: 25,
          movementType: StockMovementType.purchaseIn,
          movementDate: now,
          createdAt: now,
        ),
        StockMovement(
          id: 'm2',
          fairId: 'fair-1',
          bookId: 'book-1',
          quantity: 10,
          movementType: StockMovementType.saleOut,
          movementDate: now.add(const Duration(hours: 1)),
          createdAt: now.add(const Duration(hours: 1)),
        ),
        StockMovement(
          id: 'm3',
          fairId: 'fair-1',
          bookId: 'book-1',
          quantity: 2,
          movementType: StockMovementType.damaged,
          movementDate: now.add(const Duration(hours: 2)),
          createdAt: now.add(const Duration(hours: 2)),
        ),
        StockMovement(
          id: 'm4',
          fairId: 'fair-1',
          bookId: 'book-1',
          quantity: 1,
          movementType: StockMovementType.customerReturnIn,
          movementDate: now.add(const Duration(hours: 3)),
          createdAt: now.add(const Duration(hours: 3)),
        ),
      ];

      final totalStock = InventoryCostCalculator.calculateAvailableStock(
        movements,
      );
      // 25 - 10 - 2 + 1 = 14
      expect(totalStock, equals(14));
    });

    test('calculateAvailableStockForBook filters by book ID accurately', () {
      final now = DateTime(2026, 11, 21);
      final movements = [
        StockMovement(
          id: 'm1',
          fairId: 'fair-1',
          bookId: 'book-1',
          quantity: 50,
          movementType: StockMovementType.purchaseIn,
          movementDate: now,
          createdAt: now,
        ),
        StockMovement(
          id: 'm2',
          fairId: 'fair-1',
          bookId: 'book-2',
          quantity: 30,
          movementType: StockMovementType.purchaseIn,
          movementDate: now,
          createdAt: now,
        ),
        StockMovement(
          id: 'm3',
          fairId: 'fair-1',
          bookId: 'book-1',
          quantity: 20,
          movementType: StockMovementType.saleOut,
          movementDate: now,
          createdAt: now,
        ),
      ];

      final book1Stock = InventoryCostCalculator.calculateAvailableStockForBook(
        movements: movements,
        bookId: 'book-1',
      );
      final book2Stock = InventoryCostCalculator.calculateAvailableStockForBook(
        movements: movements,
        bookId: 'book-2',
      );

      expect(book1Stock, equals(30)); // 50 - 20
      expect(book2Stock, equals(30));
    });

    test('canDeductStock prevents negative inventory states', () {
      expect(
        InventoryCostCalculator.canDeductStock(
          currentStock: 15,
          quantityToDeduct: 10,
        ),
        isTrue,
      );
      expect(
        InventoryCostCalculator.canDeductStock(
          currentStock: 15,
          quantityToDeduct: 15,
        ),
        isTrue,
      );
      expect(
        InventoryCostCalculator.canDeductStock(
          currentStock: 15,
          quantityToDeduct: 16,
        ),
        isFalse,
      );
      expect(
        InventoryCostCalculator.canDeductStock(
          currentStock: 0,
          quantityToDeduct: 1,
        ),
        isFalse,
      );
    });

    test('calculateNewWeightedAverageCostPaise blends costs appropriately', () {
      // 10 units @ ₹100 (10000 paise) + 20 units @ ₹130 (13000 paise)
      // Total units: 30
      // Total value: 1,00,000 + 2,60,000 = 3,60,000
      // Average: 3,60,000 / 30 = 12000 paise (₹120)
      final avg = InventoryCostCalculator.calculateNewWeightedAverageCostPaise(
        existingQuantity: 10,
        existingAverageCostPaise: 10000,
        newQuantity: 20,
        newUnitCostPaise: 13000,
      );

      expect(avg, equals(12000));
    });

    test('calculateNewWeightedAverageCostPaise handles edge cases', () {
      // First purchase (no existing stock)
      expect(
        InventoryCostCalculator.calculateNewWeightedAverageCostPaise(
          existingQuantity: 0,
          existingAverageCostPaise: 0,
          newQuantity: 15,
          newUnitCostPaise: 25000,
        ),
        equals(25000),
      );

      // Zero new units added
      expect(
        InventoryCostCalculator.calculateNewWeightedAverageCostPaise(
          existingQuantity: 15,
          existingAverageCostPaise: 25000,
          newQuantity: 0,
          newUnitCostPaise: 0,
        ),
        equals(25000),
      );
    });

    test('calculateBookWeightedAverageCostPaise incorporates previous opening stock', () {
      final now = DateTime(2026, 11, 21);
      final book = Book(
        id: 'book-prev',
        fairId: 'fair-1',
        title: 'Classic Literature',
        author: 'Leo Tolstoy',
        mrpPaise: 50000,
        defaultSellingPricePaise: 35000,
        isPreviousStock: true,
        openingStockQuantity: 10,
        estimatedCostPaise: 20000, // ₹200.00
        createdAt: now,
        updatedAt: now,
      );

      // New batch of 10 copies @ ₹300 (30000 paise)
      final items = [
        const PurchaseItem(
          id: 'pi-1',
          batchId: 'batch-1',
          bookId: 'book-prev',
          quantity: 10,
          unitPurchaseCostPaise: 30000,
          lineTotalPaise: 300000,
        ),
      ];

      final weightedAvg =
          InventoryCostCalculator.calculateBookWeightedAverageCostPaise(
            book: book,
            purchaseItemsForBook: items,
          );

      // (10 * 20000 + 10 * 30000) / 20 = 25000 paise (₹250.00)
      expect(weightedAvg, equals(25000));
    });

    test(
      'analyzePricing computes margins, discounts, and profit correctly',
      () {
        // MRP: ₹500 (50000 paise)
        // Selling Price: ₹400 (40000 paise)
        // Average Cost: ₹250 (25000 paise)
        final analysis = InventoryCostCalculator.analyzePricing(
          mrpPaise: 50000,
          sellingPricePaise: 40000,
          averageCostPaise: 25000,
        );

        expect(analysis.mrpPaise, equals(50000));
        expect(analysis.sellingPricePaise, equals(40000));
        expect(analysis.discountAmountPaise, equals(10000)); // ₹100 discount
        expect(analysis.discountPercentage, equals(20.0)); // 20% discount
        expect(analysis.expectedGrossProfitPaise, equals(15000)); // ₹150 profit
        // Gross margin: (150 / 400) * 100 = 37.5%
        expect(analysis.grossMarginPercentage, equals(37.5));
      },
    );

    test('calculateTotalAcquisitionCostPaise aggregates book costs and ancillary charges', () {
      final total = InventoryCostCalculator.calculateTotalAcquisitionCostPaise(
        totalBookCostPaise: 1500000, // ₹15,000
        additionalChargesPaise: 120000, // ₹1,200 shipping & freight
      );
      expect(total, equals(1620000)); // ₹16,200
    });
  });
}
