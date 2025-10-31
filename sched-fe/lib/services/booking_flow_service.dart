import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../screens/booking_flow/engagement_type_drawer.dart';
import '../screens/booking_flow/visit_type_drawer.dart';
import '../screens/booking_flow/base_info_drawer.dart';
import '../screens/booking_flow/questionnaire_drawer.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import 'package:intl/intl.dart';
import '../utils/toast_notification.dart';

/// Service to manage the multi-step booking flow through separate drawers
class BookingFlowService {
  // Collected data from all steps
  String? _engagementType;
  String? _visitType;
  Map<String, dynamic>? _baseInfo;
  Map<String, String>? _questionnaireAnswers;

  // Booking context
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  BuildContext? _rootContext; // Store the root context

  // Callbacks for period selection integration
  Function(DateTime, String)? _loadAvailability;
  Function(DateTime, Function(TimeOfDay, int), VoidCallback?)? _showSlotPicker;

  /// Start the booking flow with period selection integration
  Future<void> startBookingFlowWithPeriodSelection(
    BuildContext context, {
    required DateTime selectedDate,
    required Function(TimeOfDay startTime) onPeriodSelected,
    required Function(DateTime date, String visitType) loadAvailability,
    required Function(DateTime date, Function(TimeOfDay startTime, int duration) onSlotSelected, VoidCallback? onBack) showSlotPicker,
  }) async {
    _selectedDate = selectedDate;
    _rootContext = context; // Store the root context
    _loadAvailability = loadAvailability;
    _showSlotPicker = showSlotPicker;
    _resetData();

    // Start with engagement type drawer
    _showEngagementTypeDrawerForPeriodFlow(context, onPeriodSelected);
  }

  /// Start the booking flow
  void startBookingFlow(
    BuildContext context, {
    required DateTime selectedDate,
    required TimeOfDay startTime,
  }) {
    _selectedDate = selectedDate;
    _startTime = startTime;
    _rootContext = context; // Store the root context for navigation
    _resetData();
    _showEngagementTypeDrawer(context);
  }

  void _resetData() {
    _engagementType = null;
    _visitType = null;
    _baseInfo = null;
    _questionnaireAnswers = null;
  }

