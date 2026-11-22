import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_badge.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_search_bar.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../book_fairs/domain/entities/book_fair.dart';
import '../../../book_fairs/presentation/view_models/book_fair_providers.dart';
import '../../../inventory/domain/entities/book.dart';
import '../../../inventory/domain/entities/stock_movement.dart';
import '../../../inventory/presentation/view_models/inventory_providers.dart';
import '../view_models/pos_cart_view_model.dart';
import '../widgets/pos_cart_item_tile.dart';
import '../widgets/pos_checkout_dialog.dart';

/// Screen 05: Primary Point-of-Sale Counter Register for stall billing, rapid scanning,
/// cart pricing, and checkout settlement.
class PosSalesCounterScreen extends ConsumerStatefulWidget {
  const PosSalesCounterScreen({super.key, this.fairId});

  final String? fairId;

  @override
  ConsumerState<PosSalesCounterScreen> createState() =>
      _PosSalesCounterScreenState();
}

class _PosSalesCounterScreenState extends ConsumerState<PosSalesCounterScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _receiptDiscountController =
      TextEditingController(text: '0');
  String _searchQuery = '';
  String? _selectedFairId;

  @override
  void initState() {
    super.initState();
    _selectedFairId = widget.fairId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final effectiveFairId = _selectedFairId ?? 'global';
      ref.read(posCartViewModelProvider.notifier).init(fairId: effectiveFairId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _receiptDiscountController.dispose();
    super.dispose();
  }

  void _showManagerOverrideDialog(PosCartItem item) {
    final partnersAsync = _selectedFairId != null
        ? ref.read(partnersForFairStreamProvider(_selectedFairId!))
        : null;
    final partners = partnersAsync?.value ?? [];

    String? selectedPartnerId = partners.isNotEmpty ? partners.first.id : null;
    final reasonController = TextEditingController(
      text: 'Physical copies verified on stall table prior to purchase batch entry',
    );

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final colors = context.colors;
            final textTheme = context.textTheme;

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.security_outlined, color: colors.warning),
                  AppSpacing.gapW8,
                  const Text('Manager Stock Override'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Title: ${item.book.title}',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    AppSpacing.gapH4,
                    Text(
                      'Recorded Available Stock: ${item.availableStock} • Requested: ${item.quantity}',
                      style: textTheme.bodySmall?.copyWith(color: colors.error),
                    ),
                    AppSpacing.gapH12,
                    Text(
                      'Physical books physically present at the stall may be authorized for sale with a recorded manager audit trail.',
                      style: textTheme.bodySmall,
                    ),
                    AppSpacing.gapH12,
                    if (partners.isNotEmpty) ...[
                      AppDropdown<String>(
                        label: 'Authorizing Partner / Manager',
                        value: selectedPartnerId,
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                        ),
                        items: partners
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(p.fullName),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => selectedPartnerId = val),
                      ),
                      AppSpacing.gapH12,
                    ] else ...[
                      AppTextField(
                        label: 'Authorizing Manager Name',
                        hint: 'e.g. Lead Partner',
                        onChanged: (val) => selectedPartnerId = val.trim(),
                      ),
                      AppSpacing.gapH12,
                    ],
                    AppTextField(
                      controller: reasonController,
                      label: 'Justification Reason',
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final authorizer = selectedPartnerId ?? 'manager';
                    final reason = reasonController.text.trim();
                    if (reason.isEmpty) {
                      AppSnackbar.show(
                        context,
                        message: 'A valid override justification reason is required.',
                        variant: AppSnackbarVariant.error,
                      );
                      return;
                    }

                    ref
                        .read(posCartViewModelProvider.notifier)
                        .applyManagerOverride(
                          item.id,
                          authorizerId: authorizer,
                          reason: reason,
                        );
                    Navigator.of(dialogCtx).pop();

                    AppSnackbar.show(
                      context,
                      message:
                          'Manager override authorized for "${item.book.title}".',
                      variant: AppSnackbarVariant.success,
                    );
                  },
                  child: const Text('Authorize Override'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openCheckoutSheet(PosCartState cartState) {
    if (cartState.items.isEmpty) {
      AppSnackbar.show(context, message: 'Cart is empty. Add books to bill.');
      return;
    }
    if (cartState.hasStockWarnings) {
      AppSnackbar.show(
        context,
        message: 'Cart contains out-of-stock titles. Manager authorization required before checkout.',
        variant: AppSnackbarVariant.error,
      );
      return;
    }

    final effectiveFairId = _selectedFairId ?? 'global';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return PosCheckoutDialog(
          fairId: effectiveFairId,
          totalPayablePaise: cartState.totalPayablePaise,
          onCheckoutSuccess: (receipt) {
            context.pushNamed(
              RouteNames.saleReceiptDetails,
              pathParameters: {'id': receipt.id},
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final isTablet = MediaQuery.of(context).size.width >= 900;

    final fairsAsync = ref.watch(bookFairsStreamProvider);
    final booksAsync = ref.watch(booksStreamProvider(_selectedFairId));
    final stockMovementsAsync = ref.watch(stockMovementsStreamProvider(null));
    final cartState = ref.watch(posCartViewModelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Sales Counter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_outlined),
            tooltip: 'Sales Register History',
            onPressed: () => context.pushNamed(RouteNames.salesHistory),
          ),
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: 'Seller Inventory Search',
            onPressed: () => context.pushNamed(RouteNames.sellerBookSearch),
          ),
        ],
      ),
      body: SafeArea(
        child: isTablet
            ? Row(
                children: [
                  // Left panel: Book Catalogue & Search
                  Expanded(
                    flex: 6,
                    child: _buildBookSelectionPanel(
                      colors,
                      textTheme,
                      fairsAsync,
                      booksAsync,
                      stockMovementsAsync,
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  // Right panel: Persistent Cart & Checkout
                  Expanded(
                    flex: 4,
                    child: _buildCartPanel(colors, textTheme, cartState),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(
                    child: _buildBookSelectionPanel(
                      colors,
                      textTheme,
                      fairsAsync,
                      booksAsync,
                      stockMovementsAsync,
                    ),
                  ),
                  _buildMobileCartSummaryBar(colors, textTheme, cartState),
                ],
              ),
      ),
    );
  }

  Widget _buildBookSelectionPanel(
    AppColorScheme colors,
    TextTheme textTheme,
    AsyncValue<List<BookFair>> fairsAsync,
    AsyncValue<List<Book>> booksAsync,
    AsyncValue<List<StockMovement>> stockMovementsAsync,
  ) {
    final movements = stockMovementsAsync.value ?? [];

    return Column(
      children: [
        // Fair selection & Search Header
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Column(
            children: [
              fairsAsync.when(
                data: (fairs) {
                  if (fairs.isEmpty) return const SizedBox.shrink();
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: AppDropdown<String?>(
                      compact: true,
                      value: _selectedFairId,
                      hint: 'Select Stall / Fair Location',
                      sheetTitle: 'Select Fair / Stall Location',
                      sheetSubtitle: 'Choose active fair for sales counter',
                      prefixIcon: const Icon(Icons.store_rounded, size: 20),
                      items: fairs
                          .map(
                            (f) => DropdownMenuItem<String?>(
                              value: f.id,
                              child: Text(f.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedFairId = val);
                        if (val != null) {
                          ref
                              .read(posCartViewModelProvider.notifier)
                              .init(fairId: val);
                        }
                      },
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              AppSearchBar(
                controller: _searchController,
                hint: 'Search book by title, author, or ISBN...',
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim().toLowerCase());
                },
              ),
            ],
          ),
        ),

        // Available Books List
        Expanded(
          child: booksAsync.when(
            loading: () => const Center(child: AppLoadingIndicator()),
            error: (err, _) => Center(child: Text('Error loading books: $err')),
            data: (allBooks) {
              final activeBooks = allBooks.where((b) {
                if (!b.isActive) return false;
                if (_searchQuery.isEmpty) return true;
                return b.title.toLowerCase().contains(_searchQuery) ||
                    b.author.toLowerCase().contains(_searchQuery) ||
                    (b.isbn13 != null && b.isbn13!.contains(_searchQuery)) ||
                    (b.isbn10 != null && b.isbn10!.contains(_searchQuery));
              }).toList();

              if (activeBooks.isEmpty) {
                return AppEmptyState(
                  icon: Icons.search_off_outlined,
                  title: 'No Matching Books',
                  description: _searchQuery.isEmpty
                      ? 'No books available in the catalogue.'
                      : 'No title matched "$_searchQuery".',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                itemCount: activeBooks.length,
                itemBuilder: (context, index) {
                  final book = activeBooks[index];
                  final availableStock = movements
                      .where((m) => m.bookId == book.id)
                      .fold<int>(0, (sum, m) => sum + m.netDelta);

                  return AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s8),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 56,
                          decoration: BoxDecoration(
                            color: colors.surfaceContainer,
                            borderRadius: AppRadius.brSmall,
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 20,
                            color: colors.onSurfaceMuted,
                          ),
                        ),
                        AppSpacing.gapW12,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              AppSpacing.gapH2,
                              Text(
                                '${book.author} • ${book.condition.displayName}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceMuted,
                                ),
                              ),
                              AppSpacing.gapH4,
                              Row(
                                children: [
                                  Text(
                                    CurrencyFormatter.format(
                                      book.defaultSellingPrice,
                                    ),
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colors.primary,
                                    ),
                                  ),
                                  if (book.mrpPaise >
                                      book.defaultSellingPricePaise) ...[
                                    AppSpacing.gapW8,
                                    Text(
                                      CurrencyFormatter.format(book.mrp),
                                      style: textTheme.bodySmall?.copyWith(
                                        decoration: TextDecoration.lineThrough,
                                        color: colors.onSurfaceMuted,
                                      ),
                                    ),
                                  ],
                                  const Spacer(),
                                  AppBadge(
                                    label: availableStock > 0
                                        ? '$availableStock In Stock'
                                        : 'Out of Stock',
                                    variant: availableStock > 0
                                        ? AppBadgeVariant.success
                                        : AppBadgeVariant.error,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapW8,
                        IconButton.filledTonal(
                          icon: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 20,
                          ),
                          tooltip: 'Add to Cart',
                          onPressed: () {
                            ref
                                .read(posCartViewModelProvider.notifier)
                                .addBook(book);
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCartPanel(
    AppColorScheme colors,
    TextTheme textTheme,
    PosCartState cartState,
  ) {
    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined),
                    AppSpacing.gapW8,
                    Text(
                      'Cart Items (${cartState.totalQuantity})',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (cartState.items.isNotEmpty)
                  TextButton(
                    onPressed: () =>
                        ref.read(posCartViewModelProvider.notifier).clearCart(),
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: cartState.items.isEmpty
                ? Center(
                    child: Text(
                      'Cart is empty.\nTap + on catalogue items to add.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    itemCount: cartState.items.length,
                    itemBuilder: (context, index) {
                      final item = cartState.items[index];
                      return PosCartItemTile(
                        item: item,
                        onQuantityChanged: (newQty) {
                          ref
                              .read(posCartViewModelProvider.notifier)
                              .updateQuantity(item.id, newQty);
                        },
                        onRemove: () {
                          ref
                              .read(posCartViewModelProvider.notifier)
                              .removeItem(item.id);
                        },
                        onOverrideRequested: () =>
                            _showManagerOverrideDialog(item),
                      );
                    },
                  ),
          ),

          // Cart bottom checkout summary
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              gradient: colors.cardGradient,
              border: Border(top: BorderSide(color: colors.borderSubtle)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Subtotal:', style: textTheme.bodyMedium),
                    Text(
                      CurrencyFormatter.format(cartState.subtotal),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapH8,
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Receipt Discount (₹):',
                        style: textTheme.bodyMedium,
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      height: 38,
                      child: TextField(
                        controller: _receiptDiscountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.end,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final discRupees = double.tryParse(val) ?? 0;
                          ref
                              .read(posCartViewModelProvider.notifier)
                              .setReceiptDiscount((discRupees * 100).round());
                        },
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapH12,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Payable:',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(cartState.totalPayable),
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapH16,
                AppButton(
                  text: 'Proceed to Checkout',
                  icon: Icons.payment_outlined,
                  onPressed: cartState.items.isNotEmpty
                      ? () => _openCheckoutSheet(cartState)
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCartSummaryBar(
    AppColorScheme colors,
    TextTheme textTheme,
    PosCartState cartState,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        border: Border(top: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${cartState.totalQuantity} items • ${CurrencyFormatter.format(cartState.totalPayable)}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                if (cartState.hasStockWarnings)
                  Text(
                    '⚠️ Out-of-stock items present',
                    style: TextStyle(color: colors.error, fontSize: 11),
                  ),
              ],
            ),
          ),
          AppButton(
            text: 'View Cart (${cartState.items.length})',
            icon: Icons.shopping_cart_outlined,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (ctx) {
                  return SizedBox(
                    height: MediaQuery.of(context).size.height * 0.85,
                    child: _buildCartPanel(colors, textTheme, cartState),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
