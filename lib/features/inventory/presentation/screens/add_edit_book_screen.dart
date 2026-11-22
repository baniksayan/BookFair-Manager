import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_app_bar.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/components/app_switch.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../domain/entities/book.dart';
import '../view_models/book_form_view_model.dart';
import '../view_models/inventory_providers.dart';

/// Screen 03: Add or Edit Book Master Catalogue Form.
class AddEditBookScreen extends ConsumerStatefulWidget {
  const AddEditBookScreen({
    super.key,
    this.bookIdToEdit,
    this.fairId = 'global',
  });

  final String? bookIdToEdit;
  final String fairId;

  @override
  ConsumerState<AddEditBookScreen> createState() => _AddEditBookScreenState();
}

class _AddEditBookScreenState extends ConsumerState<AddEditBookScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _authorController;
  late final TextEditingController _publisherController;
  late final TextEditingController _isbnController;
  late final TextEditingController _genreController;
  late final TextEditingController _mrpController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _conditionNotesController;
  late final TextEditingController _openingStockController;
  late final TextEditingController _estimatedCostController;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _subtitleController = TextEditingController();
    _authorController = TextEditingController();
    _publisherController = TextEditingController();
    _isbnController = TextEditingController();
    _genreController = TextEditingController();
    _mrpController = TextEditingController();
    _sellingPriceController = TextEditingController();
    _descriptionController = TextEditingController();
    _conditionNotesController = TextEditingController();
    _openingStockController = TextEditingController();
    _estimatedCostController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _initForm());
  }

  Future<void> _initForm() async {
    final vm = ref.read(bookFormViewModelProvider.notifier);

    if (widget.bookIdToEdit != null) {
      final repo = ref.read(inventoryRepositoryProvider);
      final book = await repo.getBookById(widget.bookIdToEdit!);
      if (book != null && mounted) {
        vm.loadForEdit(book);
        _titleController.text = book.title;
        _subtitleController.text = book.subtitle ?? '';
        _authorController.text = book.author;
        _publisherController.text = book.publisher;
        _isbnController.text = book.primaryIsbn ?? '';
        _genreController.text = book.genre;
        _mrpController.text = (book.mrpPaise / 100.0).toStringAsFixed(0);
        _sellingPriceController.text = (book.defaultSellingPricePaise / 100.0)
            .toStringAsFixed(0);
        _descriptionController.text = book.description;
        _conditionNotesController.text = book.conditionNotes;
        _openingStockController.text = book.openingStockQuantity.toString();
        _estimatedCostController.text = book.estimatedCostPaise != null
            ? (book.estimatedCostPaise! / 100.0).toStringAsFixed(0)
            : '';
      }
    } else {
      vm.initForCreate(fairId: widget.fairId);
    }

    if (mounted) setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _isbnController.dispose();
    _genreController.dispose();
    _mrpController.dispose();
    _sellingPriceController.dispose();
    _descriptionController.dispose();
    _conditionNotesController.dispose();
    _openingStockController.dispose();
    _estimatedCostController.dispose();
    super.dispose();
  }

  Future<void> _handleIsbnLookup() async {
    final vm = ref.read(bookFormViewModelProvider.notifier);
    final found = await vm.lookupIsbn();

    if (!mounted) return;

    if (found) {
      final state = ref.read(bookFormViewModelProvider);
      _titleController.text = state.title;
      _subtitleController.text = state.subtitle ?? '';
      _authorController.text = state.author;
      _publisherController.text = state.publisher;
      _genreController.text = state.genre;

      AppSnackbar.show(
        context,
        message: 'Book metadata successfully retrieved from ISBN registry.',
        variant: AppSnackbarVariant.success,
      );
    } else {
      AppSnackbar.show(
        context,
        message: 'Could not find metadata for this ISBN. You can enter details manually.',
        variant: AppSnackbarVariant.info,
      );
    }
  }

  Future<void> _handleSubmit() async {
    final vm = ref.read(bookFormViewModelProvider.notifier);
    final isEdit = ref.read(bookFormViewModelProvider).isEditMode;

    final bookId = await vm.submit();

    if (!mounted) return;

    if (bookId != null) {
      AppSnackbar.show(
        context,
        message: isEdit
            ? 'Book catalogue details updated successfully.'
            : 'New book title added to inventory.',
        variant: AppSnackbarVariant.success,
      );
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        if (router.canPop()) {
          router.pop();
        } else {
          context.go('/inventory/books/$bookId');
        }
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      final state = ref.read(bookFormViewModelProvider);
      final generalErr = state.validationErrors['general'];
      AppSnackbar.show(
        context,
        message:
            generalErr ?? 'Please resolve the highlighted validation issues.',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final state = ref.watch(bookFormViewModelProvider);
    final vm = ref.read(bookFormViewModelProvider.notifier);

    final isEdit = state.isEditMode;
    final title = isEdit ? 'Edit Book Details' : 'Add Book to Catalogue';

    return Scaffold(
      appBar: AppAppBar(
        title: title,
        subtitle: 'Bibliographic specifications & pricing',
      ),
      body: !_isInitialized
          ? const Center(
              child: AppLoadingIndicator.large(
                message: 'Preparing book catalogue form...',
              ),
            )
          : SafeArea(
              child: ResponsiveContentContainer(
                child: SingleChildScrollView(
                  padding: AppSpacing.insetAll16,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Section 1: ISBN & Fast Auto-Fill
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ISBN & Quick Lookup',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              AppSpacing.gapH4,
                              Text(
                                'Enter ISBN-10 or ISBN-13 to fetch bibliographic data automatically',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              AppSpacing.gapH16,
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      controller: _isbnController,
                                      label: 'ISBN-10 / ISBN-13',
                                      hint: 'e.g. 9780143452676',
                                      prefixIcon: Icon(
                                        Icons.qr_code_rounded,
                                        color: colors.textSecondary,
                                        size: 20.0,
                                      ),
                                      onChanged: vm.setIsbn,
                                    ),
                                  ),
                                  AppSpacing.gapW12,
                                  AppButton.outlined(
                                    text: 'Lookup',
                                    icon: Icons.search_rounded,
                                    isLoading: state.isLookingUpIsbn,
                                    onPressed: _handleIsbnLookup,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapH16,

                        // Section 2: Bibliographic Core Details
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bibliographic Information',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              AppSpacing.gapH16,
                              AppTextField(
                                controller: _titleController,
                                label: 'Book Title *',
                                hint: 'e.g. The God of Small Things',
                                errorText: state.validationErrors['title'],
                                onChanged: vm.setTitle,
                              ),
                              AppSpacing.gapH16,
                              AppTextField(
                                controller: _subtitleController,
                                label: 'Subtitle (Optional)',
                                hint: 'e.g. A Novel',
                                onChanged: vm.setSubtitle,
                              ),
                              AppSpacing.gapH16,
                              AppTextField(
                                controller: _authorController,
                                label: 'Author *',
                                hint: 'e.g. Arundhati Roy',
                                errorText: state.validationErrors['author'],
                                onChanged: vm.setAuthor,
                              ),
                              AppSpacing.gapH16,
                              AppTextField(
                                controller: _publisherController,
                                label: 'Publisher',
                                hint: 'e.g. Penguin Random House',
                                onChanged: vm.setPublisher,
                              ),
                              AppSpacing.gapH16,
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      controller: _genreController,
                                      label: 'Genre / Category',
                                      hint: 'e.g. Literary Fiction',
                                      onChanged: vm.setGenre,
                                    ),
                                  ),
                                  AppSpacing.gapW12,
                                  Expanded(
                                    child: AppDropdown<String>(
                                      label: 'Language',
                                      value: state.language,
                                      items:
                                          const [
                                            'English',
                                            'Bengali',
                                            'Hindi',
                                            'Tamil',
                                            'Malayalam',
                                            'Marathi',
                                            'Other',
                                          ].map((l) {
                                            return DropdownMenuItem(
                                              value: l,
                                              child: Text(l),
                                            );
                                          }).toList(),
                                      onChanged: (val) {
                                        if (val != null) vm.setLanguage(val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapH16,

                        // Section 3: Condition & Recommended Pricing
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Condition & Commercial Pricing',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              AppSpacing.gapH4,
                              Text(
                                'Recommended discount will automatically update based on book condition',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ),
                              AppSpacing.gapH16,
                              AppDropdown<BookCondition>(
                                label: 'Book Condition',
                                value: state.condition,
                                items: BookCondition.values.map((c) {
                                  return DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      '${c.displayName} (${c.defaultDiscountPercentage.round()}% rec. discount)',
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    vm.setCondition(val);
                                    // Update selling price field text
                                    _sellingPriceController.text = ref
                                        .read(bookFormViewModelProvider)
                                        .sellingPrice;
                                  }
                                },
                              ),
                              AppSpacing.gapH16,
                              Row(
                                children: [
                                  Expanded(
                                    child: AppTextField(
                                      controller: _mrpController,
                                      label: 'MRP (₹) *',
                                      hint: '500',
                                      keyboardType: TextInputType.number,
                                      errorText: state.validationErrors['mrp'],
                                      onChanged: (val) {
                                        vm.setMrp(val);
                                        _sellingPriceController.text = ref
                                            .read(bookFormViewModelProvider)
                                            .sellingPrice;
                                      },
                                    ),
                                  ),
                                  AppSpacing.gapW12,
                                  Expanded(
                                    child: AppTextField(
                                      controller: _sellingPriceController,
                                      label: 'Default Selling Price (₹) *',
                                      hint: '300',
                                      keyboardType: TextInputType.number,
                                      errorText: state
                                          .validationErrors['sellingPrice'],
                                      onChanged: vm.setSellingPrice,
                                    ),
                                  ),
                                ],
                              ),
                              AppSpacing.gapH16,
                              AppTextField(
                                controller: _conditionNotesController,
                                label: 'Condition Specific Notes (Optional)',
                                hint: 'e.g. Mild spine crease, inscription on first page',
                                maxLines: 2,
                                onChanged: vm.setConditionNotes,
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapH16,

                        // Section 4: Previous / Leftover Stock Registration
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Previous / Existing Stock',
                                        style: textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      AppSpacing.gapH2,
                                      Text(
                                        'Register copies on hand prior to new purchase batches',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  AppSwitch(
                                    value: state.isPreviousStock,
                                    onChanged: vm.setIsPreviousStock,
                                  ),
                                ],
                              ),
                              if (state.isPreviousStock) ...[
                                AppSpacing.gapH16,
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        controller: _openingStockController,
                                        label: 'Opening Copies *',
                                        hint: '10',
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          final q = int.tryParse(val) ?? 0;
                                          vm.setOpeningStockQuantity(q);
                                        },
                                      ),
                                    ),
                                    AppSpacing.gapW12,
                                    Expanded(
                                      child: AppTextField(
                                        controller: _estimatedCostController,
                                        label: 'Estimated Unit Cost (₹)',
                                        hint: '150',
                                        keyboardType: TextInputType.number,
                                        onChanged: vm.setEstimatedCost,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        AppSpacing.gapH16,

                        // Section 5: Synopsis / Description
                        AppCard(
                          child: AppTextField(
                            controller: _descriptionController,
                            label: 'Synopsis / Catalogue Notes',
                            hint: 'Brief synopsis, blurb, or stall notes...',
                            maxLines: 3,
                            minLines: 2,
                            onChanged: vm.setDescription,
                          ),
                        ),
                        AppSpacing.gapH24,

                        // Submit Button
                        AppButton(
                          text: isEdit ? 'Save Changes' : 'Register Book Title',
                          icon: Icons.check_circle_outline_rounded,
                          size: AppButtonSize.large,
                          isLoading: state.isSubmitting,
                          onPressed: _handleSubmit,
                        ),
                        AppSpacing.gapH32,
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
