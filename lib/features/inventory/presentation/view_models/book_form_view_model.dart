import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/financial_calculator.dart';
import '../../domain/entities/book.dart';
import '../../domain/services/isbn_lookup_service.dart';
import 'inventory_providers.dart';

class BookFormState {
  const BookFormState({
    this.editingId,
    this.fairId = 'global',
    this.title = '',
    this.subtitle,
    this.author = '',
    this.publisher = '',
    this.isbn10,
    this.isbn13,
    this.genre = 'General',
    this.language = 'English',
    this.description = '',
    this.coverImagePath,
    this.mrp = '',
    this.sellingPrice = '',
    this.condition = BookCondition.brandNew,
    this.conditionNotes = '',
    this.isPreviousStock = false,
    this.openingStockQuantity = 0,
    this.estimatedCost = '',
    this.isSubmitting = false,
    this.isLookingUpIsbn = false,
    this.validationErrors = const {},
  });

  final String? editingId;
  final String fairId;
  final String title;
  final String? subtitle;
  final String author;
  final String publisher;
  final String? isbn10;
  final String? isbn13;
  final String genre;
  final String language;
  final String description;
  final String? coverImagePath;
  final String mrp;
  final String sellingPrice;
  final BookCondition condition;
  final String conditionNotes;
  final bool isPreviousStock;
  final int openingStockQuantity;
  final String estimatedCost;
  final bool isSubmitting;
  final bool isLookingUpIsbn;
  final Map<String, String> validationErrors;

  bool get isEditMode => editingId != null;

  BookFormState copyWith({
    String? editingId,
    String? fairId,
    String? title,
    String? subtitle,
    String? author,
    String? publisher,
    String? isbn10,
    String? isbn13,
    String? genre,
    String? language,
    String? description,
    String? coverImagePath,
    String? mrp,
    String? sellingPrice,
    BookCondition? condition,
    String? conditionNotes,
    bool? isPreviousStock,
    int? openingStockQuantity,
    String? estimatedCost,
    bool? isSubmitting,
    bool? isLookingUpIsbn,
    Map<String, String>? validationErrors,
  }) {
    return BookFormState(
      editingId: editingId ?? this.editingId,
      fairId: fairId ?? this.fairId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      author: author ?? this.author,
      publisher: publisher ?? this.publisher,
      isbn10: isbn10 ?? this.isbn10,
      isbn13: isbn13 ?? this.isbn13,
      genre: genre ?? this.genre,
      language: language ?? this.language,
      description: description ?? this.description,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      mrp: mrp ?? this.mrp,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      condition: condition ?? this.condition,
      conditionNotes: conditionNotes ?? this.conditionNotes,
      isPreviousStock: isPreviousStock ?? this.isPreviousStock,
      openingStockQuantity: openingStockQuantity ?? this.openingStockQuantity,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLookingUpIsbn: isLookingUpIsbn ?? this.isLookingUpIsbn,
      validationErrors: validationErrors ?? this.validationErrors,
    );
  }
}

final bookFormViewModelProvider =
    NotifierProvider<BookFormViewModel, BookFormState>(BookFormViewModel.new);

class BookFormViewModel extends Notifier<BookFormState> {
  static const _uuid = Uuid();
  static const _isbnService = IsbnLookupService();

  @override
  BookFormState build() => const BookFormState();

  void initForCreate({String? fairId}) {
    state = BookFormState(fairId: fairId ?? 'global');
  }

  void loadForEdit(Book book) {
    state = BookFormState(
      editingId: book.id,
      fairId: book.fairId,
      title: book.title,
      subtitle: book.subtitle,
      author: book.author,
      publisher: book.publisher,
      isbn10: book.isbn10,
      isbn13: book.isbn13,
      genre: book.genre,
      language: book.language,
      description: book.description,
      coverImagePath: book.coverImagePath,
      mrp: (book.mrpPaise / 100.0).toStringAsFixed(0),
      sellingPrice: (book.defaultSellingPricePaise / 100.0).toStringAsFixed(0),
      condition: book.condition,
      conditionNotes: book.conditionNotes,
      isPreviousStock: book.isPreviousStock,
      openingStockQuantity: book.openingStockQuantity,
      estimatedCost: book.estimatedCostPaise != null
          ? (book.estimatedCostPaise! / 100.0).toStringAsFixed(0)
          : '',
    );
  }

  void setTitle(String val) => state = state.copyWith(title: val);
  void setSubtitle(String val) => state = state.copyWith(subtitle: val);
  void setAuthor(String val) => state = state.copyWith(author: val);
  void setPublisher(String val) => state = state.copyWith(publisher: val);
  void setIsbn(String val) {
    final cleaned = val.replaceAll(RegExp(r'[^0-9Xx]'), '').trim();
    if (cleaned.length == 13) {
      state = state.copyWith(isbn13: cleaned, isbn10: null);
    } else if (cleaned.length == 10) {
      state = state.copyWith(isbn10: cleaned, isbn13: null);
    } else {
      state = state.copyWith(isbn13: val, isbn10: null);
    }
  }

  void setGenre(String val) => state = state.copyWith(genre: val);
  void setLanguage(String val) => state = state.copyWith(language: val);
  void setDescription(String val) => state = state.copyWith(description: val);
  void setConditionNotes(String val) =>
      state = state.copyWith(conditionNotes: val);
  void setIsPreviousStock(bool val) =>
      state = state.copyWith(isPreviousStock: val);
  void setOpeningStockQuantity(int val) =>
      state = state.copyWith(openingStockQuantity: val);
  void setEstimatedCost(String val) =>
      state = state.copyWith(estimatedCost: val);

