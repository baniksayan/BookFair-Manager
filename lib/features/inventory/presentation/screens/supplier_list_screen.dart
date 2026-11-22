import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_app_bar.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_empty_state.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/components/palette_switcher_button.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../domain/entities/supplier.dart';
import '../view_models/inventory_providers.dart';
import '../view_models/supplier_view_model.dart';

/// Screen 07: Supplier & Vendor Directory Screen.
class SupplierListScreen extends ConsumerStatefulWidget {
  const SupplierListScreen({super.key});

  @override
  ConsumerState<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends ConsumerState<SupplierListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final suppliersAsync = ref.watch(suppliersStreamProvider);
    final batchesAsync = ref.watch(purchaseBatchesStreamProvider(null));

    final batches = batchesAsync.value ?? [];

    // Aggregate supplier stats
    final batchCountMap = <String, int>{};
    final spendMap = <String, int>{};
    for (final b in batches) {
      if (b.supplierId != null) {
        batchCountMap[b.supplierId!] = (batchCountMap[b.supplierId!] ?? 0) + 1;
        spendMap[b.supplierId!] =
            (spendMap[b.supplierId!] ?? 0) + b.totalAcquisitionCostPaise;
      }
    }

    return Scaffold(
      appBar: const AppAppBar(
        title: 'Suppliers & Vendors',
        subtitle: 'Distributor & Publishing Houses',
        actions: [PaletteSwitcherButton(compact: true), AppSpacing.gapW12],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSupplierSheet(context),
        backgroundColor: colors.accent,
        foregroundColor: colors.primaryDark,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Add Supplier',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContentContainer(
          child: Column(
            children: [
              _buildSearchBar(context),
              Expanded(
                child: suppliersAsync.when(
                  loading: () => const Center(
                    child: AppLoadingIndicator.large(
                      message: 'Loading suppliers directory...',
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text(
                      'Failed to load suppliers: $err',
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                  data: (suppliers) {
                    final query = _searchController.text.trim().toLowerCase();
                    final filtered = suppliers.where((s) {
                      final name = s.name.toLowerCase();
                      final phone = (s.contactNumber ?? '').toLowerCase();
                      final email = (s.email ?? '').toLowerCase();
                      return query.isEmpty ||
                          name.contains(query) ||
                          phone.contains(query) ||
                          email.contains(query);
                    }).toList();

                    if (suppliers.isEmpty) {
                      return _buildEmptyState(context);
                    }

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_search_rounded,
                              size: 48,
                              color: colors.textSecondary,
                            ),
                            AppSpacing.gapH12,
                            Text(
                              'No matching suppliers found',
                              style: textTheme.titleMedium?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            AppSpacing.gapH4,
                            Text(
                              'Try adjusting your search criteria.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => AppSpacing.gapH12,
                      itemBuilder: (context, index) {
                        final supplier = filtered[index];
                        final batchCount = batchCountMap[supplier.id] ?? 0;
                        final totalSpendPaise = spendMap[supplier.id] ?? 0;

                        return _buildSupplierCard(
                          context,
                          supplier: supplier,
                          batchCount: batchCount,
                          totalSpendPaise: totalSpendPaise,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colors.surface,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search by supplier name, phone, email...',
          prefixIcon: Icon(Icons.search, color: colors.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: colors.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: colors.surfaceSecondary,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: AppRadius.allMedium,
            borderSide: BorderSide(color: colors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.allMedium,
            borderSide: BorderSide(color: colors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.allMedium,
            borderSide: BorderSide(color: colors.accent, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSupplierCard(
    BuildContext context, {
    required Supplier supplier,
    required int batchCount,
    required int totalSpendPaise,
  }) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return AppCard.interactive(
      onTap: () => _openSupplierSheet(context, supplier: supplier),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: colors.surfaceSecondary,
                      radius: 20,
                      child: Text(
                        supplier.name.isNotEmpty
                            ? supplier.name[0].toUpperCase()
                            : 'S',
                        style: TextStyle(
                          color: colors.accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    AppSpacing.gapW12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier.name,
                            style: textTheme.titleMedium?.copyWith(
                              fontFamily: 'Georgia',
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (supplier.address != null &&
                              supplier.address!.isNotEmpty)
                            Text(
                              supplier.address!,
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: colors.textSecondary),
                onSelected: (val) {
                  if (val == 'edit') {
                    _openSupplierSheet(context, supplier: supplier);
                  } else if (val == 'delete') {
                    _confirmDelete(context, supplier);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18),
                        AppSpacing.gapW8,
                        Text('Edit Supplier'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: colors.error,
                        ),
                        AppSpacing.gapW8,
                        Text(
                          'Delete Supplier',
                          style: TextStyle(color: colors.error),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if ((supplier.contactNumber != null &&
                  supplier.contactNumber!.isNotEmpty) ||
              (supplier.email != null && supplier.email!.isNotEmpty)) ...[
            AppSpacing.gapH10,
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if (supplier.contactNumber != null &&
                    supplier.contactNumber!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      AppSpacing.gapW4,
                      Text(
                        supplier.contactNumber!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                if (supplier.email != null && supplier.email!.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.email_outlined,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      AppSpacing.gapW4,
                      Text(
                        supplier.email!,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          AppSpacing.gapH12,
          Divider(color: colors.divider, height: 1),
          AppSpacing.gapH10,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$batchCount procurement batch${batchCount == 1 ? '' : 'es'}',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Total Spend: ${CurrencyFormatter.format(totalSpendPaise / 100.0)}',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openSupplierSheet(BuildContext context, {Supplier? supplier}) {
    final vm = ref.read(supplierViewModelProvider.notifier);
    if (supplier != null) {
      vm.loadForEdit(supplier);
    } else {
      vm.reset();
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _SupplierFormSheet(editingSupplier: supplier),
    );
  }

  void _confirmDelete(BuildContext context, Supplier supplier) {
    final colors = context.colors;
    showDialog<void>(
      context: context,
      builder: (dlgContext) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Delete Supplier?',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to remove "${supplier.name}"? Existing purchase history referencing this vendor will be preserved.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgContext).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.surface,
            ),
            onPressed: () async {
              Navigator.of(dlgContext).pop();
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final success = await ref
                  .read(supplierViewModelProvider.notifier)
                  .deleteSupplier(supplier.id);
              if (mounted && success) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('Supplier "${supplier.name}" deleted.'),
                    backgroundColor: colors.primaryDark,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppEmptyState(
      icon: Icons.people_outline_rounded,
      title: 'No Suppliers Registered',
      description: 'Add book distributors, publishing houses, and vendors to streamline procurement tracking.',
      actionLabel: 'Add First Supplier',
      onAction: () => _openSupplierSheet(context),
    );
  }
}

class _SupplierFormSheet extends ConsumerStatefulWidget {
  const _SupplierFormSheet({this.editingSupplier});

  final Supplier? editingSupplier;

  @override
  ConsumerState<_SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends ConsumerState<_SupplierFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final supplier = widget.editingSupplier;
    _nameController = TextEditingController(text: supplier?.name ?? '');
    _phoneController = TextEditingController(
      text: supplier?.contactNumber ?? '',
    );
    _emailController = TextEditingController(text: supplier?.email ?? '');
    _addressController = TextEditingController(text: supplier?.address ?? '');
    _notesController = TextEditingController(text: supplier?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final state = ref.watch(supplierViewModelProvider);
    final vm = ref.read(supplierViewModelProvider.notifier);
    final isEdit = widget.editingSupplier != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Material(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: AppRadius.allFull,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEdit ? 'Edit Supplier' : 'Add New Supplier',
                      style: textTheme.titleMedium?.copyWith(
                        fontFamily: 'Georgia',
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(color: colors.divider, height: 1),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (state.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.1),
                          borderRadius: AppRadius.allMedium,
                          border: Border.all(color: colors.error),
                        ),
                        child: Text(
                          state.errorMessage!,
                          style: TextStyle(color: colors.error),
                        ),
                      ),
                      AppSpacing.gapH16,
                    ],
                    AppTextField(
                      label: 'Supplier / Vendor Name *',
                      hint: 'e.g. Anand Publishers, Penguin India',
                      controller: _nameController,
                      errorText: state.validationErrors['name'],
                      onChanged: vm.setName,
                    ),
                    AppSpacing.gapH14,
                    AppTextField(
                      label: 'Contact Number',
                      hint: 'e.g. +91 98765 43210',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      onChanged: vm.setContactNumber,
                    ),
                    AppSpacing.gapH14,
                    AppTextField(
                      label: 'Email Address',
                      hint: 'e.g. orders@publisher.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: vm.setEmail,
                    ),
                    AppSpacing.gapH14,
                    AppTextField(
                      label: 'Address / Warehouse Location',
                      hint: 'e.g. College Street, Kolkata',
                      controller: _addressController,
                      onChanged: vm.setAddress,
                    ),
                    AppSpacing.gapH14,
                    AppTextField(
                      label: 'Payment Terms / Notes',
                      hint: 'e.g. 30-day net credit, 40% margin on bulk trade',
                      controller: _notesController,
                      maxLines: 2,
                      onChanged: vm.setNotes,
                    ),
                    AppSpacing.gapH24,
                    AppButton(
                      text: isEdit ? 'Update Supplier' : 'Save Supplier',
                      isLoading: state.isSubmitting,
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final success = await vm.submit();
                        if (mounted && success) {
                          nav.pop();
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit
                                    ? 'Supplier updated successfully.'
                                    : 'Supplier added successfully.',
                              ),
                              backgroundColor: colors.primaryDark,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