  /// Step 1: Show Engagement Type drawer (for period selection flow)
  void _showEngagementTypeDrawerForPeriodFlow(
    BuildContext context,
    Function(TimeOfDay startTime) onPeriodSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => EngagementTypeDrawer(
          onNext: (engagementType) {
            _engagementType = engagementType;
            Navigator.pop(context);

            // If VISIT, show visit type drawer; otherwise go to period selection
            if (engagementType == 'VISIT') {
              _showVisitTypeDrawerForPeriodFlow(context, onPeriodSelected);
            } else {
              // Innovation Exchange - go directly to period selection
              _visitType = 'INNOVATION_EXCHANGE';
              _showPeriodSelection(context, onPeriodSelected);
            }
          },
        ),
      ),
    );
  }

  /// Step 1: Show Engagement Type drawer
  void _showEngagementTypeDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => EngagementTypeDrawer(
          onNext: (engagementType) {
            _engagementType = engagementType;
            Navigator.pop(context);

            // If VISIT, show visit type drawer; otherwise go to base info
            if (engagementType == 'VISIT') {
              _showVisitTypeDrawer(context);
            } else {
              _showBaseInfoDrawer(context);
            }
          },
        ),
      ),
    );
  }

  /// Step 2 (Conditional): Show Visit Type drawer (for period selection flow)
  void _showVisitTypeDrawerForPeriodFlow(
    BuildContext context,
    Function(TimeOfDay startTime) onPeriodSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => VisitTypeDrawer(
          onNext: (visitType) {
            _visitType = visitType;
            Navigator.pop(context);
            _showPeriodSelection(context, onPeriodSelected);
          },
          onBack: () {
            Navigator.pop(context);
            _showEngagementTypeDrawerForPeriodFlow(context, onPeriodSelected);
          },
        ),
      ),
    );
  }

  /// Step 2 (Conditional): Show Visit Type drawer
  void _showVisitTypeDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => VisitTypeDrawer(
          onNext: (visitType) {
            _visitType = visitType;
            Navigator.pop(context);
            _showBaseInfoDrawer(context);
          },
          onBack: () {
            Navigator.pop(context);
            _showEngagementTypeDrawer(context);
          },
        ),
      ),
    );
  }

  /// Show Period Selection (integrates with existing calendar drawer)
  Future<void> _showPeriodSelection(
    BuildContext context,
    Function(TimeOfDay startTime) onPeriodSelected,
  ) async {
    if (_selectedDate == null || _loadAvailability == null || _showSlotPicker == null) {
      ToastNotification.show(
        context,
        message: 'Missing booking configuration',
        type: ToastType.error,
      );
      return;
    }

    // Map visit type to API visitType for availability check
    String apiVisitType;
    if (_visitType == 'PACE_TOUR') {
      apiVisitType = 'PACE_TOUR';
    } else if (_visitType == 'PACE_EXPERIENCE') {
      apiVisitType = 'PACE_EXPERIENCE';
    } else {
      apiVisitType = 'INNOVATION_EXCHANGE';
    }

    // Show the slot picker drawer IMMEDIATELY (it will show loading state)
    // Pass back callback to return to visit type selection
    _showSlotPicker!(_selectedDate!, (TimeOfDay startTime, int duration) {
      _startTime = startTime;

      // Notify parent that period was selected
      onPeriodSelected(startTime);

      // Show next drawer immediately (drawer has its own confirm button now)
      if (_rootContext != null && _rootContext!.mounted) {
        _showBaseInfoDrawer(_rootContext!);
      }
    }, () {
      // Back button callback - return to visit type selection
      if (_engagementType == 'VISIT') {
        _showVisitTypeDrawerForPeriodFlow(context, onPeriodSelected);
      } else {
        _showEngagementTypeDrawerForPeriodFlow(context, onPeriodSelected);
      }
    });

    // Load availability AFTER drawer is shown (async, drawer will update when data arrives)
    _loadAvailability!(_selectedDate!, apiVisitType);
  }

  /// Step 3: Show Base Info drawer
  void _showBaseInfoDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => BaseInfoDrawer(
          onNext: (data) {
            _baseInfo = data;
            Navigator.pop(context);

            // Check if questionnaire is needed
            if (_requiresQuestionnaire()) {
              _showQuestionnaireDrawer(context);
            } else {
              // Don't await - let it run in background
              _submitBooking(context);
            }
          },
          onBack: () {
            Navigator.pop(context);
            // Go back to previous drawer
            if (_engagementType == 'VISIT') {
              _showVisitTypeDrawer(context);
            } else {
              _showEngagementTypeDrawer(context);
            }
          },
        ),
      ),
    );
  }

  /// Step 4 (Conditional): Show Questionnaire drawer
  void _showQuestionnaireDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => QuestionnaireDrawer(
          onSubmit: (answers) {
            _questionnaireAnswers = answers;
            Navigator.pop(context);
            // Don't await - let it run in background
            _submitBooking(context);
          },
          onBack: () {
            Navigator.pop(context);
            _showBaseInfoDrawer(context);
          },
        ),
      ),
    );
  }

  /// Check if questionnaire is required
  bool _requiresQuestionnaire() {
    if (_engagementType == 'INNOVATION_EXCHANGE') return true;
    if (_engagementType == 'VISIT' && _visitType == 'PACE_EXPERIENCE') return true;
    return false;
  }

  /// Submit the booking with all collected data
  Future<void> _submitBooking(BuildContext context) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint('🔵 [BookingFlow-$timestamp] ========== SUBMIT STARTED ==========');

    if (_selectedDate == null || _startTime == null || _baseInfo == null) {
      debugPrint('🔴 [BookingFlow-$timestamp] ERROR: Missing required data');
      ToastNotification.show(
        context,
        message: 'Missing required booking information',
        type: ToastType.error,
      );
      return;
    }

    // CRITICAL: Capture AuthProvider BEFORE any async operations
    // The WebSocket event will rebuild the Calendar and deactivate the drawer's context
    debugPrint('🟡 [BookingFlow-$timestamp] Step 0: Capturing AuthProvider BEFORE any async ops');
    final authProvider = context.read<AuthProvider>();
    final userRole = authProvider.user?.role;
    debugPrint('✅ [BookingFlow-$timestamp] User role captured: $userRole');

    bool dialogShown = false;
    bool navigationStarted = false;

    // CRITICAL: Get Navigator reference BEFORE any async operations
    // The WebSocket event can rebuild Calendar and unmount drawer context
    final navigator = Navigator.of(context, rootNavigator: true);
    debugPrint('✅ [BookingFlow-$timestamp] Navigator reference captured');

    try {
      debugPrint('🟡 [BookingFlow-$timestamp] Step 1: Showing loading dialog');
      // Show loading dialog using the captured navigator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WillPopScope(
          onWillPop: () async => false, // Prevent back button from closing
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
      dialogShown = true;
      debugPrint('✅ [BookingFlow-$timestamp] Loading dialog shown');

      debugPrint('🟡 [BookingFlow-$timestamp] Step 2: Building booking data');
      final bookingData = _buildBookingData();

      debugPrint('🟡 [BookingFlow-$timestamp] Step 3: Calling API...');
      final apiService = ApiService();
      final createdBooking = await apiService.createBooking(bookingData);
      debugPrint('✅ [BookingFlow-$timestamp] API call successful - Booking ID: ${createdBooking['id']}');

      // Get booking ID (userRole already captured before async operations)
      final bookingId = createdBooking['id'];

      debugPrint('🟡 [BookingFlow-$timestamp] Step 4: Preparing navigation data');
      debugPrint('📍 [BookingFlow-$timestamp] User role: $userRole');
      debugPrint('📍 [BookingFlow-$timestamp] Booking ID: $bookingId');

      // Build navigation route BEFORE any context operations
      final String navigationRoute;
      if (userRole == UserRole.USER) {
        navigationRoute = '/app/my-bookings?bookingId=$bookingId';
      } else {
        navigationRoute = '/app/pending';
      }
      debugPrint('📍 [BookingFlow-$timestamp] Navigation route: $navigationRoute');

      // CRITICAL: Close dialog using the captured Navigator (not context-dependent)
      debugPrint('🟡 [BookingFlow-$timestamp] Step 5: Closing loading dialog');
      if (dialogShown) {
        try {
          navigator.pop();
          dialogShown = false;
          debugPrint('✅ [BookingFlow-$timestamp] Loading dialog closed using captured Navigator');
        } catch (popError) {
          debugPrint('⚠️ [BookingFlow-$timestamp] Error popping dialog: $popError');
        }
      }

      // Try to show success message if context is still mounted
      if (context.mounted) {
        debugPrint('🟡 [BookingFlow-$timestamp] Step 6: Showing success message');
        ToastNotification.show(
          context,
          message: 'Booking created successfully!',
          type: ToastType.success,
          duration: const Duration(seconds: 2),
        );
      } else {
        debugPrint('⚠️ [BookingFlow-$timestamp] Context unmounted - skipping snackbar, but navigation will still work');
      }

      // Reset data BEFORE navigation
      _resetData();
      debugPrint('✅ [BookingFlow-$timestamp] Flow data reset');

      // Navigate IMMEDIATELY without delay - use WidgetsBinding to ensure it happens after current frame
      // CRITICAL: This MUST always execute, even if context is unmounted (we have _rootContext fallback)
      navigationStarted = true;
      debugPrint('🟡 [BookingFlow-$timestamp] Step 7: Scheduling navigation');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('🚀 [BookingFlow-$timestamp] Post-frame callback executing');

        // Try drawer context first, fallback to root context
        BuildContext? navContext;
        if (context.mounted) {
          navContext = context;
          debugPrint('✅ [BookingFlow-$timestamp] Using drawer context for navigation');
        } else if (_rootContext != null && _rootContext!.mounted) {
          navContext = _rootContext;
          debugPrint('✅ [BookingFlow-$timestamp] Drawer context unmounted, using root context for navigation');
        } else {
          debugPrint('⚠️ [BookingFlow-$timestamp] Both contexts unmounted - cannot navigate');
        }

        if (navContext != null) {
          try {
            debugPrint('🚀 [BookingFlow-$timestamp] Navigating to: $navigationRoute');
            navContext.go(navigationRoute);
            debugPrint('✅ [BookingFlow-$timestamp] Navigation successful');
          } catch (navError) {
            debugPrint('🔴 [BookingFlow-$timestamp] Navigation error: $navError');
          }
        }
      });

      debugPrint('✅ [BookingFlow-$timestamp] Navigation scheduled');
      debugPrint('🟢 [BookingFlow-$timestamp] ========== SUBMIT SUCCESS ==========');

    } catch (e, stackTrace) {
      debugPrint('🔴 [BookingFlow-$timestamp] ========== ERROR ==========');
      debugPrint('🔴 [BookingFlow-$timestamp] Error: $e');
      debugPrint('🔴 [BookingFlow-$timestamp] Stack trace: $stackTrace');

      // Close dialog using captured navigator (doesn't depend on context)
      if (dialogShown) {
        try {
          navigator.pop();
          dialogShown = false;
          debugPrint('✅ [BookingFlow-$timestamp] Error dialog closed using captured Navigator');
        } catch (popError) {
          debugPrint('⚠️ [BookingFlow-$timestamp] Error closing dialog: $popError');
        }
      }

      if (context.mounted) {
        ToastNotification.show(
          context,
          message: 'Error creating booking: ${e.toString()}',
          type: ToastType.error,
          duration: const Duration(seconds: 5),
        );
      }

      debugPrint('🔴 [BookingFlow-$timestamp] ========== ERROR END ==========');
    } finally {
      // SAFETY NET: Ensure dialog is always closed using captured navigator
      debugPrint('🟡 [BookingFlow-$timestamp] Finally block - dialogShown: $dialogShown, navigationStarted: $navigationStarted');

      if (dialogShown) {
        try {
          navigator.pop();
          debugPrint('✅ [BookingFlow-$timestamp] Safety net: Dialog closed using captured Navigator');
        } catch (finalError) {
          debugPrint('⚠️ [BookingFlow-$timestamp] Safety net: Error closing dialog: $finalError');
        }
      }

      debugPrint('🏁 [BookingFlow-$timestamp] ========== SUBMIT END ==========\n');
    }
  }

  /// Build the booking data payload
  Map<String, dynamic> _buildBookingData() {
    // Determine final engagement type, visit type, and duration
    String finalEngagementType;
    String finalVisitType;
    int finalDuration;

    if (_engagementType == 'VISIT') {
      finalEngagementType = 'VISIT';
      finalVisitType = _visitType!;
      finalDuration = _visitType == 'PACE_TOUR' ? 2 : 6;
    } else {
      finalEngagementType = 'INNOVATION_EXCHANGE';
      finalVisitType = 'INNOVATION_EXCHANGE';
      finalDuration = 6; // Innovation Exchange uses 6 hours (no SEVEN_HOURS in backend)
    }

    return {
      // Date/Time
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate!),
      'startTime': '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}',
      'duration': _durationToEnum(finalDuration),

      // Engagement flow
      'engagementType': finalEngagementType,
      'visitType': finalVisitType,

      // Base Information (spread all fields from _baseInfo)
      ..._baseInfo!,

      // Questionnaire (if present)
      if (_questionnaireAnswers != null)
        'questionnaireAnswers': _questionnaireAnswers,

      // Flags
      'requiresAlignmentCall': _requiresQuestionnaire(),
      'expectedAttendees': 1,

      // Legacy compatibility
      'companyName': _baseInfo!['organizationName'],
      'accountName': _baseInfo!['organizationName'],
    };
  }

  String _durationToEnum(int hours) {
    switch (hours) {
      case 1:
        return 'ONE_HOUR';
      case 2:
        return 'TWO_HOURS';
      case 3:
        return 'THREE_HOURS';
      case 4:
        return 'FOUR_HOURS';
      case 5:
        return 'FIVE_HOURS';
      case 6:
        return 'SIX_HOURS';
      default:
        return 'TWO_HOURS';
    }
  }
}
