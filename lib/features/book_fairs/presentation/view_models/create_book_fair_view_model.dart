import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/geocoding/photon_place.dart';
import '../../../../core/utils/financial_calculator.dart';
import '../../domain/entities/book_fair.dart';
import '../../domain/entities/partner.dart';
import 'book_fair_providers.dart';

/// Immutable state container for the Create / Edit Book Fair form
class CreateBookFairState {
  const CreateBookFairState({
    this.editingId,
    this.name = '',
    this.location = '',
    this.city = '',
    this.stateProvince = '',
    this.startDate,
    this.endDate,
    this.setupDate,
    this.closingDate,
    this.estimatedBudget = '',
    this.initialInvestment = '',
    this.currency = 'INR',
    this.numPartners = 1,
    this.partnershipType = 'Sole Proprietorship',
    this.initialPartnerSetup = '',
    this.description = '',
    this.operationalNotes = '',
    this.isSubmitting = false,
    this.validationErrors = const {},
    this.selectedLocation,
    this.locationName,
    this.latitude,
    this.longitude,
    this.country,
    this.formattedAddress,
    this.osmId,
    this.osmType,
  });

  final String? editingId;
  final String name;
  final String location;
  final String city;
  final String stateProvince;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? setupDate;
  final DateTime? closingDate;
  final String estimatedBudget;
  final String initialInvestment;
  final String currency;
  final int numPartners;
  final String partnershipType;
  final String initialPartnerSetup;
  final String description;
  final String operationalNotes;
  final bool isSubmitting;
  final Map<String, String> validationErrors;

  // Structured Geocoding / Location data
  final PhotonPlace? selectedLocation;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? country;
  final String? formattedAddress;
  final int? osmId;
  final String? osmType;

  bool get isEditMode => editingId != null;

  CreateBookFairState copyWith({
    String? editingId,
    String? name,
    String? location,
    String? city,
    String? stateProvince,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? setupDate,
    DateTime? closingDate,
    String? estimatedBudget,
    String? initialInvestment,
    String? currency,
    int? numPartners,
    String? partnershipType,
    String? initialPartnerSetup,
    String? description,
    String? operationalNotes,
    bool? isSubmitting,
    Map<String, String>? validationErrors,
    PhotonPlace? selectedLocation,
    bool clearSelectedLocation = false,
    String? locationName,
    double? latitude,
    double? longitude,
    bool clearCoordinates = false,
    String? country,
    String? formattedAddress,
    int? osmId,
    String? osmType,
  }) {
    return CreateBookFairState(
      editingId: editingId ?? this.editingId,
      name: name ?? this.name,
      location: location ?? this.location,
      city: city ?? this.city,
      stateProvince: stateProvince ?? this.stateProvince,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      setupDate: setupDate ?? this.setupDate,
      closingDate: closingDate ?? this.closingDate,
      estimatedBudget: estimatedBudget ?? this.estimatedBudget,
      initialInvestment: initialInvestment ?? this.initialInvestment,
      currency: currency ?? this.currency,
      numPartners: numPartners ?? this.numPartners,
      partnershipType: partnershipType ?? this.partnershipType,
      initialPartnerSetup: initialPartnerSetup ?? this.initialPartnerSetup,
      description: description ?? this.description,
      operationalNotes: operationalNotes ?? this.operationalNotes,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      validationErrors: validationErrors ?? this.validationErrors,
      selectedLocation: clearSelectedLocation
          ? null
          : (selectedLocation ?? this.selectedLocation),
      locationName: locationName ?? this.locationName,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      country: country ?? this.country,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      osmId: osmId ?? this.osmId,
      osmType: osmType ?? this.osmType,
    );
  }
}

final createBookFairViewModelProvider =
    NotifierProvider<CreateBookFairViewModel, CreateBookFairState>(
      CreateBookFairViewModel.new,
    );

class CreateBookFairViewModel extends Notifier<CreateBookFairState> {
  final _uuid = const Uuid();

  @override
  CreateBookFairState build() => const CreateBookFairState();

  void initForCreate() {
    state = const CreateBookFairState();
  }

  void loadForEdit(BookFair fair) {
    state = CreateBookFairState(
      editingId: fair.id,
      name: fair.name,
      location: fair.location,
      city: fair.city,
      stateProvince: fair.state,
      startDate: fair.startDate,
      endDate: fair.endDate,
      setupDate: fair.setupDate,
      closingDate: fair.closingDate,
      estimatedBudget: (fair.estimatedBudget).toStringAsFixed(0),
      initialInvestment: (fair.initialInvestment).toStringAsFixed(0),
      currency: fair.currency,
      numPartners: fair.partnerCount,
      partnershipType: fair.partnershipType,
      initialPartnerSetup: fair.initialPartnerSetup,
      description: fair.description,
      operationalNotes: fair.operationalNotes,
      validationErrors: const {},
    );
  }

