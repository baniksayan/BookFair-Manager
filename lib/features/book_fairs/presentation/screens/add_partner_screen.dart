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
import '../../../../core/components/app_text_field.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/utils/responsive_layout.dart';
import '../../domain/entities/partner.dart';
import '../view_models/book_fair_providers.dart';
import '../view_models/partner_management_view_model.dart';

/// Form screen to add a new partner or update an existing partner for a fair.
class AddPartnerScreen extends ConsumerStatefulWidget {
  const AddPartnerScreen({
    super.key,
    required this.fairId,
    this.partnerIdToEdit,
  });

  final String fairId;
  final String? partnerIdToEdit;

  @override
  ConsumerState<AddPartnerScreen> createState() => _AddPartnerScreenState();
}

class _AddPartnerScreenState extends ConsumerState<AddPartnerScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _equityController;
  late final TextEditingController _notesController;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _equityController = TextEditingController();
    _notesController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) => _initForm());
  }

  Future<void> _initForm() async {
    final vm = ref.read(partnerFormViewModelProvider(widget.fairId).notifier);

    if (widget.partnerIdToEdit != null) {
      final repo = ref.read(partnerRepositoryProvider);
      final partner = await repo.getPartnerById(widget.partnerIdToEdit!);
      if (partner != null && mounted) {
        vm.loadForEdit(partner);
        _nameController.text = partner.fullName;
        _phoneController.text = partner.phoneNumber ?? '';
        _emailController.text = partner.email ?? '';
        _equityController.text = partner.profitSharingPercentage != null
            ? partner.profitSharingPercentage.toString()
            : '';
        _notesController.text = partner.notes;
      }
    } else {
      vm.reset();
    }

    if (mounted) setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _equityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final vm = ref.read(partnerFormViewModelProvider(widget.fairId).notifier);
    final isEdit = ref
        .read(partnerFormViewModelProvider(widget.fairId))
        .isEditMode;

    final success = await vm.submit();

    if (!mounted) return;

    if (success) {
      AppSnackbar.show(
        context,
        message: isEdit
            ? 'Partner profile updated successfully.'
            : 'New partner added to stall roster.',
        variant: AppSnackbarVariant.success,
      );
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/book-fairs/${widget.fairId}/partners');
        }
      } else if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } else {
      final state = ref.read(partnerFormViewModelProvider(widget.fairId));
      if (state.errorMessage != null) {
        AppSnackbar.show(
          context,
          message: state.errorMessage!,
          variant: AppSnackbarVariant.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;
    final state = ref.watch(partnerFormViewModelProvider(widget.fairId));
    final vm = ref.read(partnerFormViewModelProvider(widget.fairId).notifier);

    final isEdit = state.isEditMode;
    final title = isEdit ? 'Edit Partner' : 'Add New Partner';

    return Scaffold(
      appBar: AppAppBar(title: title, subtitle: 'Partnership Directory'),
      body: !_isInitialized
          ? const Center(
              child: AppLoadingIndicator.large(
                message: 'Preparing partner profile...',
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
                        // Partner Basic Info Card
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Personal Information',
                                style: textTheme.titleMedium?.copyWith(
                                  fontFamily: 'Georgia',
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              AppSpacing.gapH16,
                              AppTextField(
                                controller: _nameController,
                                label: 'Full Legal Name',
                                hint: 'e.g. Sayan Banik',
                                prefixIcon: Icon(
                                  Icons.person_outline_rounded,
                                  color: colors.textSecondary,
                                  size: 20.0,
                                ),
                                errorText: state.validationErrors['fullName'],
                                onChanged: vm.setFullName,
                              ),
                              AppSpacing.gapH16,
                              AppDropdown<PartnerRole>(
                                label: 'Organizational Role',
                                value: state.role,
                                prefixIcon: Icon(
                                  Icons.badge_outlined,
                                  color: colors.textSecondary,
                                  size: 20.0,
                                ),
                                items: PartnerRole.values.map((role) {
                                  return DropdownMenuItem(
                                    value: role,
                                    child: Text(role.displayName),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) vm.setRole(val);
                                },
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapH16,

                        // Contact Details Card
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Contact & Channels',
                                style: textTheme.titleMedium?.copyWith(
                                  fontFamily: 'Georgia',
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              AppSpacing.gapH16,
                              AppTextField(
                                controller: _phoneController,
                                label: 'Phone Number (Optional)',
                                hint: 'e.g. +91 98765 43210',
                                keyboardType: TextInputType.phone,
                                prefixIcon: Icon(
                                  Icons.phone_outlined,
                                  color: colors.textSecondary,
                                  size: 20.0,
                                ),
                                onChanged: vm.setPhoneNumber,
                              ),
                              AppSpacing.gapH16,
                              AppTextField(
                                controller: _emailController,
                                label: 'Email Address (Optional)',
                                hint: 'e.g. sayan@example.com',
                                keyboardType: TextInputType.emailAddress,
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: colors.textSecondary,
                                  size: 20.0,
                                ),
                                errorText: state.validationErrors['email'],
                                onChanged: vm.setEmail,
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapH16,

                        // Equity & Operational Notes Card
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Terms & Agreement',
                                style: textTheme.titleMedium?.copyWith(
                                  fontFamily: 'Georgia',
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              AppSpacing.gapH16,
                              AppTextField(
                                controller: _equityController,
                                label: 'Profit Sharing % (Optional)',
                                hint: 'e.g. 25.0',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                prefixIcon: Icon(
                                  Icons.pie_chart_outline_rounded,
                                  color: colors.textSecondary,
                                  size: 20.0,
                                ),
                                helperText: 'Agreed profit distribution ratio. Independent of capital contribution amount.',
                                errorText:
                                    state.validationErrors['profitSharing'],
                                onChanged: vm.setProfitSharingPercentage,
                              ),
                              AppSpacing.gapH16,
                              AppTextField(
                                controller: _notesController,
                                label: 'Operational Notes',
                                hint: 'Responsibilities (e.g. stall staffing, logistics, inventory oversight...)',
                                maxLines: 3,
                                minLines: 2,
                                onChanged: vm.setNotes,
                              ),
                            ],
                          ),
                        ),
                        AppSpacing.gapH24,

                        // Submit Button
                        AppButton(
                          text: isEdit ? 'Update Partner' : 'Register Partner',
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