  void setCondition(BookCondition condition) {
    state = state.copyWith(condition: condition);
    _recalculateSuggestedPrice();
  }

  void setMrp(String val) {
    state = state.copyWith(mrp: val);
    _recalculateSuggestedPrice();
  }

  void setSellingPrice(String val) {
    state = state.copyWith(sellingPrice: val);
  }

  void _recalculateSuggestedPrice() {
    final mrpPaise = FinancialCalculator.parseToPaise(state.mrp);
    if (mrpPaise > 0) {
      final suggestedPaise = state.condition
          .calculateSuggestedSellingPricePaise(mrpPaise);
      state = state.copyWith(
        sellingPrice: (suggestedPaise / 100.0).toStringAsFixed(0),
      );
    }
  }

  /// Queries OpenLibrary by ISBN and auto-fills bibliographic fields if found.
  Future<bool> lookupIsbn() async {
    final isbn = state.isbn13 ?? state.isbn10;
    if (isbn == null || isbn.trim().isEmpty) return false;

    state = state.copyWith(isLookingUpIsbn: true);

    try {
      final result = await _isbnService.lookupByIsbn(isbn);
      if (result != null) {
        state = state.copyWith(
          title: result.title.isNotEmpty ? result.title : state.title,
          subtitle: result.subtitle ?? state.subtitle,
          author: result.author.isNotEmpty ? result.author : state.author,
          publisher: result.publisher.isNotEmpty
              ? result.publisher
              : state.publisher,
          genre: result.genre.isNotEmpty ? result.genre : state.genre,
          isbn10: result.isbn10 ?? state.isbn10,
          isbn13: result.isbn13 ?? state.isbn13,
          isLookingUpIsbn: false,
        );
        return true;
      }
    } catch (_) {}

    state = state.copyWith(isLookingUpIsbn: false);
    return false;
  }

  bool validate() {
    final errors = <String, String>{};

    if (state.title.trim().isEmpty) {
      errors['title'] = 'Book title is required.';
    }
    if (state.author.trim().isEmpty) {
      errors['author'] = 'Primary author name is required.';
    }

    final mrpPaise = FinancialCalculator.parseToPaise(state.mrp);
    if (mrpPaise <= 0) {
      errors['mrp'] = 'Valid Maximum Retail Price (MRP) is required.';
    }

    final sellingPaise = FinancialCalculator.parseToPaise(state.sellingPrice);
    if (sellingPaise <= 0) {
      errors['sellingPrice'] = 'Valid default selling price is required.';
    }

    state = state.copyWith(validationErrors: errors);
    return errors.isEmpty;
  }

  Future<String?> submit() async {
    if (!validate() || state.isSubmitting) return null;

    state = state.copyWith(isSubmitting: true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final mrpPaise = FinancialCalculator.parseToPaise(state.mrp);
      final sellingPaise = FinancialCalculator.parseToPaise(state.sellingPrice);
      final estimatedPaise =
          state.isPreviousStock && state.estimatedCost.trim().isNotEmpty
          ? FinancialCalculator.parseToPaise(state.estimatedCost)
          : null;

      final now = DateTime.now();

      if (state.isEditMode) {
        final existing = await repo.getBookById(state.editingId!);
        final updatedBook = Book(
          id: state.editingId!,
          fairId: state.fairId,
          title: state.title.trim(),
          subtitle: state.subtitle?.trim(),
          author: state.author.trim(),
          publisher: state.publisher.trim(),
          isbn10: state.isbn10?.trim(),
          isbn13: state.isbn13?.trim(),
          genre: state.genre.trim(),
          language: state.language.trim(),
          description: state.description.trim(),
          coverImagePath: state.coverImagePath,
          mrpPaise: mrpPaise,
          defaultSellingPricePaise: sellingPaise,
          condition: state.condition,
          conditionNotes: state.conditionNotes.trim(),
          isPreviousStock: state.isPreviousStock,
          openingStockQuantity: state.openingStockQuantity,
          estimatedCostPaise: estimatedPaise,
          isActive: true,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        );

        await repo.updateBook(updatedBook);
        state = state.copyWith(isSubmitting: false);
        return updatedBook.id;
      } else {
        final newId = _uuid.v4();
        final newBook = Book(
          id: newId,
          fairId: state.fairId,
          title: state.title.trim(),
          subtitle: state.subtitle?.trim(),
          author: state.author.trim(),
          publisher: state.publisher.trim(),
          isbn10: state.isbn10?.trim(),
          isbn13: state.isbn13?.trim(),
          genre: state.genre.trim(),
          language: state.language.trim(),
          description: state.description.trim(),
          coverImagePath: state.coverImagePath,
          mrpPaise: mrpPaise,
          defaultSellingPricePaise: sellingPaise,
          condition: state.condition,
          conditionNotes: state.conditionNotes.trim(),
          isPreviousStock: state.isPreviousStock,
          openingStockQuantity: state.openingStockQuantity,
          estimatedCostPaise: estimatedPaise,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );

        await repo.addBook(newBook);
        state = state.copyWith(isSubmitting: false);
        return newBook.id;
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        validationErrors: {'general': e.toString()},
      );
      return null;
    }
  }
}
