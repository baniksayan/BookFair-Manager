/// Centralized application strings for BookFair Manager.
///
/// Designed to support future multi-language localization (e.g. English and Bengali)
/// while keeping the initial Stage 01 implementation in English.
abstract final class AppStrings {
  // --- General & App Identity ---
  static const String appName = 'BookFair Manager';
  static const String appTagline = 'Offline-First Literary Business Suite';
  static const String offlineModeBadge = 'Offline Ready';
  static const String sampleDataNotice = 'SAMPLE DATA';
  static const String sampleDataSubtitle =
      'Demonstration figures only. Persistent storage begins in Stage 02.';

  // --- Navigation Labels ---
  static const String navDashboard = 'Dashboard';
  static const String navBookFairs = 'Book Fairs';
  static const String navInventory = 'Inventory';
  static const String navMore = 'More';

  // --- Common Actions ---
  static const String btnCancel = 'Cancel';
  static const String btnConfirm = 'Confirm';
  static const String btnClose = 'Close';
  static const String btnSave = 'Save';
  static const String btnBack = 'Back';
  static const String btnRetry = 'Retry';
  static const String btnDismiss = 'Dismiss';
  static const String btnUnderstood = 'Understood';

  // --- Dashboard Screen ---
  static const String dashboardGreeting = 'Welcome back, Stall Organizer';
  static const String dashboardSubtitle =
      'Book Fair Operations & Financial Status';
  static const String dashboardHeroTitle =
      'Curate, Invest & Track Every Literary Fair';
  static const String dashboardHeroSubtitle =
      'Manage stall partnerships, book inventory batches, daily sales counters, and profit settlement with complete offline privacy.';
  static const String dashboardHeroAction = 'Start New Book Fair';

  // Business Overview Metrics
  static const String activeFairTitle = 'Active Fair';
  static const String activeFairName = 'Kolkata International Book Fair 2026';
  static const String activeFairLocation = 'Milan Mela Prangan, Stall #B-42';
  static const String activeFairDaysRemaining = '8 Days Left';
  static const String activeFairStatusBadge = 'In Progress';

  static const String metricInvestment = 'Total Investment';
  static const String metricInvestmentValue = '₹ 1,85,000';
  static const String metricInvestmentSub = 'Funded across 3 active partners';

  static const String metricSales = 'Total Gross Sales';
  static const String metricSalesValue = '₹ 2,42,500';
  static const String metricSalesSub = '+18.4% above initial forecast';

  static const String metricExpenses = 'Operating Expenses';
  static const String metricExpensesValue = '₹ 48,200';
  static const String metricExpensesSub = 'Rent, stall decor, staff stipends';

  static const String metricInventory = 'Current Inventory';
  static const String metricInventoryValue = '1,420 Books';
  static const String metricInventorySub = '38 unique titles across 4 batches';

  // Quick Actions Section
  static const String quickActionsTitle = 'Quick Stall Actions';
  static const String quickActionsSubtitle = 'Immediate operational workflows';
  static const String actionAddBookFair = 'New Fair';
  static const String actionAddBookFairDesc = 'Setup upcoming exhibition';
  static const String actionAddBooks = 'Stock In';
  static const String actionAddBooksDesc = 'Record book arrival batch';
  static const String actionRecordExpense = 'Expense';
  static const String actionRecordExpenseDesc = 'Log stall overhead payment';
  static const String actionSalesCounter = 'Sales Counter';
  static const String actionSalesCounterDesc = 'Launch point-of-sale register';

  // Recent Activity Section
  static const String recentActivityTitle = 'Recent Fair Activities';
  static const String recentActivitySubtitle =
      'Latest transaction & inventory ledger';
  static const String viewAllActivity = 'View All';

  static const String act1Title = 'Inventory Batch #104 Received';
  static const String act1Time = 'Today, 02:45 PM';
  static const String act1Amount = '+500 Books';
  static const String act1Subtitle =
      'Fiction & Classics batch arrived at stall';

  static const String act2Title = 'Stall Lighting & Decor Payment';
  static const String act2Time = 'Today, 11:30 AM';
  static const String act2Amount = '-₹ 3,500';
  static const String act2Subtitle = 'Vendor settlement via cash voucher';

  static const String act3Title = 'Partner Contribution — Sayan Banik';
  static const String act3Time = 'Yesterday, 07:15 PM';
  static const String act3Amount = '+₹ 50,000';
  static const String act3Subtitle =
      'Capital injection for international reprint batch';

  static const String act4Title = 'Institutional Bulk Sale to Library';
  static const String act4Time = 'Yesterday, 03:00 PM';
  static const String act4Amount = '+₹ 18,600';
  static const String act4Subtitle =
      'Invoice #BF-089 (42 volumes with 15% discount)';

