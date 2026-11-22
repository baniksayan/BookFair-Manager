import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/components/app_app_bar.dart';
import '../../../../core/components/app_button.dart';
import '../../../../core/components/app_card.dart';
import '../../../../core/components/app_dropdown.dart';
import '../../../../core/components/app_loading.dart';
import '../../../../core/components/app_photon_autocomplete_field.dart';
import '../../../../core/components/app_snackbar.dart';
import '../../../../core/components/app_text_field.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/services/geocoding/photon_geocoding_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../view_models/book_fair_providers.dart';
import '../view_models/create_book_fair_view_model.dart';

/// Form screen supporting both Creation of a new fair and Editing of an existing fair.
class CreateBookFairScreen extends ConsumerStatefulWidget {
  const CreateBookFairScreen({super.key, this.fairId});

  final String? fairId;

  @override
  ConsumerState<CreateBookFairScreen> createState() =>
      _CreateBookFairScreenState();
}

class _CreateBookFairScreenState extends ConsumerState<CreateBookFairScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _budgetController;
  late final TextEditingController _investmentController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _locationController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _budgetController = TextEditingController();
    _investmentController = TextEditingController();
    _descriptionController = TextEditingController();
    _notesController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeForm());
  }

  Future<void> _initializeForm() async {
    final vm = ref.read(createBookFairViewModelProvider.notifier);

    if (widget.fairId != null) {
      // Edit Mode: fetch fair from repo
      final repo = ref.read(bookFairRepositoryProvider);
      final fair = await repo.getBookFairById(widget.fairId!);
      if (fair != null && mounted) {
        vm.loadForEdit(fair);
        _syncControllersWithState();
      }
    } else {
      // Create Mode: check if draft exists in Hive
      final repo = ref.read(bookFairRepositoryProvider);
      final draft = await repo.getDraft();
      if (draft != null && mounted) {
        vm.loadForEdit(draft);
        _syncControllersWithState();
      } else {
        vm.initForCreate();
      }
    }

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  void _syncControllersWithState() {
    final state = ref.read(createBookFairViewModelProvider);
    _nameController.text = state.name;
    _locationController.text = state.location;
    _cityController.text = state.city;
    _stateController.text = state.stateProvince;
    _budgetController.text = state.estimatedBudget;
    _investmentController.text = state.initialInvestment;
    _descriptionController.text = state.description;
    _notesController.text = state.operationalNotes;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _budgetController.dispose();
    _investmentController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final state = ref.read(createBookFairViewModelProvider);
    final initialDate = state.startDate ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) =>
          Theme(data: Theme.of(context), child: child!),
    );

    if (picked != null) {
      ref.read(createBookFairViewModelProvider.notifier).setStartDate(picked);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final state = ref.read(createBookFairViewModelProvider);
    final initialDate =
        state.endDate ??
        state.startDate ??
        DateTime.now().add(const Duration(days: 7));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: state.startDate ?? DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) =>
          Theme(data: Theme.of(context), child: child!),
    );

    if (picked != null) {
      ref.read(createBookFairViewModelProvider.notifier).setEndDate(picked);
    }
  }

  Future<void> _handleSaveDraft() async {
    final vm = ref.read(createBookFairViewModelProvider.notifier);
    await vm.saveDraft();
    if (!mounted) return;

    AppSnackbar.show(
      context,
      message: 'Draft saved to local storage.',
      variant: AppSnackbarVariant.success,
    );
  }

  Future<void> _handleSubmit() async {
    final vm = ref.read(createBookFairViewModelProvider.notifier);
    final isEdit = ref.read(createBookFairViewModelProvider).isEditMode;

    final fairId = await vm.submit();

    if (!mounted) return;

    if (fairId != null) {
      AppSnackbar.show(
        context,
        message: isEdit
            ? 'Book fair details updated successfully.'
            : 'Book fair established and stored in local database.',
        variant: AppSnackbarVariant.success,
      );

      // Navigate to details of the created/edited fair
      context.pushReplacement('/book-fairs/$fairId');
    } else {
      AppSnackbar.show(
        context,
        message: 'Please resolve form validation issues before submitting.',
        variant: AppSnackbarVariant.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final state = ref.watch(createBookFairViewModelProvider);
    final vm = ref.read(createBookFairViewModelProvider.notifier);

    final isEdit = state.isEditMode;
    final title = isEdit ? 'Edit Book Fair' : AppStrings.createFairTitle;

    return Scaffold(
      appBar: AppAppBar(
        title: title,
        subtitle: isEdit
            ? 'Update Fair Specifications'
            : 'Establish Fair Exhibition Workspace',
      ),
      body: !_isInitialized
          ? const Center(
              child: AppLoadingIndicator.large(
                message: 'Preparing exhibition form...',
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
                        // Header description banner
                        Container(
                          padding: AppSpacing.insetAll16,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: AppRadius.brLarge,
                            border: Border.all(
                              color: colors.border,
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                isEdit
                                    ? Icons.edit_note_rounded
                                    : Icons.menu_book_rounded,
                                color: colors.primary,
                                size: 24.0,
                              ),
                              AppSpacing.gapW12,
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: textTheme.titleMedium?.copyWith(
                                        fontFamily: 'Georgia',
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    AppSpacing.gapH4,
                                    Text(
                                      isEdit
                                          ? 'Modify dates, budgets, and operational parameters for this book stall.'
                                          : AppStrings.createFairSubtitle,
                                      style: textTheme.bodySmall?.copyWith(
                                        color: colors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapH24,

                        // Section 1: General Info
                        _buildSectionHeader(
                          context,
                          AppStrings.sectionGeneralInfo,
                          Icons.storefront_outlined,
                        ),
                        AppSpacing.gapH12,
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppTextField(
                                controller: _nameController,
                                label: AppStrings.fieldFairName,
                                hint: AppStrings.fieldFairNameHint,
                                prefixIcon: Icon(
                                  Icons.drive_file_rename_outline_rounded,
                                  color: colors.textSecondary,
                                  size: 20.0,
                                ),
                                errorText: state.validationErrors['name'],
                                onChanged: vm.setName,
                              ),
                              AppSpacing.gapH16,
                              AppPhotonAutocompleteField(
                                controller: _locationController,
                                label: AppStrings.fieldLocation,
                                hint: AppStrings.fieldLocationHint,
                                prefixIcon: Icon(
                                  Icons.location_on_outlined,
                                  color: colors.textSecondary,
                                  size: 20.0,
                                ),
                                errorText: state.validationErrors['location'],
                                searchType: PhotonSearchType.venue,
                                latitude: state.latitude,
                                longitude: state.longitude,
                                onChanged: vm.setLocation,
                                onPlaceSelected: (place) {
                                  _locationController.text =
                                      place.venueFormattedName;
                                  vm.onVenueSelected(place);

                                  // Auto-populate city if field is currently empty
                                  if (_cityController.text.trim().isEmpty &&
                                      place.city != null &&
                                      place.city!.isNotEmpty) {
                                    _cityController.text = place.city!;
                                    vm.setCity(place.city!);
                                  }
                                  // Auto-populate state if field is currently empty
                                  if (_stateController.text.trim().isEmpty &&
                                      place.state != null &&
                                      place.state!.isNotEmpty) {
                                    _stateController.text = place.state!;
                                    vm.setStateProvince(place.state!);
                                  }
                                },
                              ),
                              AppSpacing.gapH16,
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 450;
                                  final cityField = AppPhotonAutocompleteField(
                                    controller: _cityController,
                                    label: 'City',
                                    hint: 'e.g. Kolkata',
                                    prefixIcon: Icon(
                                      Icons.location_city_rounded,
                                      color: colors.textSecondary,
                                      size: 20.0,
                                    ),
                                    searchType: PhotonSearchType.city,
                                    onChanged: vm.setCity,
                                    onPlaceSelected: (place) {
                                      _cityController.text =
                                          place.cityFormattedName;
                                      vm.onCitySelected(place);

                                      // Automatically populate State / Province if available in API response
                                      if (place.state != null &&
                                          place.state!.isNotEmpty) {
                                        _stateController.text = place.state!;
                                        vm.setStateProvince(place.state!);
                                      }
                                    },
                                  );

                                  final stateField = AppPhotonAutocompleteField(
                                    controller: _stateController,
                                    label: 'State / Province',
                                    hint: 'e.g. West Bengal',
                                    prefixIcon: Icon(
                                      Icons.map_outlined,
                                      color: colors.textSecondary,
                                      size: 20.0,
                                    ),
                                    searchType: PhotonSearchType.state,
                                    onChanged: vm.setStateProvince,
                                    onPlaceSelected: (place) {
                                      _stateController.text =
                                          place.stateFormattedName;
                                      vm.onStateSelected(place);
                                    },
                                  );

                                  if (isWide) {
                                    return Row(
                                      children: [
                                        Expanded(child: cityField),
                                        AppSpacing.gapW16,
                                        Expanded(child: stateField),
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
                                      cityField,
                                      AppSpacing.gapH16,
                                      stateField,
                                    ],
                                  );
                                },
                              ),
                              AppSpacing.gapH16,
                              AppTextField(
                                controller: _descriptionController,
                                label: 'Description',
                                hint: 'Brief summary of the stall setup, targeted literary genres, and expected audience...',
                                maxLines: 3,
                                minLines: 2,
                                onChanged: vm.setDescription,
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapH24,

                        // Section 2: Exhibition Schedule
                        _buildSectionHeader(
                          context,
                          AppStrings.sectionSchedule,
                          Icons.calendar_today_outlined,
                        ),
                        AppSpacing.gapH12,
                        AppCard(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isWide = constraints.maxWidth > 450;
                              final startField = GestureDetector(
                                onTap: () => _selectStartDate(context),
                                child: AbsorbPointer(
                                  child: AppTextField(
                                    key: ValueKey(state.startDate),
                                    label: AppStrings.fieldStartDate,
                                    hint: state.startDate != null
                                        ? DateFormatter.formatDisplay(
                                            state.startDate!,
                                          )
                                        : AppStrings.fieldStartDateHint,
                                    prefixIcon: Icon(
                                      Icons.date_range_rounded,
                                      color: colors.textSecondary,
                                      size: 20.0,
                                    ),
                                    errorText:
                                        state.validationErrors['startDate'],
                                    readOnly: true,
                                  ),
                                ),
                              );

                              final endField = GestureDetector(
                                onTap: () => _selectEndDate(context),
                                child: AbsorbPointer(
                                  child: AppTextField(
                                    key: ValueKey(state.endDate),
                                    label: AppStrings.fieldEndDate,
                                    hint: state.endDate != null
                                        ? DateFormatter.formatDisplay(
                                            state.endDate!,
                                          )
                                        : AppStrings.fieldEndDateHint,
                                    prefixIcon: Icon(
                                      Icons.event_available_rounded,
                                      color: colors.textSecondary,
                                      size: 20.0,
                                    ),
                                    errorText:
                                        state.validationErrors['endDate'],
                                    readOnly: true,
                                  ),
                                ),
                              );

                              if (isWide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: startField),
                                    AppSpacing.gapW16,
                                    Expanded(child: endField),
                                  ],
                                );
                              }

                              return Column(
                                children: [
                                  startField,
                                  AppSpacing.gapH16,
                                  endField,
                                ],
                              );
                            },
                          ),
                        ),
                        AppSpacing.gapH24,

                        // Section 3: Financial & Partnership Setup
                        _buildSectionHeader(
                          context,
                          AppStrings.sectionFinances,
                          Icons.account_balance_outlined,
                        ),
                        AppSpacing.gapH12,
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 450;
                                  final budgetField = AppTextField(
                                    controller: _budgetController,
                                    label: AppStrings.fieldEstimatedBudget,
                                    hint: AppStrings.fieldEstimatedBudgetHint,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    prefixIcon: Icon(
                                      Icons.currency_rupee_rounded,
                                      color: colors.textSecondary,
                                      size: 20.0,
                                    ),
                                    errorText: state
                                        .validationErrors['estimatedBudget'],
                                    onChanged: vm.setEstimatedBudget,
                                  );

                                  final investmentField = AppTextField(
                                    controller: _investmentController,
                                    label: AppStrings.fieldInitialInvestment,
                                    hint: AppStrings.fieldInitialInvestmentHint,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    prefixIcon: Icon(
                                      Icons.savings_outlined,
                                      color: colors.textSecondary,
                                      size: 20.0,
                                    ),
                                    errorText: state
                                        .validationErrors['initialInvestment'],
                                    onChanged: vm.setInitialInvestment,
                                  );

                                  if (isWide) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: budgetField),
                                        AppSpacing.gapW16,
                                        Expanded(child: investmentField),
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
                                      budgetField,
                                      AppSpacing.gapH16,
                                      investmentField,
                                    ],
                                  );
                                },
                              ),
                              AppSpacing.gapH16,
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 450;
                                  final partnerCountDropdown = AppDropdown<int>(
                                    label: AppStrings.fieldNumPartners,
                                    value: state.numPartners,
                                    prefixIcon: Icon(
                                      Icons.groups_outlined,
                                      color: colors.textSecondary,
                                      size: 20.0,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 1,
                                        child: Text(
                                          'Sole Proprietor (1 Organizer)',
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 2,
                                        child: Text('2 Partners'),
                                      ),
                                      DropdownMenuItem(
                                        value: 3,
                                        child: Text('3 Partners'),
                                      ),
                                      DropdownMenuItem(
                                        value: 4,
                                        child: Text('4 Partners'),
                                      ),
                                      DropdownMenuItem(
                                        value: 5,
                                        child: Text('5+ Partners / Syndicate'),
                                      ),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        vm.setNumPartners(val);
                                      }
                                    },
                                  );

                                  final partnershipTypeDropdown =
                                      AppDropdown<String>(
                                        label: 'Partnership Type',
                                        value: state.partnershipType,
                                        prefixIcon: Icon(
                                          Icons.handshake_outlined,
                                          color: colors.textSecondary,
                                          size: 20.0,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'Sole Proprietorship',
                                            child: Text('Sole Proprietorship'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'Equal Partnership',
                                            child: Text('Equal Partnership'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'Equity Ratio',
                                            child: Text('Equity / Ratio Based'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'Silent Investor Syndicate',
                                            child: Text(
                                              'Silent Investor Syndicate',
                                            ),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            vm.setPartnershipType(val);
                                          }
                                        },
                                      );

                                  if (isWide) {
                                    return Row(
                                      children: [
                                        Expanded(child: partnerCountDropdown),
                                        AppSpacing.gapW16,
                                        Expanded(
                                          child: partnershipTypeDropdown,
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
                                      partnerCountDropdown,
                                      AppSpacing.gapH16,
                                      partnershipTypeDropdown,
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapH24,

                        // Section 4: Operational Notes
                        _buildSectionHeader(
                          context,
                          AppStrings.sectionNotes,
                          Icons.notes_rounded,
                        ),
                        AppSpacing.gapH12,
                        AppCard(
                          child: AppTextField(
                            controller: _notesController,
                            label: AppStrings.fieldDescription,
                            hint: AppStrings.fieldDescriptionHint,
                            maxLines: 4,
                            minLines: 3,
                            onChanged: vm.setOperationalNotes,
                          ),
                        ),
                        AppSpacing.gapH32,

                        // Form Action Buttons
                        Row(
                          children: [
                            if (!isEdit) ...[
                              Expanded(
                                child: AppButton.outlined(
                                  text: AppStrings.btnSaveDraft,
                                  onPressed: _handleSaveDraft,
                                  size: AppButtonSize.medium,
                                ),
                              ),
                              AppSpacing.gapW12,
                            ],
                            Expanded(
                              child: AppButton(
                                text: isEdit
                                    ? 'Update Book Fair'
                                    : AppStrings.btnCreateFair,
                                onPressed: _handleSubmit,
                                isLoading: state.isSubmitting,
                                size: AppButtonSize.medium,
                                icon: Icons.check_circle_outline_rounded,
                              ),
                            ),
                          ],
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

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Row(
      children: [
        Icon(icon, size: 18.0, color: colors.primary),
        AppSpacing.gapW8,
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontFamily: 'Georgia',
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
