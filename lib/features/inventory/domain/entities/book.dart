import 'package:flutter/foundation.dart';

/// Condition classification for books in stock with recommended discounting guidelines.
enum BookCondition {
  brandNew,
  likeNew,
  veryGood,
  good,
  fair,
  old,
  damaged;

  String get displayName {
    switch (this) {
      case BookCondition.brandNew:
        return 'Brand New';
      case BookCondition.likeNew:
        return 'Like New';
      case BookCondition.veryGood:
        return 'Very Good';
      case BookCondition.good:
        return 'Good';
      case BookCondition.fair:
        return 'Fair';
      case BookCondition.old:
        return 'Old / Vintage';
      case BookCondition.damaged:
        return 'Torn / Damaged';
    }
  }

  String get description {
    switch (this) {
      case BookCondition.brandNew:
        return 'Mint condition, pristine unread copy with flawless binding and pages.';
      case BookCondition.likeNew:
        return 'Near-mint condition with negligible signs of handling or shelf life.';
      case BookCondition.veryGood:
        return 'Gently read, intact spine, clean pages with no major defacements.';
      case BookCondition.good:
        return 'Well-read copy with typical shelf wear, solid binding, fully readable.';
      case BookCondition.fair:
        return 'Considerable reading wear, possible cover creasing, complete intact text.';
      case BookCondition.old:
        return 'Vintage or aged edition with page yellowing/toning, collectible appeal.';
      case BookCondition.damaged:
        return 'Noticeable damage, water stains, or torn jacket. Manual price override suggested.';
    }
  }

  /// Default suggested discount percentage recommendation.
  double get defaultDiscountPercentage {
    switch (this) {
      case BookCondition.brandNew:
        return 10.0;
      case BookCondition.likeNew:
        return 20.0;
      case BookCondition.veryGood:
        return 30.0;
      case BookCondition.good:
        return 45.0;
      case BookCondition.fair:
        return 60.0;
      case BookCondition.old:
        return 70.0;
      case BookCondition.damaged:
        return 80.0;
    }
  }

  /// Calculates the suggested selling price in paise given the MRP in paise.
  int calculateSuggestedSellingPricePaise(int mrpPaise) {
    if (mrpPaise <= 0) return 0;
    final discountFactor = (100.0 - defaultDiscountPercentage) / 100.0;
    return (mrpPaise * discountFactor).round();
  }

  static BookCondition fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'brandnew':
      case 'brand new':
        return BookCondition.brandNew;
      case 'likenew':
      case 'like new':
        return BookCondition.likeNew;
      case 'verygood':
      case 'very good':
        return BookCondition.veryGood;
      case 'good':
        return BookCondition.good;
      case 'fair':
        return BookCondition.fair;
      case 'old':
      case 'old / vintage':
        return BookCondition.old;
      case 'damaged':
      case 'torn / damaged':
        return BookCondition.damaged;
      default:
        return BookCondition.good;
    }
  }
}

/// Domain entity representing a book title in the master catalog and fair inventory.
@immutable
class Book {
  const Book({
    required this.id,
    required this.fairId,
    required this.title,
    this.subtitle,
    required this.author,
    this.additionalAuthors = const [],
    this.publisher = '',
    this.isbn10,
    this.isbn13,
    this.genre = 'General',
    this.language = 'English',
    this.description = '',
    this.coverImagePath,
    this.coverImageSource,
    required this.mrpPaise,
    required this.defaultSellingPricePaise,
    this.condition = BookCondition.brandNew,
    this.conditionNotes = '',
    this.isPreviousStock = false,
    this.openingStockQuantity = 0,
    this.estimatedCostPaise,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// Associated book fair identifier, or 'global' for cross-fair catalogue reference.
  final String fairId;

  final String title;
  final String? subtitle;
  final String author;
  final List<String> additionalAuthors;
  final String publisher;
  final String? isbn10;
  final String? isbn13;
  final String genre;
  final String language;
  final String description;
  final String? coverImagePath;
  final String? coverImageSource;

  /// Maximum Retail Price in integer paise (1 INR = 100 paise).
  final int mrpPaise;

  /// Default listing selling price in integer paise.
  final int defaultSellingPricePaise;

  final BookCondition condition;
  final String conditionNotes;

  /// Indicates if this stock originated from previously owned / leftover stock.
  final bool isPreviousStock;

  /// Initial physical copy count if registered as opening stock.
  final int openingStockQuantity;

  /// Estimated acquisition cost in paise if original acquisition invoice was unavailable.
  final int? estimatedCostPaise;

  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // --- Convenience Currency Getters ---
  double get mrp => mrpPaise / 100.0;
  double get defaultSellingPrice => defaultSellingPricePaise / 100.0;
  double? get estimatedCost =>
      estimatedCostPaise != null ? estimatedCostPaise! / 100.0 : null;

  /// Returns the preferred ISBN identifier (ISBN-13 preferred, then ISBN-10).
  String? get primaryIsbn => isbn13?.isNotEmpty == true ? isbn13 : isbn10;

  Book copyWith({
    String? id,
    String? fairId,
    String? title,
    String? subtitle,
    String? author,
    List<String>? additionalAuthors,
    String? publisher,
    String? isbn10,
    String? isbn13,
    String? genre,
    String? language,
    String? description,
    String? coverImagePath,
    String? coverImageSource,
    int? mrpPaise,
    int? defaultSellingPricePaise,
    BookCondition? condition,
    String? conditionNotes,
    bool? isPreviousStock,
    int? openingStockQuantity,
    int? estimatedCostPaise,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Book(
      id: id ?? this.id,
      fairId: fairId ?? this.fairId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      author: author ?? this.author,
      additionalAuthors: additionalAuthors ?? this.additionalAuthors,
      publisher: publisher ?? this.publisher,
      isbn10: isbn10 ?? this.isbn10,
      isbn13: isbn13 ?? this.isbn13,
      genre: genre ?? this.genre,
      language: language ?? this.language,
      description: description ?? this.description,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      coverImageSource: coverImageSource ?? this.coverImageSource,
      mrpPaise: mrpPaise ?? this.mrpPaise,
      defaultSellingPricePaise:
          defaultSellingPricePaise ?? this.defaultSellingPricePaise,
      condition: condition ?? this.condition,
      conditionNotes: conditionNotes ?? this.conditionNotes,
      isPreviousStock: isPreviousStock ?? this.isPreviousStock,
      openingStockQuantity: openingStockQuantity ?? this.openingStockQuantity,
      estimatedCostPaise: estimatedCostPaise ?? this.estimatedCostPaise,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Book && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