  // --- Create Book Fair Screen ---
  static const String createFairTitle = 'Create New Book Fair';
  static const String createFairSubtitle =
      'Establish a distinct management workspace for your upcoming stall exhibition.';

  // Form Section Headers
  static const String sectionGeneralInfo = 'General Information';
  static const String sectionSchedule = 'Exhibition Schedule';
  static const String sectionFinances = 'Financial & Partnership Setup';
  static const String sectionNotes = 'Additional Notes & Strategy';

  // Form Fields & Hints
  static const String fieldFairName = 'Book Fair Name';
  static const String fieldFairNameHint =
      'e.g. Dhaka International Book Fair 2026';
  static const String fieldLocation = 'Location / Venue';
  static const String fieldLocationHint = 'e.g. Bangla Academy Ground, Dhaka';
  static const String fieldStartDate = 'Start Date';
  static const String fieldStartDateHint = 'Select opening date';
  static const String fieldEndDate = 'End Date';
  static const String fieldEndDateHint = 'Select concluding date';
  static const String fieldEstimatedBudget = 'Estimated Budget (₹)';
  static const String fieldEstimatedBudgetHint = 'e.g. 200000';
  static const String fieldInitialInvestment = 'Initial Investment (₹)';
  static const String fieldInitialInvestmentHint = 'e.g. 50000';
  static const String fieldNumPartners = 'Number of Partners / Investors';
  static const String fieldNumPartnersHint = 'Select partner count';
  static const String fieldDescription = 'Description / Operational Notes';
  static const String fieldDescriptionHint =
      'Notes regarding stall size, prominent genres, expected footfall, logistics...';

  // Form Actions
  static const String btnSaveDraft = 'Save Draft';
  static const String btnCreateFair = 'Create Book Fair';

  // Form Validation
  static const String valRequiredField = 'This field is required';
  static const String valInvalidNumber = 'Please enter a valid numeric value';
  static const String valPositiveNumber = 'Amount must be greater than zero';
  static const String valEndBeforeStart =
      'End date cannot precede the start date';
  static const String valInvalidDate = 'Please select a valid date';

  // Feedback Messages & Dialogs
  static const String demoDialogTitle = 'Stage 01 Demonstration';
  static const String demoDialogBody =
      'This form has passed all validation checks! In this stage, data is handled by an in-memory view model. Full local persistence with Hive will be integrated in Stage 02.';
  static const String demoDraftSavedTitle = 'Draft Saved (In-Memory)';
  static const String demoDraftSavedBody =
      'Your book fair configuration draft has been captured for this session.';
  static const String demoActionNotAvailable =
      'Demonstration Mode: This business module will be unlocked in the subsequent development stage.';

  // --- Coming Soon & Placeholder Screens ---
  static const String comingSoonTitle = 'Module Under Construction';
  static const String comingSoonDesc =
      'This module is scheduled for future stages of the BookFair Manager offline architecture.';
  static const String navBookFairsDesc =
      'Manage multiple concurrent book stalls, historical records, and stall allocations.';
  static const String navInventoryDesc =
      'Purchase batches, book condition categorization, barcode tracking, and pricing rules.';
  static const String navMoreDesc =
      'Partner equity settlements, P&L reporting, backup export/import, and system settings.';

  // --- Common UI Component Strings ---
  static const String emptyStateTitle = 'No Records Found';
  static const String emptyStateDesc =
      'Get started by adding your first record using the action button below.';
  static const String errorStateTitle = 'Something Went Wrong';
  static const String errorStateDesc =
      'An unexpected error occurred while processing this request.';
  static const String searchPlaceholder =
      'Search books, sales, partners, expenses...';

  // --- Stage 04 Finance & Accounting Strings ---
  static const String navExpenses = 'Expenses';
  static const String navCashbook = 'Cashbook';
  static const String navAccounting = 'Accounting';
  static const String navFinancialReports = 'Financial Reports';
  static const String navPartnerDues = 'Partner Dues';

  static const String totalOperatingExpenses = 'Total Operating Expenses';
  static const String paidExpenses = 'Paid Expenses';
  static const String outstandingExpenses = 'Outstanding Expenses';
  static const String totalBusinessCash = 'Total Business Cash';
  static const String totalOnlineBalance = 'Total UPI / Online';
  static const String totalBankBalance = 'Total Bank Balance';
  static const String totalBusinessFunds = 'Total Business Liquid Funds';
  static const String partnerReimbursementLiability =
      'Partner Reimbursement Liability';
  static const String supplierPayables = 'Supplier Payables';
  static const String transferFunds = 'Transfer Funds';
  static const String settleReimbursement = 'Settle Reimbursement';
  static const String addExpensePayment = 'Add Expense Payment';
}
