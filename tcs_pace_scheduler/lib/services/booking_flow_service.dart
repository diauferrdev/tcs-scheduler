import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/booking_flow/engagement_type_drawer.dart';
import '../screens/booking_flow/visit_type_drawer.dart';
import '../screens/booking_flow/base_info_drawer.dart';
import '../screens/booking_flow/questionnaire_drawer.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

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
  Function(DateTime, Function(TimeOfDay, int))? _showSlotPicker;

  /// Start the booking flow with period selection integration
  Future<void> startBookingFlowWithPeriodSelection(
    BuildContext context, {
    required DateTime selectedDate,
    required Function(TimeOfDay startTime) onPeriodSelected,
    required Function(DateTime date, String visitType) loadAvailability,
    required Function(DateTime date, Function(TimeOfDay startTime, int duration) onSlotSelected) showSlotPicker,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing booking configuration'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Map visit type to API visitType for availability check
    // PACE_TOUR uses QUICK_TOUR, others use INNOVATION_EXCHANGE
    String apiVisitType;
    if (_visitType == 'PACE_TOUR') {
      apiVisitType = 'QUICK_TOUR';
    } else {
      apiVisitType = 'INNOVATION_EXCHANGE';
    }

    // Load availability for the selected date and visit type - WAIT for it to complete
    await _loadAvailability!(_selectedDate!, apiVisitType);

    // Show the slot picker drawer and capture the selected time
    _showSlotPicker!(_selectedDate!, (TimeOfDay startTime, int duration) {
      _startTime = startTime;

      // Notify parent that period was selected
      onPeriodSelected(startTime);

      // Show next drawer immediately (drawer has its own confirm button now)
      if (_rootContext != null && _rootContext!.mounted) {
        _showBaseInfoDrawer(_rootContext!);
      }
    });
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
          onNext: (data) async {
            _baseInfo = data;
            Navigator.pop(context);

            // Check if questionnaire is needed
            if (_requiresQuestionnaire()) {
              _showQuestionnaireDrawer(context);
            } else {
              // Wait for submit to complete
              await _submitBooking(context);
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
          onSubmit: (answers) async {
            _questionnaireAnswers = answers;
            Navigator.pop(context);
            // Wait for submit to complete before returning
            await _submitBooking(context);
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
    if (_selectedDate == null || _startTime == null || _baseInfo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Missing required booking information'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool dialogShown = false;

    try {
      // Show loading dialog
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

      final bookingData = _buildBookingData();
      final apiService = ApiService();
      final createdBooking = await apiService.createBooking(bookingData);

      // SUCCESS: Close dialog and show success
      if (dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to My Bookings
        Future.delayed(const Duration(milliseconds: 500), () {
          if (context.mounted) {
            context.go('/my-bookings', extra: {'bookingId': createdBooking['id']});
          }
        });
      }

      _resetData();
    } catch (e) {
      // ERROR: Close dialog and show error
      if (dialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating booking: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      // SAFETY NET: Ensure dialog is always closed
      if (dialogShown) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Ignore if already closed
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