  void setName(String val) => state = state.copyWith(name: val);

  void setLocation(String val) {
    final trimmed = val.trim();
    final isDifferent =
        state.selectedLocation != null &&
        state.selectedLocation!.name != trimmed &&
        state.selectedLocation!.venueFormattedName != trimmed;

    state = state.copyWith(location: val, clearSelectedLocation: isDifferent);
  }

  void setCity(String val) {
    final trimmed = val.trim();
    final cityChanged = state.city.trim() != trimmed;
    state = state.copyWith(
      city: val,
      clearCoordinates: cityChanged && state.selectedLocation == null,
    );
  }

  void setStateProvince(String val) =>
      state = state.copyWith(stateProvince: val);

  void onVenueSelected(PhotonPlace place) {
    state = state.copyWith(
      location: place.venueFormattedName,
      selectedLocation: place,
      locationName: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
      country: place.country ?? state.country,
      formattedAddress: place.formattedAddress,
      osmId: place.osmId,
      osmType: place.osmType,
    );
  }

  void onCitySelected(PhotonPlace place) {
    final newStateProvince = (place.state != null && place.state!.isNotEmpty)
        ? place.state!
        : state.stateProvince;

    state = state.copyWith(
      city: place.cityFormattedName,
      stateProvince: newStateProvince,
      latitude: state.selectedLocation == null
          ? place.latitude
          : state.latitude,
      longitude: state.selectedLocation == null
          ? place.longitude
          : state.longitude,
      country: place.country ?? state.country,
    );
  }

  void onStateSelected(PhotonPlace place) {
    state = state.copyWith(
      stateProvince: place.stateFormattedName,
      country: place.country ?? state.country,
    );
  }

  void setStartDate(DateTime val) => state = state.copyWith(startDate: val);
  void setEndDate(DateTime val) => state = state.copyWith(endDate: val);
  void setSetupDate(DateTime? val) => state = state.copyWith(setupDate: val);
  void setClosingDate(DateTime? val) =>
      state = state.copyWith(closingDate: val);
  void setEstimatedBudget(String val) =>
      state = state.copyWith(estimatedBudget: val);
  void setInitialInvestment(String val) =>
      state = state.copyWith(initialInvestment: val);
  void setCurrency(String val) => state = state.copyWith(currency: val);
  void setNumPartners(int val) => state = state.copyWith(numPartners: val);
  void setPartnershipType(String val) =>
      state = state.copyWith(partnershipType: val);
  void setInitialPartnerSetup(String val) =>
      state = state.copyWith(initialPartnerSetup: val);
  void setDescription(String val) => state = state.copyWith(description: val);
  void setOperationalNotes(String val) =>
      state = state.copyWith(operationalNotes: val);

  bool validate() {
    final errors = <String, String>{};

    if (state.name.trim().isEmpty) {
      errors['name'] = 'Book fair name is required';
    }
    if (state.location.trim().isEmpty) {
      errors['location'] = 'Venue location is required';
    }
    if (state.startDate == null) {
      errors['startDate'] = 'Start date is required';
    }
    if (state.endDate == null) {
      errors['endDate'] = 'End date is required';
    } else if (state.startDate != null &&
        state.endDate!.isBefore(state.startDate!)) {
      errors['endDate'] = 'End date cannot precede the start date';
    }

    final budget = double.tryParse(state.estimatedBudget.trim());
    if (state.estimatedBudget.trim().isEmpty) {
      errors['estimatedBudget'] = 'Estimated budget is required';
    } else if (budget == null || budget <= 0) {
      errors['estimatedBudget'] = 'Enter a valid positive budget amount';
    }

    final investment = double.tryParse(state.initialInvestment.trim());
    if (state.initialInvestment.trim().isEmpty) {
      errors['initialInvestment'] = 'Initial investment is required';
    } else if (investment == null || investment < 0) {
      errors['initialInvestment'] = 'Enter a valid investment amount';
    }

    state = state.copyWith(validationErrors: errors);
    return errors.isEmpty;
  }

