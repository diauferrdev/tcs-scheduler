import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../models/booking.dart';
import '../widgets/booking_form_fields.dart';
import '../utils/toast_notification.dart';

class BookingFormScreen extends StatefulWidget {
  final DateTime selectedDate;
  final TimeOfDay startTime;
  final int duration;
  final bool showScaffold;
  final Booking? existingBooking;

  const BookingFormScreen({
    super.key,
    required this.selectedDate,
    required this.startTime,
    required this.duration,
    this.showScaffold = true,
    this.existingBooking,
  });

  @override
  State<BookingFormScreen> createState() => BookingFormScreenState();
}

class BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Multi-step flow state
  int _currentStep = 1; // 1, 2, 3, 4

  // Step 1: Engagement Type
  String? _engagementType; // 'PACE_VISIT', 'INNOVATION_EXCHANGE', or 'HACKATHON'

  // Step 2: Visit Type (only if PACE_VISIT selected)
  String? _visitType; // 'PACE_TOUR' or 'PACE_VISIT_FULLDAY'

  // Step 3: Base Information
  final _requesterNameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  String? _vertical;
  final _organizationNameController = TextEditingController();
  String? _organizationType;
  final _organizationTypeOtherController = TextEditingController();
  final _organizationDescriptionController = TextEditingController();
  final _objectiveInterestController = TextEditingController();
  List<String> _targetAudience = [];

  // Attendees (optional)
  List<AttendeeFormData> _attendees = [];

  // Step 4: Questionnaire (for PACE_VISIT_FULLDAY, INNOVATION_EXCHANGE, HACKATHON)
  final _questionnaireAnswers = <String, String>{
    'q1': '',
    'q2': '',
    'q3': '',
    'q4': '',
    'q5': '',
  };

  @override
  void initState() {
    super.initState();

    if (widget.existingBooking != null) {
      _prefillFromExistingBooking(widget.existingBooking!);
      // In edit mode, start at Step 3 (Base Information)
      _currentStep = 3;
    }
  }

  bool get _isEditMode => widget.existingBooking != null;

  void _prefillFromExistingBooking(Booking booking) {
    setState(() {
      // Step 1: Engagement Type
      _engagementType = booking.engagementType?.name ??
        (booking.visitType == VisitType.INNOVATION_EXCHANGE ? 'INNOVATION_EXCHANGE' : 'PACE_VISIT');

      // Step 2: Visit Type
      if (_engagementType == 'PACE_VISIT') {
        _visitType = booking.visitType.name;
      }

      // Step 3: Base Information
      _requesterNameController.text = booking.requesterName ?? '';
      _employeeIdController.text = booking.employeeId ?? '';
      _vertical = booking.vertical?.name;
      _organizationNameController.text = booking.organizationName ?? booking.companyName;
      _organizationType = booking.organizationType?.name;
      _organizationTypeOtherController.text = booking.organizationTypeOther ?? '';
      _organizationDescriptionController.text = booking.organizationDescription ?? '';
      _objectiveInterestController.text = booking.objectiveInterest ?? '';
      _targetAudience = booking.targetAudience?.map((a) => a.name).toList() ?? [];

      // Attendees (if present)
      if (booking.attendees != null && booking.attendees!.isNotEmpty) {
        _attendees = booking.attendees!.map((a) => AttendeeFormData.fromAttendee(a)).toList();
      }

      // Step 4: Questionnaire
      if (booking.questionnaireAnswers != null) {
        booking.questionnaireAnswers!.forEach((key, value) {
          if (_questionnaireAnswers.containsKey(key)) {
            _questionnaireAnswers[key] = value.toString();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _requesterNameController.dispose();
    _employeeIdController.dispose();
    _organizationNameController.dispose();
    _organizationTypeOtherController.dispose();
    _organizationDescriptionController.dispose();
    _objectiveInterestController.dispose();
    // Dispose attendees
    for (var attendee in _attendees) {
      attendee.dispose();
    }
    super.dispose();
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
      default:
        return 'TWO_HOURS';
    }
  }

  Map<String, dynamic> _buildBookingData() {
    // Determine final engagement type and visit type
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
      finalVisitType = 'PACE_TOUR'; // placeholder
      finalDuration = 8;
    }

    final bookingData = {
      // Date/Time
      'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
      'startTime': '${widget.startTime.hour.toString().padLeft(2, '0')}:${widget.startTime.minute.toString().padLeft(2, '0')}',
      'duration': _durationToEnum(finalDuration),

      // New engagement flow
      'engagementType': finalEngagementType,
      'visitType': finalVisitType,

      // Base Information
      'requesterName': _requesterNameController.text.trim(),
      'employeeId': _employeeIdController.text.trim(),
      'vertical': _vertical,
      'organizationName': _organizationNameController.text.trim(),
      'organizationType': _organizationType,
      if (_organizationType == 'OTHER')
        'organizationTypeOther': _organizationTypeOtherController.text.trim(),
      if (_organizationDescriptionController.text.trim().isNotEmpty)
        'organizationDescription': _organizationDescriptionController.text.trim(),
      if (_objectiveInterestController.text.trim().isNotEmpty)
        'objectiveInterest': _objectiveInterestController.text.trim(),
      'targetAudience': _targetAudience,

      // Questionnaire
      if (_requiresQuestionnaire())
        'questionnaireAnswers': _questionnaireAnswers,

      // Alignment call flag
      'requiresAlignmentCall': _requiresQuestionnaire(),

      // Attendees (optional)
      if (_attendees.isNotEmpty)
        'attendees': _attendees.map((a) => a.toJson()).toList(),
      'expectedAttendees': _attendees.isNotEmpty ? _attendees.length : 1,

      // Legacy compatibility fields
      'companyName': _organizationNameController.text.trim(),
      'accountName': _organizationNameController.text.trim(),
    };

    return bookingData;
  }

  bool _requiresQuestionnaire() {
    if (_engagementType == 'INNOVATION_EXCHANGE') return true;
    if (_engagementType == 'HACKATHON') return true;
    if (_engagementType == 'PACE_VISIT' && _visitType == 'PACE_VISIT_FULLDAY') return true;
    return false;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ToastNotification.show(
        context,
        message: 'Please fill in all required fields',
        type: ToastType.error,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final apiService = ApiService();

      if (_isEditMode) {
        // EDIT MODE: Update existing booking
        final bookingData = _buildBookingData();
        // Remove date/time fields (cannot be changed in edit mode)
        bookingData.remove('date');
        bookingData.remove('startTime');
        bookingData.remove('duration');


        await apiService.updateBooking(widget.existingBooking!.id, bookingData);

        if (!mounted) return;

        // Reset loading state BEFORE popping
        setState(() {
          _isSubmitting = false;
        });

        ToastNotification.show(
          context,
          message: 'Booking updated successfully! Status changed to Under Review.',
          type: ToastType.success,
        );
      } else {
        // CREATE MODE: Create new booking
        final bookingData = _buildBookingData();


        await apiService.createBooking(bookingData);

        if (!mounted) return;

        // Reset loading state BEFORE popping
        setState(() {
          _isSubmitting = false;
        });

        ToastNotification.show(
          context,
          message: 'Booking created successfully!',
          type: ToastType.success,
        );
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSubmitting = false;
      });

      ToastNotification.show(
        context,
        message: 'Error: ${e.toString()}',
        type: ToastType.error,
        duration: const Duration(seconds: 5),
      );
    }
  }

  void _nextStep() {
    if (_currentStep == 1) {
      // Validate engagement type selection
      if (_engagementType == null) {
        ToastNotification.show(
          context,
          message: 'Please select an engagement type',
          type: ToastType.warning,
        );
        return;
      }

      // If VISIT, go to step 2 (visit type selection)
      // If INNOVATION_EXCHANGE, skip to step 3 (base info)
      if (_engagementType == 'PACE_VISIT') {
        setState(() => _currentStep = 2);
      } else {
        setState(() => _currentStep = 3);
      }
    } else if (_currentStep == 2) {
      // Validate visit type selection
      if (_visitType == null) {
        ToastNotification.show(
          context,
          message: 'Please select a visit type',
          type: ToastType.warning,
        );
        return;
      }
      setState(() => _currentStep = 3);
    } else if (_currentStep == 3) {
      // Validate base information
      if (!_formKey.currentState!.validate()) {
        ToastNotification.show(
          context,
          message: 'Please fill in all required fields',
          type: ToastType.error,
        );
        return;
      }

      // If requires questionnaire, go to step 4
      // Otherwise, submit directly
      if (_requiresQuestionnaire()) {
        setState(() => _currentStep = 4);
      } else {
        _submitForm();
      }
    } else if (_currentStep == 4) {
      // Validate questionnaire
      bool allAnswered = _questionnaireAnswers.values.every((answer) => answer.trim().isNotEmpty);
      if (!allAnswered) {
        ToastNotification.show(
          context,
          message: 'Please answer all questions',
          type: ToastType.error,
        );
        return;
      }
      _submitForm();
    }
  }

  void _previousStep() {
    // In edit mode, only allow navigation between steps 3 and 4
    if (_isEditMode) {
      if (_currentStep == 4) {
        setState(() => _currentStep = 3);
      }
      // If at step 3, can't go back (it's the first step in edit mode)
      return;
    }

    // Normal create mode navigation
    if (_currentStep == 2) {
      setState(() => _currentStep = 1);
    } else if (_currentStep == 3) {
      // If came from VISIT flow, go back to step 2
      // Otherwise go back to step 1
      if (_engagementType == 'PACE_VISIT') {
        setState(() => _currentStep = 2);
      } else {
        setState(() => _currentStep = 1);
      }
    } else if (_currentStep == 4) {
      setState(() => _currentStep = 3);
    }
  }

  // Attendee management
  void _addAttendee() {
    setState(() {
      if (_attendees.length < 10) {
        _attendees.add(AttendeeFormData());
      }
    });
  }

  void _removeAttendee(int index) {
    setState(() {
      _attendees[index].dispose();
      _attendees.removeAt(index);
    });
  }

  void fillWithMockData() {
    final random = Random();
    final mockCompanies = [
      'Itaú Unibanco', 'Petrobras', 'Magazine Luiza', 'Vale', 'Telefônica Brasil',
      'Banco do Brasil', 'Bradesco', 'Natura', 'Ambev', 'Embraer'
    ];
    final mockNames = [
      'Ana Paula Silva', 'Carlos Eduardo Santos', 'Marina Oliveira',
      'Roberto Mendes', 'Fernanda Costa', 'Lucas Almeida'
    ];

    setState(() {
      // Step 1: Set engagement type randomly
      _engagementType = ['PACE_VISIT', 'INNOVATION_EXCHANGE', 'HACKATHON'][random.nextInt(3)];

      // Step 2: If PACE_VISIT, set visit type
      if (_engagementType == 'PACE_VISIT') {
        _visitType = random.nextBool() ? 'PACE_TOUR' : 'PACE_VISIT_FULLDAY';
      }

      // Step 3: Fill base information
      _requesterNameController.text = mockNames[random.nextInt(mockNames.length)];
      _employeeIdController.text = '${random.nextInt(900000) + 100000}';
      _vertical = [
        'BFSI', 'RETAIL_CPG', 'LIFE_SCIENCES_HEALTHCARE', 'MANUFACTURING',
        'HI_TECH', 'CMT', 'ERU'
      ][random.nextInt(7)];
      _organizationNameController.text = mockCompanies[random.nextInt(mockCompanies.length)];
      _organizationType = [
        'EXISTING_CUSTOMER', 'PROSPECT', 'PARTNER'
      ][random.nextInt(3)];
      _organizationDescriptionController.text = 'Leading company in their sector';
      _objectiveInterestController.text = 'Explore digital transformation solutions and innovation capabilities';
      _targetAudience = ['C-Level', 'Technology Leaders'];

      // Step 4: Fill questionnaire if needed
      if (_requiresQuestionnaire()) {
        _questionnaireAnswers['q1'] = 'Cloud migration and AI/ML integration';
        _questionnaireAnswers['q2'] = 'Digital transformation, customer experience, data analytics';
        _questionnaireAnswers['q3'] = 'CTO, VP of Engineering, Innovation Director';
        _questionnaireAnswers['q4'] = 'Technology modernization and scalability challenges';
        _questionnaireAnswers['q5'] = 'Understanding best practices and real-world use cases';
      }
    });

    ToastNotification.show(
      context,
      message: 'Mock data loaded',
      type: ToastType.success,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget formContent = Form(
      key: _formKey,
      child: Column(
        children: [
          // Header with date/time
          _buildHeader(isDark),

          // Content based on current step
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildStepContent(isDark),
            ),
          ),

          // Navigation buttons
          _buildNavigationButtons(isDark),
        ],
      ),
    );

    if (!widget.showScaffold) {
      return formContent;
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_isEditMode ? 'Edit Booking' : 'New Booking'),
        elevation: 0,
        actions: [
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Fill with Mock Data',
              onPressed: fillWithMockData,
            ),
        ],
      ),
      body: formContent,
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : const Color(0xFFF9FAFB),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator (only in create mode)
          if (!_isEditMode) ...[
            Row(
              children: [
                _buildStepIndicator(1, _currentStep >= 1, isDark),
                if (_engagementType == 'PACE_VISIT') ...[
                  _buildStepConnector(isDark),
                  _buildStepIndicator(2, _currentStep >= 2, isDark),
                ],
                _buildStepConnector(isDark),
                _buildStepIndicator(3, _currentStep >= 3, isDark),
                if (_requiresQuestionnaire()) ...[
                  _buildStepConnector(isDark),
                  _buildStepIndicator(4, _currentStep >= 4, isDark),
                ],
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Step title
          Text(
            _getStepTitle(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _getStepSubtitle(),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),

          // Selected date/time
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isEditMode
                  ? (isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: _isEditMode
                  ? Border.all(
                      color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(widget.selectedDate),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  widget.startTime.format(context),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                if (_isEditMode) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, bool isActive, bool isDark) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive
            ? Colors.black
            : (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Text(
          '$step',
          style: TextStyle(
            color: isActive ? Colors.white : (isDark ? Colors.grey[600] : Colors.grey[400]),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStepConnector(bool isDark) {
    return Container(
      width: 40,
      height: 2,
      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return 'Select Engagement Type';
      case 2:
        return 'Select Visit Type';
      case 3:
        return 'Base Information';
      case 4:
        return 'Questionnaire';
      default:
        return '';
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 1:
        return 'Choose between a visit or innovation exchange';
      case 2:
        return 'Choose the type of visit experience';
      case 3:
        return 'Provide organization and requester details';
      case 4:
        return 'Answer questions to help us prepare';
      default:
        return '';
    }
  }

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case 1:
        return _buildStep1EngagementType(isDark);
      case 2:
        return _buildStep2VisitType(isDark);
      case 3:
        return _buildStep3BaseInfo(isDark);
      case 4:
        return _buildStep4Questionnaire(isDark);
      default:
        return Container();
    }
  }

  Widget _buildStep1EngagementType(bool isDark) {
    return Column(
      children: [
        _buildEngagementTypeCard(
          'PACE_VISIT',
          'Pace Visit',
          'Quick tour or full-day experience',
          Icons.tour,
          isDark,
        ),
        const SizedBox(height: 16),
        _buildEngagementTypeCard(
          'INNOVATION_EXCHANGE',
          'Innovation Exchange',
          'Multi-day innovation session with 5 weeks preparation',
          Icons.lightbulb_outline,
          isDark,
        ),
        const SizedBox(height: 16),
        _buildEngagementTypeCard(
          'HACKATHON',
          'Hackathon',
          'Multi-day collaborative hackathon event',
          Icons.code,
          isDark,
        ),
      ],
    );
  }

  static const _prepRequiredTypes = {'INNOVATION_EXCHANGE', 'HACKATHON'};
  static const int _requiredPrepBusinessDays = 3;

  int _businessDaysBetween(DateTime from, DateTime to) {
    int count = 0;
    DateTime day = DateTime(from.year, from.month, from.day).add(const Duration(days: 1));
    final target = DateTime(to.year, to.month, to.day);
    while (day.isBefore(target)) {
      if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
        count++;
      }
      day = day.add(const Duration(days: 1));
    }
    return count;
  }

  DateTime _addBusinessDays(DateTime from, int n) {
    DateTime day = DateTime(from.year, from.month, from.day);
    int added = 0;
    while (added < n) {
      day = day.add(const Duration(days: 1));
      if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
        added++;
      }
    }
    return day;
  }

  bool _isPrepGreyedOut(String value) {
    if (!_prepRequiredTypes.contains(value)) return false;
    final today = DateTime.now();
    return _businessDaysBetween(today, widget.selectedDate) < _requiredPrepBusinessDays;
  }

  String _nextAvailableDateLabel() {
    final next = _addBusinessDays(DateTime.now(), _requiredPrepBusinessDays);
    return '${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}/${next.year}';
  }

  Widget _buildEngagementTypeCard(
    String value,
    String title,
    String subtitle,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _engagementType == value;
    final greyedOut = _isPrepGreyedOut(value);

    return Opacity(
      opacity: greyedOut ? 0.4 : 1.0,
      child: InkWell(
        onTap: greyedOut
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Requires $_requiredPrepBusinessDays prep days. Next available: ${_nextAvailableDateLabel()}',
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            : () {
                setState(() {
                  _engagementType = value;
                  if (value != 'PACE_VISIT') {
                    _visitType = null;
                  }
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected && !greyedOut
                ? (isDark ? const Color(0xFF18181B) : Colors.white)
                : (isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected && !greyedOut
                  ? Colors.black
                  : (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
              width: isSelected && !greyedOut ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected && !greyedOut
                      ? Colors.black
                      : (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isSelected && !greyedOut
                      ? Colors.white
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    if (greyedOut) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Requires $_requiredPrepBusinessDays prep days. Next available: ${_nextAvailableDateLabel()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected && !greyedOut)
                const Icon(Icons.check_circle, color: Colors.black, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep2VisitType(bool isDark) {
    return Column(
      children: [
        _buildVisitTypeCard(
          'PACE_TOUR',
          'Pace Tour',
          '2 hours (14h-16h)',
          'Quick demonstration and overview',
          Icons.schedule,
          isDark,
        ),
        const SizedBox(height: 16),
        _buildVisitTypeCard(
          'PACE_VISIT_FULLDAY',
          'Pace Visit Fullday',
          'Up to 8 hours',
          'Full-day immersive experience with questionnaire',
          Icons.event,
          isDark,
        ),
      ],
    );
  }

  Widget _buildVisitTypeCard(
    String value,
    String title,
    String duration,
    String description,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _visitType == value;

    return InkWell(
      onTap: () {
        setState(() {
          _visitType = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF18181B) : Colors.white)
              : (isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.black
                : (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.black
                    : (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    duration,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.black, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3BaseInfo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Requester Name
        TextFormField(
          controller: _requesterNameController,
          decoration: InputDecoration(
            labelText: 'Your Name',
            hintText: 'Enter your full name',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Employee ID
        TextFormField(
          controller: _employeeIdController,
          decoration: InputDecoration(
            labelText: 'Employee ID',
            hintText: 'Enter your TCS employee ID',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.badge),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Employee ID is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Vertical
        DropdownButtonFormField<String>(
          initialValue: _vertical,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Vertical',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.business_center),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          items: const [
            DropdownMenuItem(
              value: 'BFSI',
              child: Text(
                'BFSI (Banking, Financial Services & Insurance)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'RETAIL_CPG',
              child: Text(
                'Retail & CPG',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'LIFE_SCIENCES_HEALTHCARE',
              child: Text(
                'Life Sciences & Healthcare',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'MANUFACTURING',
              child: Text(
                'Manufacturing',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'HI_TECH',
              child: Text(
                'Hi-Tech',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'CMT',
              child: Text(
                'CMT (Communications, Media & Technology)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'ERU',
              child: Text(
                'ERU (Energy, Resources & Utilities)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'TRAVEL_HOSPITALITY',
              child: Text(
                'Travel & Hospitality',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'PUBLIC_SERVICES',
              child: Text(
                'Public Services',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'BUSINESS_SERVICES',
              child: Text(
                'Business Services',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          validator: (value) {
            if (value == null) {
              return 'Please select a vertical';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {
              _vertical = value;
            });
          },
        ),
        const SizedBox(height: 16),

        // Organization Name
        TextFormField(
          controller: _organizationNameController,
          decoration: InputDecoration(
            labelText: 'Organization Name',
            hintText: 'Enter the organization/company name',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.business),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Organization name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Organization Type
        DropdownButtonFormField<String>(
          initialValue: _organizationType,
          decoration: InputDecoration(
            labelText: 'Organization Type',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.category),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          items: const [
            DropdownMenuItem(value: 'EXISTING_CUSTOMER', child: Text('Existing Customer')),
            DropdownMenuItem(value: 'PROSPECT', child: Text('Prospect')),
            DropdownMenuItem(value: 'PARTNER', child: Text('Partner')),
            DropdownMenuItem(value: 'GOVERNMENTAL_INSTITUTION', child: Text('Governmental Institution')),
            DropdownMenuItem(value: 'OTHER', child: Text('Other')),
          ],
          validator: (value) {
            if (value == null) {
              return 'Please select organization type';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {
              _organizationType = value;
            });
          },
        ),
        const SizedBox(height: 16),

        // Organization Type Other (conditional)
        if (_organizationType == 'OTHER') ...[
          TextFormField(
            controller: _organizationTypeOtherController,
            decoration: InputDecoration(
              labelText: 'Specify Organization Type',
              hintText: 'Please specify the type',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.edit),
              filled: true,
              fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
            ),
            validator: (value) {
              if (_organizationType == 'OTHER' && (value == null || value.trim().isEmpty)) {
                return 'Please specify organization type';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
        ],

        // Organization Description
        TextFormField(
          controller: _organizationDescriptionController,
          decoration: InputDecoration(
            labelText: 'Organization Description (optional)',
            hintText: 'Brief description of the organization',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Objective/Interest
        TextFormField(
          controller: _objectiveInterestController,
          decoration: InputDecoration(
            labelText: 'Objective / Interest in Pace (optional)',
            hintText: 'What do you hope to learn or achieve?',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Target Audience (Multi-select)
        _buildTargetAudienceMultiSelect(isDark),
        const SizedBox(height: 24),

        // Attendees Section (Optional)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attendees (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            if (_attendees.length < 10)
              TextButton.icon(
                onPressed: _addAttendee,
                icon: Icon(Icons.add, color: isDark ? Colors.white : Colors.black, size: 18),
                label: Text(
                  'Add Attendee',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Add information about attendees for this visit (optional)',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),

        // Attendees List
        if (_attendees.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _attendees.length,
            itemBuilder: (context, index) {
              return AttendeeCard(
                attendee: _attendees[index],
                index: index,
                onRemove: () => _removeAttendee(index),
                onUpdate: setState,
                enabled: true,
                initiallyExpanded: index == _attendees.length - 1, // Expand last added
              );
            },
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'No attendees added yet. Click "Add Attendee" to add visitor information.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTargetAudienceMultiSelect(bool isDark) {
    const availableOptions = [
      'C-Level',
      'Technology Leaders',
      'Business Leaders',
      'Innovation Team',
      'Technical Team',
    ];

    return InkWell(
      onTap: () async {
        final selectedItems = List<String>.from(_targetAudience);

        await showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
                  title: Text(
                    'Select Target Audience',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: availableOptions.map((option) {
                        final isSelected = selectedItems.contains(option);
                        return CheckboxListTile(
                          title: Text(
                            option,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          value: isSelected,
                          activeColor: Colors.black,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedItems.add(option);
                              } else {
                                selectedItems.remove(option);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _targetAudience = selectedItems;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirm'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Target Audience',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.groups),
          filled: true,
          fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: _targetAudience.isEmpty
            ? Text(
                'Select target audience',
                style: TextStyle(
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _targetAudience.map((audience) {
                  return Chip(
                    label: Text(
                      audience,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onDeleted: () {
                      setState(() {
                        _targetAudience.remove(audience);
                      });
                    },
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildStep4Questionnaire(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFBAE6FD),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: isDark ? Colors.blue[300] : Colors.blue[700],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Please answer these questions to help us prepare a tailored experience for you.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.blue[200] : Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildQuestionField(
          'q1',
          '1. What are the main technology areas you want to explore?',
          isDark,
        ),
        const SizedBox(height: 20),

        _buildQuestionField(
          'q2',
          '2. What are your key business challenges or focus areas?',
          isDark,
        ),
        const SizedBox(height: 20),

        _buildQuestionField(
          'q3',
          '3. Who will be attending and what are their roles?',
          isDark,
        ),
        const SizedBox(height: 20),

        _buildQuestionField(
          'q4',
          '4. What specific problems are you looking to solve?',
          isDark,
        ),
        const SizedBox(height: 20),

        _buildQuestionField(
          'q5',
          '5. What do you hope to take away from this session?',
          isDark,
        ),
      ],
    );
  }

  Widget _buildQuestionField(String key, String question, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _questionnaireAnswers[key],
          decoration: InputDecoration(
            hintText: 'Your answer...',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          maxLines: 3,
          onChanged: (value) {
            _questionnaireAnswers[key] = value;
          },
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0A0A0B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button (hide in edit mode at step 3, since it's the first editable step)
          if (_currentStep > 1 && !(_isEditMode && _currentStep == 3))
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _previousStep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  side: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          if (_currentStep > 1 && !(_isEditMode && _currentStep == 3)) const SizedBox(width: 12),

          // Next/Submit button
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: Colors.grey,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      _getNextButtonLabel(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _getNextButtonLabel() {
    if (_currentStep == 3 && !_requiresQuestionnaire()) {
      return _isEditMode ? 'Update Booking' : 'Create Booking';
    }
    if (_currentStep == 4) {
      return _isEditMode ? 'Update Booking' : 'Create Booking';
    }
    return 'Next';
  }
}
