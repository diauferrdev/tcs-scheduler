import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math';
import '../services/api_service.dart';
import '../services/attachment_service.dart';
import '../widgets/attachment_manager.dart';
import '../models/booking.dart';

class BookingFormScreen extends StatefulWidget {
  final DateTime selectedDate;
  final TimeOfDay startTime;
  final int duration;
  final bool showScaffold; // Whether to show Scaffold wrapper (false when used in drawer)
  final Booking? existingBooking; // CRITICAL: Draft booking to prefill form with

  const BookingFormScreen({
    Key? key,
    required this.selectedDate,
    required this.startTime,
    required this.duration,
    this.showScaffold = true,
    this.existingBooking, // Optional draft booking
  }) : super(key: key);

  @override
  State<BookingFormScreen> createState() => BookingFormScreenState();
}

class BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  // Visit Type & Duration
  String _visitType = 'INNOVATION_EXCHANGE';
  int? _selectedDuration; // For Innovation Exchange (4, 5, or 6 hours)

  // Section 1: Account & Company Information
  final _accountNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  String? _companySector;
  String? _companyVertical;
  String? _companySize;

  // Section 2: Visit Details
  final _venueController = TextEditingController();
  final _overallThemeController = TextEditingController();
  DateTime? _lastInnovationDay;

  // Section 3: Event Type & Deal Information
  String _eventType = 'TCS';
  final _partnerNameController = TextEditingController();
  String _dealStatus = 'SWON';
  bool _attachHeadApproval = false;

  // Section 4: Attendees
  List<AttendeeData> _attendees = [AttendeeData()];

  // Section 5: Additional Notes
  final _additionalNotesController = TextEditingController();

  // Attachments
  List<File> _localAttachments = [];
  List<String> _uploadedAttachmentUrls = [];
  bool _isUploadingAttachments = false;

  @override
  void initState() {
    super.initState();

    // CRITICAL: Prefill form if editing an existing booking (draft)
    if (widget.existingBooking != null) {
      _prefillFromExistingBooking(widget.existingBooking!);
    } else {
      // Initialize duration based on widget.duration
      if (widget.duration == 2) {
        _visitType = 'QUICK_TOUR';
      } else if (widget.duration >= 4 && widget.duration <= 6) {
        _visitType = 'INNOVATION_EXCHANGE';
        _selectedDuration = widget.duration;
      } else {
        // Default to Innovation Exchange with 4 hours
        _visitType = 'INNOVATION_EXCHANGE';
        _selectedDuration = 4;
      }
    }
  }

  /// CRITICAL: Prefill all form fields from an existing booking (for draft editing)
  void _prefillFromExistingBooking(Booking booking) {
    // Section 1: Account & Company Information
    _accountNameController.text = booking.accountName ?? '';
    _companyNameController.text = booking.companyName;
    _companySector = booking.companySector;
    _companyVertical = booking.companyVertical;
    _companySize = booking.companySize;

    // Visit Type & Duration
    _visitType = booking.visitType.toString().split('.').last;
    final durationHours = _durationEnumToInt(booking.duration);
    if (durationHours == 2) {
      _visitType = 'QUICK_TOUR';
    } else {
      _visitType = 'INNOVATION_EXCHANGE';
      _selectedDuration = durationHours;
    }

    // Section 2: Visit Details
    _venueController.text = booking.venue ?? '';
    _overallThemeController.text = booking.overallTheme ?? '';
    _lastInnovationDay = booking.lastInnovationDay;

    // Section 3: Event Type & Deal Information
    _eventType = booking.eventType.toString().split('.').last;
    _partnerNameController.text = booking.partnerName ?? '';
    _dealStatus = booking.dealStatus.toString().split('.').last;
    _attachHeadApproval = booking.attachHeadApproval ?? false;

    // Section 4: Attendees
    if (booking.attendees != null && booking.attendees!.isNotEmpty) {
      // Clear default attendee
      for (var attendee in _attendees) {
        attendee.dispose();
      }
      _attendees.clear();

      // Create attendees from booking
      for (var bookingAttendee in booking.attendees!) {
        final attendeeData = AttendeeData();
        attendeeData.nameController.text = bookingAttendee.name;
        attendeeData.emailController.text = bookingAttendee.email;
        attendeeData.roleController.text = bookingAttendee.role ?? '';
        attendeeData.positionController.text = bookingAttendee.position ?? '';
        attendeeData.tcsSupporter = bookingAttendee.tcsSupporter.toString().split('.').last;
        attendeeData.understandingController.text = bookingAttendee.understandingOfTCS ?? '';
        attendeeData.focusAreasController.text = bookingAttendee.focusAreas ?? '';
        attendeeData.yearsWithTcsController.text = bookingAttendee.yearsWorkingWithTCS?.toString() ?? '';
        attendeeData.educationController.text = bookingAttendee.educationalQualification ?? '';
        attendeeData.careerBackgroundController.text = bookingAttendee.careerBackground ?? '';
        attendeeData.linkedinController.text = bookingAttendee.linkedinProfile ?? '';
        _attendees.add(attendeeData);
      }
    }

    // Section 5: Additional Notes
    _additionalNotesController.text = booking.additionalNotes ?? '';

    // Attachments
    if (booking.attachments != null && booking.attachments!.isNotEmpty) {
      _uploadedAttachmentUrls = List<String>.from(booking.attachments!);
    }
  }

  /// Convert duration enum to integer hours
  int _durationEnumToInt(VisitDuration duration) {
    switch (duration) {
      case VisitDuration.ONE_HOUR:
        return 1;
      case VisitDuration.TWO_HOURS:
        return 2;
      case VisitDuration.THREE_HOURS:
        return 3;
      case VisitDuration.FOUR_HOURS:
        return 4;
      case VisitDuration.FIVE_HOURS:
        return 5;
      case VisitDuration.SIX_HOURS:
        return 6;
    }
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _companyNameController.dispose();
    _venueController.dispose();
    _overallThemeController.dispose();
    _partnerNameController.dispose();
    _additionalNotesController.dispose();
    for (var attendee in _attendees) {
      attendee.dispose();
    }
    super.dispose();
  }

  // Get final duration based on visit type
  int _getFinalDuration() {
    if (_visitType == 'QUICK_TOUR') {
      return 2;
    } else {
      return _selectedDuration ?? 4;
    }
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
        return 'FOUR_HOURS';
    }
  }

  Map<String, dynamic> _buildBookingData() {
    final finalDuration = _getFinalDuration();

    return {
      'accountName': _accountNameController.text.trim(),
      'companyName': _companyNameController.text.trim(),
      'companySector': _companySector,
      'companyVertical': _companyVertical,
      'companySize': _companySize,
      'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
      'startTime': '${widget.startTime.hour.toString().padLeft(2, '0')}:${widget.startTime.minute.toString().padLeft(2, '0')}',
      'duration': _durationToEnum(finalDuration),
      'visitType': _visitType,
      'venue': _venueController.text.trim().isNotEmpty
          ? _venueController.text.trim()
          : null,
      'expectedAttendees': _attendees.length,
      'overallTheme': _overallThemeController.text.trim().isNotEmpty
          ? _overallThemeController.text.trim()
          : null,
      'lastInnovationDay': _lastInnovationDay != null
          ? DateFormat('yyyy-MM-dd').format(_lastInnovationDay!)
          : null,
      'eventType': _eventType,
      if (_eventType == 'PARTNER' && _partnerNameController.text.trim().isNotEmpty)
        'partnerName': _partnerNameController.text.trim(),
      'dealStatus': _dealStatus,
      'attachHeadApproval': _attachHeadApproval,
      'attendees': _attendees
          .map((a) => {
                'name': a.nameController.text.trim(),
                'email': a.emailController.text.trim(),
                'role': a.roleController.text.trim().isNotEmpty
                    ? a.roleController.text.trim()
                    : null,
                'position': a.positionController.text.trim().isNotEmpty
                    ? a.positionController.text.trim()
                    : null,
                'tcsSupporter': a.tcsSupporter,
                'understandingOfTCS':
                    a.understandingController.text.trim().isNotEmpty
                        ? a.understandingController.text.trim()
                        : null,
                'focusAreas': a.focusAreasController.text.trim().isNotEmpty
                    ? a.focusAreasController.text.trim()
                    : null,
                'yearsWorkingWithTCS': a.yearsWithTcsController.text.trim().isNotEmpty
                    ? int.parse(a.yearsWithTcsController.text.trim())
                    : null,
                'educationalQualification':
                    a.educationController.text.trim().isNotEmpty
                        ? a.educationController.text.trim()
                        : null,
                'careerBackground':
                    a.careerBackgroundController.text.trim().isNotEmpty
                        ? a.careerBackgroundController.text.trim()
                        : null,
                'linkedinProfile':
                    a.linkedinController.text.trim().isNotEmpty
                        ? a.linkedinController.text.trim()
                        : null,
              })
          .toList(),
      'additionalNotes': _additionalNotesController.text.trim().isNotEmpty
          ? _additionalNotesController.text.trim()
          : null,
      if (_uploadedAttachmentUrls.isNotEmpty)
        'attachments': _uploadedAttachmentUrls,
    };
  }

  Future<void> _uploadAttachments() async {
    if (_localAttachments.isEmpty) return;

    setState(() {
      _isUploadingAttachments = true;
    });

    try {
      final attachmentService = AttachmentService();
      final uploadedFiles = await attachmentService.uploadMultipleAttachments(_localAttachments);

      // Add uploaded URLs to the list
      for (final fileInfo in uploadedFiles) {
        _uploadedAttachmentUrls.add(fileInfo['url'] as String);
      }

      // Clear local files after successful upload
      _localAttachments.clear();

      setState(() {
        _isUploadingAttachments = false;
      });
    } catch (e) {
      setState(() {
        _isUploadingAttachments = false;
      });
      rethrow;
    }
  }

  Future<void> _saveDraft() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload attachments if any
      if (_localAttachments.isNotEmpty) {
        try {
          await _uploadAttachments();
        } catch (e) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload attachments: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      }

      final bookingData = _buildBookingData();

      // Debug: Print booking data
      print('[BOOKING] Saving draft: ${json.encode(bookingData)}');

      // Use ApiService to create booking as draft
      final apiService = ApiService();
      await apiService.createBooking(bookingData, isDraft: true);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft saved successfully! You can continue editing later.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving draft: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Upload attachments if any
      if (_localAttachments.isNotEmpty) {
        try {
          await _uploadAttachments();
        } catch (e) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload attachments: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          return;
        }
      }

      final bookingData = _buildBookingData();

      // Debug: Print booking data
      print('[BOOKING] Sending booking data: ${json.encode(bookingData)}');

      // Use ApiService to create booking
      final apiService = ApiService();
      await apiService.createBooking(bookingData);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Booking created successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _addAttendee() {
    if (_attendees.length < 3) {
      setState(() {
        _attendees.add(AttendeeData());
      });
    }
  }

  void _removeAttendee(int index) {
    if (_attendees.length > 1) {
      setState(() {
        _attendees[index].dispose();
        _attendees.removeAt(index);
      });
    }
  }

  // Make fillWithMockData public so it can be called from drawer
  void fillWithMockData() {
    final random = Random();
    final mockVariations = [
      // Variation 1: Itaú Unibanco - Banking
      {
        'accountName': 'Itaú Unibanco',
        'companyName': 'Itaú Unibanco',
        'companySector': 'Finance',
        'companyVertical': 'Banking',
        'companySize': '5000+',
        'venue': 'PacePort São Paulo',
        'overallTheme': 'Accelerate digital transformation with AI and Cloud solutions',
        'eventType': 'TCS',
        'dealStatus': 'WON',
        'attachHeadApproval': true,
        'attendeeName': 'Carlos Eduardo Santos',
        'attendeeEmail': 'carlos.santos@itau.com.br',
        'attendeeRole': 'Decision Maker',
        'attendeePosition': 'CTO',
        'tcsSupporter': 'SUPPORTER',
        'understanding': 'High understanding of TCS capabilities in digital banking transformation',
        'focusAreas': 'Cloud Migration, AI/ML, Open Banking APIs',
        'yearsWithTCS': '4',
        'education': 'MBA in Technology Management, Computer Science',
        'careerBackground': 'Technology leader with 15+ years in banking sector',
        'linkedin': 'https://linkedin.com/in/carloseduardosantos',
        'notes': 'Visit approved by executive committee. Interest in generative AI use cases.',
      },
      // Variation 2: Petrobras - Energy
      {
        'accountName': 'Petrobras',
        'companyName': 'Petrobras',
        'companySector': 'Energy',
        'companyVertical': 'Oil & Gas',
        'companySize': '5000+',
        'venue': 'PacePort São Paulo',
        'overallTheme': 'Modernize legacy infrastructure and migrate to cloud',
        'eventType': 'TCS',
        'dealStatus': 'SWON',
        'attachHeadApproval': true,
        'attendeeName': 'Maria Fernanda Oliveira',
        'attendeeEmail': 'maria.oliveira@petrobras.com.br',
        'attendeeRole': 'Decision Maker',
        'attendeePosition': 'CIO',
        'tcsSupporter': 'NEUTRAL',
        'understanding': 'Familiar with TCS energy solutions, seeking cloud migration expertise',
        'focusAreas': 'Cloud Infrastructure, Data Analytics, IoT',
        'yearsWithTCS': '2',
        'education': 'Engineering degree, Executive MBA',
        'careerBackground': 'IT executive with 20+ years in oil & gas industry',
        'linkedin': 'https://linkedin.com/in/mariafernandaoliveira',
        'notes': 'Q1 priority project. Cloud architecture demonstration required.',
      },
      // Variation 3: Magazine Luiza - Retail (Partner with Insper)
      {
        'accountName': 'Magazine Luiza',
        'companyName': 'Magazine Luiza',
        'companySector': 'Retail',
        'companyVertical': 'E-commerce',
        'companySize': '5000+',
        'venue': 'PacePort São Paulo',
        'overallTheme': 'Transform customer experience with digital',
        'eventType': 'PARTNER',
        'partnerName': 'Insper',
        'dealStatus': 'WON',
        'attachHeadApproval': true,
        'attendeeName': 'Roberto Silva Mendes',
        'attendeeEmail': 'roberto.mendes@magazineluiza.com.br',
        'attendeeRole': 'Decision Maker',
        'attendeePosition': 'CDO',
        'tcsSupporter': 'SUPPORTER',
        'understanding': 'Strong understanding of TCS retail and e-commerce solutions',
        'focusAreas': 'Omnichannel, Customer Analytics, AI/ML',
        'yearsWithTCS': '3',
        'education': 'Business Administration, MBA from Insper',
        'careerBackground': 'Digital transformation leader with 12+ years in retail',
        'linkedin': 'https://linkedin.com/in/robertomendes',
        'notes': 'Joint event with Insper. Focus on showcasing AI capabilities for retail.',
      },
      // Variation 4: Vale - Manufacturing/Mining
      {
        'accountName': 'Vale',
        'companyName': 'Vale',
        'companySector': 'Manufacturing',
        'companyVertical': 'Mining',
        'companySize': '5000+',
        'venue': 'PacePort São Paulo',
        'overallTheme': 'Implement data strategy and advanced analytics',
        'eventType': 'TCS',
        'dealStatus': 'WON',
        'attachHeadApproval': true,
        'attendeeName': 'Ana Paula Costa',
        'attendeeEmail': 'ana.costa@vale.com',
        'attendeeRole': 'Influencer',
        'attendeePosition': 'VP of Innovation',
        'tcsSupporter': 'SUPPORTER',
        'understanding': 'High understanding of TCS data and analytics capabilities',
        'focusAreas': 'Data Platform, Advanced Analytics, Automation',
        'yearsWithTCS': '5',
        'education': 'Engineering, MBA in Data Science',
        'careerBackground': 'Innovation leader with 15+ years in mining sector',
        'linkedin': 'https://linkedin.com/in/anapaulacosta',
        'notes': 'Strategic meeting with C-Level. Present data platform and AI use cases.',
      },
      // Variation 5: Telefônica Brasil (Vivo) - Telecommunications
      {
        'accountName': 'Telefônica Brasil',
        'companyName': 'Telefônica Brasil (Vivo)',
        'companySector': 'Telecommunications',
        'companyVertical': 'Telecommunications',
        'companySize': '5000+',
        'venue': 'PacePort São Paulo',
        'overallTheme': 'Strengthen cybersecurity posture and compliance',
        'eventType': 'TCS',
        'dealStatus': 'SWON',
        'attachHeadApproval': false,
        'attendeeName': 'João Pedro Lima',
        'attendeeEmail': 'joao.lima@telefonica.com.br',
        'attendeeRole': 'Decision Maker',
        'attendeePosition': 'CISO',
        'tcsSupporter': 'NEUTRAL',
        'understanding': 'Aware of TCS cybersecurity solutions, seeking deeper technical understanding',
        'focusAreas': 'Cybersecurity, Cloud Security, Compliance',
        'yearsWithTCS': '1',
        'education': 'Computer Science, Cybersecurity Certifications',
        'careerBackground': 'Security professional with 10+ years in telecommunications',
        'linkedin': 'https://linkedin.com/in/joaopedrolima',
        'notes': 'Technical team will participate. Focus on security and regulatory compliance.',
      },
    ];

    final selectedMock = mockVariations[random.nextInt(mockVariations.length)];

    setState(() {
      // Section 1: Account & Company Information
      _accountNameController.text = selectedMock['accountName'] as String;
      _companyNameController.text = selectedMock['companyName'] as String;
      _companySector = selectedMock['companySector'] as String;
      _companyVertical = selectedMock['companyVertical'] as String;
      _companySize = selectedMock['companySize'] as String;

      // Section 2: Visit Details
      _venueController.text = selectedMock['venue'] as String;
      _overallThemeController.text = selectedMock['overallTheme'] as String;
      _lastInnovationDay = DateTime.now().subtract(Duration(days: random.nextInt(365) + 90));

      // Section 3: Event Type & Deal Information
      _eventType = selectedMock['eventType'] as String;
      if (_eventType == 'PARTNER') {
        _partnerNameController.text = selectedMock['partnerName'] as String? ?? 'Insper';
      }
      _dealStatus = selectedMock['dealStatus'] as String;
      _attachHeadApproval = selectedMock['attachHeadApproval'] as bool;

      // Section 4: Attendees - Generate random number of attendees (1-3)
      final numAttendees = random.nextInt(3) + 1; // 1, 2, or 3

      // Clear existing attendees except the first one
      while (_attendees.length > 1) {
        _attendees.last.dispose();
        _attendees.removeLast();
      }

      // Add more attendees if needed
      while (_attendees.length < numAttendees) {
        _attendees.add(AttendeeData());
      }

      // Fill first attendee with mock data
      if (_attendees.isNotEmpty) {
        _attendees[0].nameController.text = selectedMock['attendeeName'] as String;
        _attendees[0].emailController.text = selectedMock['attendeeEmail'] as String;
        _attendees[0].roleController.text = selectedMock['attendeeRole'] as String;
        _attendees[0].positionController.text = selectedMock['attendeePosition'] as String;
        _attendees[0].tcsSupporter = selectedMock['tcsSupporter'] as String;
        _attendees[0].understandingController.text = selectedMock['understanding'] as String;
        _attendees[0].focusAreasController.text = selectedMock['focusAreas'] as String;
        _attendees[0].yearsWithTcsController.text = selectedMock['yearsWithTCS'] as String;
        _attendees[0].educationController.text = selectedMock['education'] as String;
        _attendees[0].careerBackgroundController.text = selectedMock['careerBackground'] as String;
        _attendees[0].linkedinController.text = selectedMock['linkedin'] as String;
      }

      // Fill additional attendees with generic data
      final firstNames = [
        'Ana Paula', 'Carlos Eduardo', 'Marina', 'Felipe', 'Juliana', 'Roberto', 'Beatriz', 'Lucas',
        'Fernanda', 'Ricardo', 'Camila', 'Rodrigo', 'Patricia', 'Marcelo', 'Gabriela', 'Daniel',
        'Renata', 'Alexandre', 'Mariana', 'Bruno', 'Claudia', 'Rafael', 'Carolina', 'Thiago',
        'Amanda', 'Leonardo', 'Vanessa', 'Gustavo', 'Larissa', 'Diego', 'Priscila', 'Henrique'
      ];
      final lastNames = [
        'Silva', 'Santos', 'Oliveira', 'Souza', 'Lima', 'Costa', 'Pereira', 'Rodrigues',
        'Almeida', 'Nascimento', 'Araújo', 'Carvalho', 'Ribeiro', 'Martins', 'Rocha', 'Barbosa',
        'Fernandes', 'Gomes', 'Dias', 'Castro', 'Cardoso', 'Correia', 'Ferreira', 'Mendes'
      ];
      final positions = [
        // C-Level
        'CEO', 'CTO', 'CIO', 'CFO', 'COO', 'CDO', 'CISO', 'CMO', 'CPO', 'CRO', 'CAO',
        'Chief Digital Officer', 'Chief Innovation Officer', 'Chief Data Officer',
        'Chief Information Security Officer', 'Chief Product Officer', 'Chief Revenue Officer',
        'Chief Analytics Officer', 'Chief Experience Officer', 'Chief Strategy Officer',
        // VP Level
        'VP of Technology', 'VP of Innovation', 'VP of Digital Transformation', 'VP of Engineering',
        'VP of IT', 'VP of Data & Analytics', 'VP of Product', 'VP of Operations',
        'VP of Information Security', 'VP of Cloud Services', 'VP of Enterprise Architecture',
        // Director Level
        'IT Director', 'Innovation Director', 'Technology Director', 'Digital Director',
        'Director of Engineering', 'Director of Data Science', 'Director of Cloud Operations',
        'Director of Cybersecurity', 'Director of Enterprise Solutions', 'Director of Architecture',
        // Head Level
        'Head of Digital', 'Head of Technology', 'Head of Data & Analytics', 'Head of Engineering',
        'Head of Innovation', 'Head of Architecture', 'Head of Cloud', 'Head of Security',
        'Head of IT Operations', 'Head of Digital Transformation', 'Head of Product Development',
        // Manager/Lead Level
        'Technology Manager', 'Innovation Manager', 'Digital Transformation Lead', 'Senior Manager',
        'IT Manager', 'Product Manager', 'Program Manager', 'Solutions Architect',
        'Enterprise Architect', 'Chief Architect', 'Tech Lead', 'Engineering Manager',
        'Senior Consultant', 'Principal Consultant', 'Product Owner', 'Scrum Master'
      ];
      final roles = ['Decision Maker', 'Influencer', 'Technical'];

      for (int i = 1; i < _attendees.length; i++) {
        final firstName = firstNames[random.nextInt(firstNames.length)];
        final lastName = lastNames[random.nextInt(lastNames.length)];
        final companyDomain = (selectedMock['attendeeEmail'] as String).split('@')[1];

        _attendees[i].nameController.text = '$firstName $lastName';
        _attendees[i].emailController.text = '${firstName.toLowerCase()}.${lastName.toLowerCase()}@$companyDomain';
        _attendees[i].roleController.text = roles[random.nextInt(roles.length)];
        _attendees[i].positionController.text = positions[random.nextInt(positions.length)];
        _attendees[i].tcsSupporter = ['SUPPORTER', 'NEUTRAL'][random.nextInt(2)];
        _attendees[i].understandingController.text = 'Good understanding of digital transformation initiatives';
        _attendees[i].focusAreasController.text = selectedMock['focusAreas'] as String;
        _attendees[i].yearsWithTcsController.text = random.nextInt(5).toString();
        _attendees[i].educationController.text = 'Bachelor in Computer Science';
        _attendees[i].careerBackgroundController.text = 'Technology professional with ${random.nextInt(10) + 5}+ years of experience';
        _attendees[i].linkedinController.text = 'https://linkedin.com/in/${firstName.toLowerCase()}${lastName.toLowerCase()}';
      }

      // Section 5: Additional Notes
      _additionalNotesController.text = selectedMock['notes'] as String;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Mock data loaded: ${selectedMock['companyName']}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Build the form content
    final formContent = Form(
      key: _formKey,
      child: Column(
        children: [
          // Selected Date/Time Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Schedule',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[700]
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(widget.selectedDate),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[700]
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${widget.startTime.format(context)} (${_getFinalDuration()} ${_getFinalDuration() == 1 ? 'hour' : 'hours'})',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection1(),
                  const SizedBox(height: 24),
                  _buildSection2(),
                  const SizedBox(height: 24),
                  _buildSection3(),
                  const SizedBox(height: 24),
                  _buildSection4(),
                  const SizedBox(height: 24),
                  _buildSection5(),
                  if (_attachHeadApproval) ...[
                    const SizedBox(height: 24),
                    _buildSection6(),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _buildSubmitButton(),
        ],
      ),
    );

    // If used in drawer, return just the form content without Scaffold
    if (!widget.showScaffold) {
      return formContent;
    }

    // If used standalone, wrap with Scaffold and AppBar
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('New Booking'),
        elevation: 0,
        actions: [
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

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildVisitTypeSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Visit Type & Duration'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Visit Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              RadioListTile<String>(
                title: const Text('Quick Tour'),
                subtitle: const Text('2 hours - Quick demonstration (max 2 per day)'),
                value: 'QUICK_TOUR',
                groupValue: _visitType,
                activeColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() {
                    _visitType = value!;
                  });
                },
              ),
              RadioListTile<String>(
                title: const Text('Innovation Exchange'),
                subtitle: const Text('4-6 hours - In-depth session with preparation'),
                value: 'INNOVATION_EXCHANGE',
                groupValue: _visitType,
                activeColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() {
                    _visitType = value!;
                    if (_selectedDuration == null || _selectedDuration! < 4) {
                      _selectedDuration = 4;
                    }
                  });
                },
              ),
              if (_visitType == 'INNOVATION_EXCHANGE') ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _selectedDuration ?? 4,
                  decoration: InputDecoration(
                    labelText: 'Duration',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.schedule),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.white,
                  ),
                  items: const [
                    DropdownMenuItem(value: 4, child: Text('4 hours')),
                    DropdownMenuItem(value: 5, child: Text('5 hours')),
                    DropdownMenuItem(value: 6, child: Text('6 hours')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedDuration = value;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSection1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('1. Account & Company Information'),
        TextFormField(
          controller: _accountNameController,
          decoration: const InputDecoration(
            labelText: 'Account Name',
            hintText: 'Enter account name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.account_circle),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Account name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _companyNameController,
          decoration: const InputDecoration(
            labelText: 'Company Name',
            hintText: 'Enter company name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Company name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _companySector,
          decoration: const InputDecoration(
            labelText: 'Company Sector (optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
          items: const [
            DropdownMenuItem(value: 'Technology', child: Text('Technology')),
            DropdownMenuItem(value: 'Finance', child: Text('Finance')),
            DropdownMenuItem(value: 'Healthcare', child: Text('Healthcare')),
            DropdownMenuItem(value: 'Retail', child: Text('Retail')),
            DropdownMenuItem(value: 'Manufacturing', child: Text('Manufacturing')),
            DropdownMenuItem(value: 'Energy', child: Text('Energy')),
            DropdownMenuItem(value: 'Telecommunications', child: Text('Telecommunications')),
            DropdownMenuItem(value: 'Government', child: Text('Government')),
            DropdownMenuItem(value: 'Education', child: Text('Education')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (value) {
            setState(() {
              _companySector = value;
            });
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _companyVertical,
          decoration: const InputDecoration(
            labelText: 'Company Vertical (optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.vertical_align_center),
          ),
          items: const [
            DropdownMenuItem(value: 'Banking', child: Text('Banking')),
            DropdownMenuItem(value: 'Insurance', child: Text('Insurance')),
            DropdownMenuItem(value: 'Capital Markets', child: Text('Capital Markets')),
            DropdownMenuItem(value: 'Healthcare Provider', child: Text('Healthcare Provider')),
            DropdownMenuItem(value: 'Life Sciences', child: Text('Life Sciences')),
            DropdownMenuItem(value: 'E-commerce', child: Text('E-commerce')),
            DropdownMenuItem(value: 'Logistics', child: Text('Logistics')),
            DropdownMenuItem(value: 'Oil & Gas', child: Text('Oil & Gas')),
            DropdownMenuItem(value: 'Utilities', child: Text('Utilities')),
            DropdownMenuItem(value: 'Mining', child: Text('Mining')),
            DropdownMenuItem(value: 'Telecommunications', child: Text('Telecommunications')),
            DropdownMenuItem(value: 'Media', child: Text('Media')),
            DropdownMenuItem(value: 'Public Sector', child: Text('Public Sector')),
            DropdownMenuItem(value: 'Higher Education', child: Text('Higher Education')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (value) {
            setState(() {
              _companyVertical = value;
            });
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _companySize,
          decoration: const InputDecoration(
            labelText: 'Company Size (optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.groups),
          ),
          items: const [
            DropdownMenuItem(value: '1-50', child: Text('1-50 employees')),
            DropdownMenuItem(value: '51-200', child: Text('51-200 employees')),
            DropdownMenuItem(value: '201-500', child: Text('201-500 employees')),
            DropdownMenuItem(value: '501-1000', child: Text('501-1000 employees')),
            DropdownMenuItem(value: '1001-5000', child: Text('1001-5000 employees')),
            DropdownMenuItem(value: '5000+', child: Text('5000+ employees')),
          ],
          onChanged: (value) {
            setState(() {
              _companySize = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSection2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('2. Visit Details'),
        TextFormField(
          controller: _venueController,
          decoration: const InputDecoration(
            labelText: 'Venue (optional)',
            hintText: 'e.g., PacePort São Paulo',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _overallThemeController,
          decoration: const InputDecoration(
            labelText: 'Overall Theme / Focus Area (optional)',
            hintText: 'Describe the main focus of this visit',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.topic),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final picked = await showDatePicker(
              context: context,
              initialDate: _lastInnovationDay ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: isDark
                    ? ThemeData.dark().copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: Colors.white,
                          onPrimary: Colors.black,
                          surface: Colors.grey[850]!,
                          onSurface: Colors.white,
                        ),
                      )
                    : ThemeData.light().copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Colors.black,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: Colors.black,
                        ),
                      ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() {
                _lastInnovationDay = picked;
              });
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date of Last Innovation Day (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event),
            ),
            child: Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Text(
                  _lastInnovationDay != null
                      ? DateFormat('MMMM d, yyyy').format(_lastInnovationDay!)
                      : 'Select date',
                  style: TextStyle(
                    color: _lastInnovationDay != null
                        ? (isDark ? Colors.white : Colors.black)
                        : Colors.grey,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection3() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('3. Event Type & Deal Information'),
        Text(
          'Event Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('TCS'),
                value: 'TCS',
                groupValue: _eventType,
                activeColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() {
                    _eventType = value!;
                  });
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('PARTNER'),
                value: 'PARTNER',
                groupValue: _eventType,
                activeColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  setState(() {
                    _eventType = value!;
                  });
                },
              ),
            ),
          ],
        ),
        if (_eventType == 'PARTNER') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _partnerNameController,
            decoration: const InputDecoration(
              labelText: 'Partner Name',
              hintText: 'Enter partner name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.handshake),
            ),
            validator: (value) {
              if (_eventType == 'PARTNER' &&
                  (value == null || value.trim().isEmpty)) {
                return 'Partner name is required for partner events';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _dealStatus,
          decoration: const InputDecoration(
            labelText: 'Deal Status',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.assignment_turned_in),
          ),
          items: const [
            DropdownMenuItem(value: 'SWON', child: Text('SWON')),
            DropdownMenuItem(value: 'WON', child: Text('WON')),
          ],
          onChanged: (value) {
            setState(() {
              _dealStatus = value!;
            });
          },
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('Attaching Head Approval'),
          subtitle: const Text('Check this if you\'re adding approval documents'),
          value: _attachHeadApproval,
          activeColor: Colors.black,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (value) {
            setState(() {
              _attachHeadApproval = value ?? false;
            });
          },
        ),
      ],
    );
  }

  Widget _buildSection4() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('4. Attendees'),
            if (_attendees.length < 3)
              TextButton.icon(
                onPressed: _addAttendee,
                icon: Icon(Icons.add, color: isDark ? Colors.white : Colors.black),
                label: Text(
                  'Add Attendee',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                ),
              ),
          ],
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _attendees.length,
          itemBuilder: (context, index) {
            return _buildAttendeeCard(index);
          },
        ),
      ],
    );
  }

  Widget _buildAttendeeCard(int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final attendee = _attendees[index];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: isDark ? Colors.grey[850] : Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: index == 0,
          title: Text(
            attendee.nameController.text.isEmpty
                ? 'Attendee ${index + 1}'
                : attendee.nameController.text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_attendees.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeAttendee(index),
                ),
              const Icon(Icons.expand_more),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: attendee.nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Attendee full name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'attendee@company.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.roleController,
                    decoration: const InputDecoration(
                      labelText: 'Role (optional)',
                      hintText: 'e.g., CTO, VP of Engineering',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.positionController,
                    decoration: const InputDecoration(
                      labelText: 'Position (optional)',
                      hintText: 'Job title or position',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: attendee.tcsSupporter,
                    decoration: const InputDecoration(
                      labelText: 'TCS Supporter',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.thumb_up),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'SUPPORTER', child: Text('Supporter')),
                      DropdownMenuItem(
                          value: 'NEUTRAL', child: Text('Neutral')),
                      DropdownMenuItem(
                          value: 'DETRACTOR', child: Text('Detractor')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        attendee.tcsSupporter = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.understandingController,
                    decoration: const InputDecoration(
                      labelText: 'Understanding of TCS Innovation Capabilities (optional)',
                      hintText: 'Describe their understanding...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.focusAreasController,
                    decoration: const InputDecoration(
                      labelText: 'Focus Areas for the Year (optional)',
                      hintText: 'Key focus areas...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.yearsWithTcsController,
                    decoration: const InputDecoration(
                      labelText: 'Years Working with TCS (optional)',
                      hintText: 'Number of years',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.educationController,
                    decoration: const InputDecoration(
                      labelText: 'Educational Qualification (optional)',
                      hintText: 'Degrees, certifications...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.careerBackgroundController,
                    decoration: const InputDecoration(
                      labelText: 'Career Background (optional)',
                      hintText: 'Previous roles, experience...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timeline),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.linkedinController,
                    decoration: const InputDecoration(
                      labelText: 'LinkedIn Profile (optional)',
                      hintText: 'https://linkedin.com/in/...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final uri = Uri.tryParse(value);
                        if (uri == null || !uri.hasAbsolutePath) {
                          return 'Enter a valid URL';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('5. Additional Notes'),
        TextFormField(
          controller: _additionalNotesController,
          decoration: const InputDecoration(
            labelText: 'Additional Notes (optional)',
            hintText: 'Any other relevant information...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 5,
        ),
      ],
    );
  }

  Widget _buildSection6() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('6. Attachments'),
        AttachmentManager(
          attachmentUrls: _uploadedAttachmentUrls,
          localFiles: _localAttachments,
          onFilesAdded: (files) {
            setState(() {
              _localAttachments.addAll(files);
            });
          },
          onFileRemoved: (index, isUrl) {
            setState(() {
              if (isUrl) {
                _uploadedAttachmentUrls.removeAt(index);
              } else {
                _localAttachments.removeAt(index);
              }
            });
          },
          onClearAll: () {
            setState(() {
              _localAttachments.clear();
              _uploadedAttachmentUrls.clear();
            });
          },
          maxFiles: 6,
          readOnly: false,
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Save Draft button
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: _isSubmitting ? null : _saveDraft,
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.black,
                side: BorderSide(
                  color: isDark ? Colors.white : Colors.black,
                  width: 2,
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save Draft',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Create Booking button
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitForm,
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
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isUploadingAttachments
                              ? 'Uploading...'
                              : 'Creating...',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Create Booking',
                      style: TextStyle(
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
}

class AttendeeData {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController roleController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  String tcsSupporter = 'NEUTRAL';
  final TextEditingController understandingController = TextEditingController();
  final TextEditingController focusAreasController = TextEditingController();
  final TextEditingController yearsWithTcsController = TextEditingController();
  final TextEditingController educationController = TextEditingController();
  final TextEditingController careerBackgroundController = TextEditingController();
  final TextEditingController linkedinController = TextEditingController();

  void dispose() {
    nameController.dispose();
    emailController.dispose();
    roleController.dispose();
    positionController.dispose();
    understandingController.dispose();
    focusAreasController.dispose();
    yearsWithTcsController.dispose();
    educationController.dispose();
    careerBackgroundController.dispose();
    linkedinController.dispose();
  }
}