  /// Submits the form. Returns the ID of the created or updated [BookFair] on success,
  /// or null if validation fails.
  Future<String?> submit() async {
    if (!validate() || state.isSubmitting) return null;

    state = state.copyWith(isSubmitting: true);

    try {
      final fairRepo = ref.read(bookFairRepositoryProvider);
      final partnerRepo = ref.read(partnerRepositoryProvider);

      final budgetPaise = FinancialCalculator.parseToPaise(
        state.estimatedBudget,
      );
      final investmentPaise = FinancialCalculator.parseToPaise(
        state.initialInvestment,
      );

      final now = DateTime.now();

      if (state.isEditMode) {
        // Update existing fair
        final existingFair = await fairRepo.getBookFairById(state.editingId!);
        final updatedFair = BookFair(
          id: state.editingId!,
          name: state.name.trim(),
          location: state.location.trim(),
          city: state.city.trim(),
          state: state.stateProvince.trim(),
          startDate: state.startDate!,
          endDate: state.endDate!,
          setupDate: state.setupDate,
          closingDate: state.closingDate ?? state.endDate,
          estimatedBudgetPaise: budgetPaise,
          initialInvestmentPaise: investmentPaise,
          currency: state.currency,
          partnerCount: state.numPartners,
          partnershipType: state.partnershipType,
          initialPartnerSetup: state.initialPartnerSetup.trim(),
          description: state.description.trim(),
          operationalNotes: state.operationalNotes.trim(),
          isDraft: false,
          isArchived: existingFair?.isArchived ?? false,
          createdAt: existingFair?.createdAt ?? now,
          updatedAt: now,
        );

        await fairRepo.updateBookFair(updatedFair);
        state = state.copyWith(isSubmitting: false);
        return updatedFair.id;
      } else {
        // Create new fair
        final newId = _uuid.v4();
        final newFair = BookFair(
          id: newId,
          name: state.name.trim(),
          location: state.location.trim(),
          city: state.city.trim(),
          state: state.stateProvince.trim(),
          startDate: state.startDate!,
          endDate: state.endDate!,
          setupDate: state.setupDate,
          closingDate: state.closingDate ?? state.endDate,
          estimatedBudgetPaise: budgetPaise,
          initialInvestmentPaise: investmentPaise,
          currency: state.currency,
          partnerCount: state.numPartners,
          partnershipType: state.partnershipType,
          initialPartnerSetup: state.initialPartnerSetup.trim(),
          description: state.description.trim(),
          operationalNotes: state.operationalNotes.trim(),
          isDraft: false,
          isArchived: false,
          createdAt: now,
          updatedAt: now,
        );

        await fairRepo.createBookFair(newFair);

        // Auto-initialize lead organizer partner
        final leadPartner = Partner(
          id: _uuid.v4(),
          fairId: newId,
          fullName: 'Primary Stall Organizer',
          role: PartnerRole.owner,
          joinedAt: now,
          profitSharingPercentage: state.numPartners == 1 ? 100.0 : null,
          notes: 'Initial organizer established during book fair creation.',
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        await partnerRepo.addPartner(leadPartner);

        state = state.copyWith(isSubmitting: false);
        return newId;
      }
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        validationErrors: {'general': e.toString()},
      );
      return null;
    }
  }

  Future<void> saveDraft() async {
    final budgetPaise = FinancialCalculator.parseToPaise(
      state.estimatedBudget.trim(),
    );
    final investmentPaise = FinancialCalculator.parseToPaise(
      state.initialInvestment.trim(),
    );

    final now = DateTime.now();
    final draftFair = BookFair(
      id: state.editingId ?? _uuid.v4(),
      name: state.name.trim().isEmpty ? 'Untitled Draft' : state.name.trim(),
      location: state.location.trim(),
      city: state.city.trim(),
      state: state.stateProvince.trim(),
      startDate: state.startDate ?? now,
      endDate: state.endDate ?? now.add(const Duration(days: 7)),
      setupDate: state.setupDate,
      closingDate: state.closingDate,
      estimatedBudgetPaise: budgetPaise,
      initialInvestmentPaise: investmentPaise,
      currency: state.currency,
      partnerCount: state.numPartners,
      partnershipType: state.partnershipType,
      initialPartnerSetup: state.initialPartnerSetup.trim(),
      description: state.description.trim(),
      operationalNotes: state.operationalNotes.trim(),
      isDraft: true,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    final repo = ref.read(bookFairRepositoryProvider);
    await repo.saveDraft(draftFair);
  }

  void reset() {
    state = const CreateBookFairState();
  }
}
