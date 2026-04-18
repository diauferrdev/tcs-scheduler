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
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => EngagementTypeDrawer(
          selectedDate: _selectedDate,
          onNext: (engagementType) {
            _engagementType = engagementType;
            Navigator.pop(context);

            if (engagementType == 'PACE_VISIT') {
              _showVisitTypeDrawerForPeriodFlow(context, onPeriodSelected);
            } else {
              // IE and Hackathon: full-day events, skip period selection
              _visitType = engagementType == 'INNOVATION_EXCHANGE'
                  ? 'INNOVATION_EXCHANGE'
                  : 'HACKATHON';
              _startTime = const TimeOfDay(hour: 9, minute: 0);
              onPeriodSelected(const TimeOfDay(hour: 9, minute: 0));
              if (_rootContext != null && _rootContext!.mounted) {
                _showBaseInfoDrawer(_rootContext!);
              }
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
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => EngagementTypeDrawer(
          selectedDate: _selectedDate,
          onNext: (engagementType) {
            _engagementType = engagementType;
            Navigator.pop(context);

            if (engagementType == 'PACE_VISIT') {
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

            if (visitType == 'PACE_TOUR') {
              // Pace Tour needs period selection (morning/afternoon)
              _showPeriodSelection(context, onPeriodSelected);
            } else {
              // Pace Visit Fullday: full day, skip period selection
              _startTime = const TimeOfDay(hour: 9, minute: 0);
              onPeriodSelected(const TimeOfDay(hour: 9, minute: 0));
              if (_rootContext != null && _rootContext!.mounted) {
                _showBaseInfoDrawer(_rootContext!);
              }
            }
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
    String apiVisitType = _visitType ?? 'PACE_TOUR';

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
      // Back button callback - return to previous drawer
      if (_engagementType == 'PACE_VISIT') {
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
            if (_engagementType == 'PACE_VISIT') {
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
          eventType: _engagementType,
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
    if (_engagementType == 'HACKATHON') return true;
    if (_engagementType == 'PACE_VISIT' && _visitType == 'PACE_VISIT_FULLDAY') return true;
    return false;
  }

  /// Submit the booking with all collected data
  Future<void> _submitBooking(BuildContext context) async {
    if (_selectedDate == null || _startTime == null || _baseInfo == null) {
      ToastNotification.show(
        context,
        message: 'Missing required booking information',
        type: ToastType.error,
      );
      return;
    }

    // CRITICAL: Capture AuthProvider BEFORE any async operations
    // The WebSocket event will rebuild the Calendar and deactivate the drawer's context
    final authProvider = context.read<AuthProvider>();
    final userRole = authProvider.user?.role;

    bool dialogShown = false;

    // CRITICAL: Get Navigator reference BEFORE any async operations
    // The WebSocket event can rebuild Calendar and unmount drawer context
    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      // Show loading dialog using the captured navigator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false, // Prevent back button from closing
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
      dialogShown = true;

      final bookingData = _buildBookingData();

      final apiService = ApiService();
      final createdBooking = await apiService.createBooking(bookingData);

      // Get booking ID (userRole already captured before async operations)
      final bookingId = createdBooking['id'];


      // Build navigation route BEFORE any context operations
      final String navigationRoute;
      if (userRole == UserRole.USER) {
        navigationRoute = '/app/my-bookings?bookingId=$bookingId';
      } else {
        navigationRoute = '/app/pending';
      }

      // CRITICAL: Close dialog using the captured Navigator (not context-dependent)
      if (dialogShown) {
        try {
          navigator.pop();
          dialogShown = false;
        } catch (popError) {
        }
      }

      // Try to show success message if context is still mounted
      if (context.mounted) {
        ToastNotification.show(
          context,
          message: 'Booking created successfully!',
          type: ToastType.success,
          duration: const Duration(seconds: 2),
        );
      } else {
      }

      // Reset data BEFORE navigation
      _resetData();

      // Navigate IMMEDIATELY without delay - use WidgetsBinding to ensure it happens after current frame
      // CRITICAL: This MUST always execute, even if context is unmounted (we have _rootContext fallback)
      WidgetsBinding.instance.addPostFrameCallback((_) {

        // Try drawer context first, fallback to root context
        BuildContext? navContext;
        if (context.mounted) {
          navContext = context;
        } else if (_rootContext != null && _rootContext!.mounted) {
          navContext = _rootContext;
        } else {
        }

        if (navContext != null) {
          try {
            navContext.go(navigationRoute);
          } catch (navError) {
          }
        }
      });


    } catch (e) {

      // Close dialog using captured navigator (doesn't depend on context)
      if (dialogShown) {
        try {
          navigator.pop();
          dialogShown = false;
        } catch (popError) {
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

    } finally {
      // SAFETY NET: Ensure dialog is always closed using captured navigator

      if (dialogShown) {
        try {
          navigator.pop();
        } catch (finalError) {
        }
      }

    }
  }

  /// Build the booking data payload
  Map<String, dynamic> _buildBookingData() {
    // Determine final engagement type, visit type, and duration
    String finalEngagementType;
    String finalVisitType;
    int finalDuration;

    if (_engagementType == 'PACE_VISIT') {
      finalEngagementType = 'PACE_VISIT';
      finalVisitType = _visitType!;
      finalDuration = _visitType == 'PACE_TOUR' ? 2 : 8;
    } else if (_engagementType == 'INNOVATION_EXCHANGE') {
      finalEngagementType = 'INNOVATION_EXCHANGE';
      finalVisitType = 'INNOVATION_EXCHANGE';
      finalDuration = 8;
    } else {
      // HACKATHON
      finalEngagementType = 'HACKATHON';
      finalVisitType = 'PACE_TOUR'; // placeholder, not used for hackathon
      finalDuration = 8;
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
      case 7:
        return 'SEVEN_HOURS';
      case 8:
        return 'EIGHT_HOURS';
      default:
        return 'TWO_HOURS';
    }
  }
}
