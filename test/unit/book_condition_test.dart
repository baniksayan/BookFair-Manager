import 'package:bookfair_manager/features/inventory/domain/entities/book.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BookCondition Unit Tests', () {
    test('all 7 conditions are present in BookCondition enum', () {
      expect(BookCondition.values.length, equals(7));
      expect(
        BookCondition.values,
        containsAll([
          BookCondition.brandNew,
          BookCondition.likeNew,
          BookCondition.veryGood,
          BookCondition.good,
          BookCondition.fair,
          BookCondition.old,
          BookCondition.damaged,
        ]),
      );
    });

    test(
      'defaultDiscountPercentage assigns expected percentage per condition',
      () {
        expect(BookCondition.brandNew.defaultDiscountPercentage, equals(10.0));
        expect(BookCondition.likeNew.defaultDiscountPercentage, equals(20.0));
        expect(BookCondition.veryGood.defaultDiscountPercentage, equals(30.0));
        expect(BookCondition.good.defaultDiscountPercentage, equals(45.0));
        expect(BookCondition.fair.defaultDiscountPercentage, equals(60.0));
        expect(BookCondition.old.defaultDiscountPercentage, equals(70.0));
        expect(BookCondition.damaged.defaultDiscountPercentage, equals(80.0));
      },
    );

    test(
      'calculateSuggestedSellingPricePaise calculates correct prices from MRP',
      () {
        // MRP = ₹1000 (100000 paise)
        const mrpPaise = 100000;

        // Brand New (10% off) -> ₹900
        expect(
          BookCondition.brandNew.calculateSuggestedSellingPricePaise(mrpPaise),
          equals(90000),
        );

        // Like New (20% off) -> ₹800
        expect(
          BookCondition.likeNew.calculateSuggestedSellingPricePaise(mrpPaise),
          equals(80000),
        );

        // Very Good (30% off) -> ₹700
        expect(
          BookCondition.veryGood.calculateSuggestedSellingPricePaise(mrpPaise),
          equals(70000),
        );

        // Good (45% off) -> ₹550
        expect(
          BookCondition.good.calculateSuggestedSellingPricePaise(mrpPaise),
          equals(55000),
        );

        // Fair (60% off) -> ₹400
        expect(
          BookCondition.fair.calculateSuggestedSellingPricePaise(mrpPaise),
          equals(40000),
        );

        // Old / Vintage (70% off) -> ₹300
        expect(
          BookCondition.old.calculateSuggestedSellingPricePaise(mrpPaise),
          equals(30000),
        );

        // Torn / Damaged (80% off) -> ₹200
        expect(
          BookCondition.damaged.calculateSuggestedSellingPricePaise(mrpPaise),
          equals(20000),
        );
      },
    );

    test('fromString accurately parses strings case-insensitively and handles fallback', () {
      expect(
        BookCondition.fromString('Brand New'),
        equals(BookCondition.brandNew),
      );
      expect(
        BookCondition.fromString('likenew'),
        equals(BookCondition.likeNew),
      );
      expect(
        BookCondition.fromString('very good'),
        equals(BookCondition.veryGood),
      );
      expect(BookCondition.fromString('good'), equals(BookCondition.good));
      expect(BookCondition.fromString('FAIR'), equals(BookCondition.fair));
      expect(
        BookCondition.fromString('Old / Vintage'),
        equals(BookCondition.old),
      );
      expect(
        BookCondition.fromString('Torn / Damaged'),
        equals(BookCondition.damaged),
      );
      expect(
        BookCondition.fromString('unknown_condition'),
        equals(BookCondition.good),
      );
      expect(BookCondition.fromString(null), equals(BookCondition.good));
    });
  });
}
