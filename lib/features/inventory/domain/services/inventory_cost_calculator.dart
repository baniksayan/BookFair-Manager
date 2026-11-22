import '../entities/book.dart';
import '../entities/purchase_item.dart';
import '../entities/stock_movement.dart';

/// Calculation result encapsulating book pricing and gross margin analytics.
class BookPricingAnalysis {
  const BookPricingAnalysis({
    required this.mrpPaise,
    required this.sellingPricePaise,
    required this.averageCostPaise,
    required this.discountAmountPaise,
    required this.discountPercentage,
    required this.expectedGrossProfitPaise,
    required this.grossMarginPercentage,
  });

  final int mrpPaise;
  final int sellingPricePaise;
  final int averageCostPaise;
  final int discountAmountPaise;
  final double discountPercentage;
  final int expectedGrossProfitPaise;
  final double grossMarginPercentage;

  double get mrp => mrpPaise / 100.0;
  double get sellingPrice => sellingPricePaise / 100.0;
  double get averageCost => averageCostPaise / 100.0;
  double get discountAmount => discountAmountPaise / 100.0;
  double get expectedGrossProfit => expectedGrossProfitPaise / 100.0;
}

/// Precision mathematical engine for inventory valuation, weighted average costs,
/// stock movement ledger balances, and pricing analytics using integer paise.
abstract final class InventoryCostCalculator {
  /// Calculates physical on-hand available stock by summing ledger deltas.
  static int calculateAvailableStock(List<StockMovement> movements) {
    var stock = 0;
    for (final movement in movements) {
      stock += movement.netDelta;
    }
    return stock;
  }

  /// Calculates available stock specifically for a single [bookId].
  static int calculateAvailableStockForBook({
    required List<StockMovement> movements,
    required String bookId,
  }) {
    var stock = 0;
    for (final movement in movements) {
      if (movement.bookId == bookId) {
        stock += movement.netDelta;
      }
    }
    return stock;
  }

  /// Validates whether a requested stock reduction can be fulfilled without creating
  /// an accidental negative inventory balance.
  static bool canDeductStock({
    required int currentStock,
    required int quantityToDeduct,
  }) {
    if (quantityToDeduct <= 0) return true;
    return (currentStock - quantityToDeduct) >= 0;
  }

  /// Computes new perpetual weighted average unit cost in paise when new stock arrives.
  ///
  /// Formula:
  /// `((Existing Qty * Existing Avg Cost) + (New Qty * New Unit Cost)) / (Existing Qty + New Qty)`
  static int calculateNewWeightedAverageCostPaise({
    required int existingQuantity,
    required int existingAverageCostPaise,
    required int newQuantity,
    required int newUnitCostPaise,
  }) {
    if (existingQuantity <= 0 && newQuantity <= 0) return 0;
    if (existingQuantity <= 0) return newUnitCostPaise;
    if (newQuantity <= 0) return existingAverageCostPaise;

    final totalQuantity = existingQuantity + newQuantity;
    final totalExistingValue =
        existingQuantity.toDouble() * existingAverageCostPaise.toDouble();
    final totalNewValue = newQuantity.toDouble() * newUnitCostPaise.toDouble();

    final newAverage = (totalExistingValue + totalNewValue) / totalQuantity;
    return newAverage.round();
  }

  /// Calculates the weighted average cost for a book from all its purchase line items
  /// and opening stock if applicable.
  static int calculateBookWeightedAverageCostPaise({
    required Book book,
    required List<PurchaseItem> purchaseItemsForBook,
  }) {
    var totalQuantity = 0;
    var totalCostPaise = 0;

    // Include opening stock if previous stock
    if (book.isPreviousStock && book.openingStockQuantity > 0) {
      final unitCost = book.estimatedCostPaise ?? 0;
      totalQuantity += book.openingStockQuantity;
      totalCostPaise += (book.openingStockQuantity * unitCost);
    }

    // Include all purchase items
    for (final item in purchaseItemsForBook) {
      totalQuantity += item.quantity;
      totalCostPaise += item.lineTotalPaise;
    }

    if (totalQuantity <= 0) return 0;
    return (totalCostPaise / totalQuantity).round();
  }

  /// Computes comprehensive commercial pricing, discount, and gross margin analytics.
  static BookPricingAnalysis analyzePricing({
    required int mrpPaise,
    required int sellingPricePaise,
    required int averageCostPaise,
  }) {
    // Discount calculations: MRP - Selling Price
    final discountAmountPaise = mrpPaise > sellingPricePaise
        ? (mrpPaise - sellingPricePaise)
        : 0;

    final discountPercentage = mrpPaise > 0
        ? ((mrpPaise - sellingPricePaise).toDouble() / mrpPaise.toDouble()) *
              100.0
        : 0.0;

    // Expected Gross Profit = Selling Price - Average Purchase Cost
    final expectedGrossProfitPaise = sellingPricePaise - averageCostPaise;

    // Gross Margin % = (Gross Profit / Selling Price) * 100
    final grossMarginPercentage = sellingPricePaise > 0
        ? (expectedGrossProfitPaise.toDouble() / sellingPricePaise.toDouble()) *
              100.0
        : 0.0;

    return BookPricingAnalysis(
      mrpPaise: mrpPaise,
      sellingPricePaise: sellingPricePaise,
      averageCostPaise: averageCostPaise,
      discountAmountPaise: discountAmountPaise,
      discountPercentage: discountPercentage.clamp(0.0, 100.0),
      expectedGrossProfitPaise: expectedGrossProfitPaise,
      grossMarginPercentage: double.parse(
        grossMarginPercentage.toStringAsFixed(2),
      ),
    );
  }

  /// Calculates the sum total cost of a list of purchase line items in paise.
  static int calculateTotalBookCostPaise(List<PurchaseItem> items) {
    var sum = 0;
    for (final item in items) {
      sum += item.lineTotalPaise;
    }
    return sum;
  }

  /// Total Acquisition Cost = (Total Book Cost) + (Additional Incurred Charges)
  static int calculateTotalAcquisitionCostPaise({
    required int totalBookCostPaise,
    required int additionalChargesPaise,
  }) {
    return totalBookCostPaise + additionalChargesPaise;
  }
}
