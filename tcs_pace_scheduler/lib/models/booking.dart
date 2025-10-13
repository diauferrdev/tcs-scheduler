enum VisitDuration {
  ONE_HOUR,
  TWO_HOURS,
  THREE_HOURS,
  FOUR_HOURS,
  FIVE_HOURS,
  SIX_HOURS,
}

enum VisitType {
  QUICK_TOUR,           // 2 hours - up to 2 per day
  INNOVATION_EXCHANGE,  // 4-6 hours - needs prep/teardown
}

enum BookingStatus {
  DRAFT,
  PENDING_APPROVAL,
  APPROVED,
  CANCELLED,
}

enum EventType {
  TCS,
  PARTNER,
}

enum DealStatus {
  SWON,
  WON,
}

enum TCSSupporter {
  SUPPORTER,
  NEUTRAL,
  DETRACTOR,
}

class Attendee {
  final String id;
  final String name;
  final String email;

  // TCS Relationship
  final String? role;
  final TCSSupporter? tcsSupporter;
  final String? understandingOfTCS;
  final String? focusAreas;
  final int? yearsWorkingWithTCS;

  // Professional Info
  final String? position;
  final String? educationalQualification;
  final String? careerBackground;
  final String? linkedinProfile;

  // Optional
  final String? photoUrl;

  Attendee({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.tcsSupporter,
    this.understandingOfTCS,
    this.focusAreas,
    this.yearsWorkingWithTCS,
    this.position,
    this.educationalQualification,
    this.careerBackground,
    this.linkedinProfile,
    this.photoUrl,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) {
    return Attendee(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String?,
      tcsSupporter: json['tcsSupporter'] != null
          ? TCSSupporter.values.firstWhere((e) => e.name == json['tcsSupporter'])
          : null,
      understandingOfTCS: json['understandingOfTCS'] as String?,
      focusAreas: json['focusAreas'] as String?,
      yearsWorkingWithTCS: json['yearsWorkingWithTCS'] as int?,
      position: json['position'] as String?,
      educationalQualification: json['educationalQualification'] as String?,
      careerBackground: json['careerBackground'] as String?,
      linkedinProfile: json['linkedinProfile'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      if (role != null) 'role': role,
      if (tcsSupporter != null) 'tcsSupporter': tcsSupporter!.name,
      if (understandingOfTCS != null) 'understandingOfTCS': understandingOfTCS,
      if (focusAreas != null) 'focusAreas': focusAreas,
      if (yearsWorkingWithTCS != null) 'yearsWorkingWithTCS': yearsWorkingWithTCS,
      if (position != null) 'position': position,
      if (educationalQualification != null) 'educationalQualification': educationalQualification,
      if (careerBackground != null) 'careerBackground': careerBackground,
      if (linkedinProfile != null) 'linkedinProfile': linkedinProfile,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
  }
}

class Booking {
  final String id;
  final DateTime date;
  final String startTime;
  final VisitDuration duration;
  final VisitType visitType;
  final BookingStatus status;

  // Account & Company Information
  final String accountName;
  final String companyName;
  final String? companySector;
  final String? companyVertical;
  final String? companySize;

  // Contact Information (kept for compatibility)
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final String? contactPosition;

  // Visit Details
  final String? venue;
  final int expectedAttendees;
  final String? overallTheme;
  final DateTime? lastInnovationDay;

  // Event Type
  final EventType? eventType;
  final String? partnerName;

  // Deal Status
  final DealStatus? dealStatus;

  // Approvals
  final bool attachHeadApproval;
  final List<String>? attachments;
  final String? approvedById;
  final DateTime? approvedAt;

  // Reschedule tracking
  final String? originalBookingId;
  final String? rescheduledToId;

  // Legacy fields (kept for compatibility)
  final String? interestArea;
  final String? businessGoal;
  final String? additionalNotes;

  // Attendees
  final List<Attendee>? attendees;

  // Metadata
  final String? createdById;
  final DateTime createdAt;
  final DateTime updatedAt;

  Booking({
    required this.id,
    required this.date,
    required this.startTime,
    required this.duration,
    required this.visitType,
    required this.status,
    required this.accountName,
    required this.companyName,
    this.companySector,
    this.companyVertical,
    this.companySize,
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.contactPosition,
    this.venue,
    required this.expectedAttendees,
    this.overallTheme,
    this.lastInnovationDay,
    this.eventType,
    this.partnerName,
    this.dealStatus,
    this.attachHeadApproval = false,
    this.attachments,
    this.approvedById,
    this.approvedAt,
    this.originalBookingId,
    this.rescheduledToId,
    this.interestArea,
    this.businessGoal,
    this.additionalNotes,
    this.attendees,
    this.createdById,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    return Booking(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      startTime: json['startTime'] as String,
      duration: VisitDuration.values.firstWhere(
        (e) => e.name == json['duration'],
      ),
      visitType: json['visitType'] != null
          ? VisitType.values.firstWhere((e) => e.name == json['visitType'])
          : VisitType.INNOVATION_EXCHANGE,
      status: BookingStatus.values.firstWhere(
        (e) => e.name == json['status'],
      ),
      accountName: json['accountName'] as String,
      companyName: json['companyName'] as String,
      companySector: json['companySector'] as String?,
      companyVertical: json['companyVertical'] as String?,
      companySize: json['companySize'] as String?,
      contactName: json['contactName'] as String?,
      contactEmail: json['contactEmail'] as String?,
      contactPhone: json['contactPhone'] as String?,
      contactPosition: json['contactPosition'] as String?,
      venue: json['venue'] as String?,
      expectedAttendees: json['expectedAttendees'] as int,
      overallTheme: json['overallTheme'] as String?,
      lastInnovationDay: json['lastInnovationDay'] != null
          ? DateTime.parse(json['lastInnovationDay'] as String)
          : null,
      eventType: json['eventType'] != null
          ? EventType.values.firstWhere((e) => e.name == json['eventType'])
          : null,
      partnerName: json['partnerName'] as String?,
      dealStatus: json['dealStatus'] != null
          ? DealStatus.values.firstWhere((e) => e.name == json['dealStatus'])
          : null,
      attachHeadApproval: json['attachHeadApproval'] as bool? ?? false,
      attachments: json['attachments'] != null
          ? (json['attachments'] as List).map((e) => e as String).toList()
          : null,
      approvedById: json['approvedById'] as String?,
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'] as String)
          : null,
      originalBookingId: json['originalBookingId'] as String?,
      rescheduledToId: json['rescheduledToId'] as String?,
      interestArea: json['interestArea'] as String?,
      businessGoal: json['businessGoal'] as String?,
      additionalNotes: json['additionalNotes'] as String?,
      attendees: json['attendees'] != null
          ? (json['attendees'] as List).map((e) => Attendee.fromJson(e)).toList()
          : null,
      createdById: json['createdById'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'startTime': startTime,
      'duration': duration.name,
      'visitType': visitType.name,
      'accountName': accountName,
      'companyName': companyName,
      if (companySector != null) 'companySector': companySector,
      if (companyVertical != null) 'companyVertical': companyVertical,
      if (companySize != null) 'companySize': companySize,
      if (contactName != null) 'contactName': contactName,
      if (contactEmail != null) 'contactEmail': contactEmail,
      if (contactPhone != null) 'contactPhone': contactPhone,
      if (contactPosition != null) 'contactPosition': contactPosition,
      if (venue != null) 'venue': venue,
      'expectedAttendees': expectedAttendees,
      if (overallTheme != null) 'overallTheme': overallTheme,
      if (lastInnovationDay != null)
        'lastInnovationDay': lastInnovationDay!.toIso8601String().split('T')[0],
      if (eventType != null) 'eventType': eventType!.name,
      if (partnerName != null) 'partnerName': partnerName,
      if (dealStatus != null) 'dealStatus': dealStatus!.name,
      'attachHeadApproval': attachHeadApproval,
      if (attachments != null) 'attachments': attachments,
      if (interestArea != null) 'interestArea': interestArea,
      if (businessGoal != null) 'businessGoal': businessGoal,
      if (additionalNotes != null) 'additionalNotes': additionalNotes,
      if (attendees != null) 'attendees': attendees!.map((e) => e.toJson()).toList(),
    };
  }
}

// Model for available time slots from API
class AvailableTimeSlot {
  final String time;
  final int maxDuration; // in hours

  AvailableTimeSlot({
    required this.time,
    required this.maxDuration,
  });

  factory AvailableTimeSlot.fromJson(Map<String, dynamic> json) {
    return AvailableTimeSlot(
      time: json['time'] as String,
      maxDuration: json['maxDuration'] as int,
    );
  }
}

// Model for blocked period (Innovation Exchange prep/teardown)
class BlockedPeriod {
  final String date;
  final String period; // e.g., "Manhã (prep)", "Tarde (teardown)"

  BlockedPeriod({
    required this.date,
    required this.period,
  });

  factory BlockedPeriod.fromJson(Map<String, dynamic> json) {
    return BlockedPeriod(
      date: json['date'] as String,
      period: json['period'] as String,
    );
  }
}

// Model for available periods (morning/afternoon)
class AvailablePeriod {
  final String period; // MORNING or AFTERNOON
  final String label; // e.g., "Manhã (9:00 - 13:00)"
  final String startTime;
  final bool available;
  final String? blockedBy;
  final List<BlockedPeriod>? willBlock; // For Innovation Exchange

  AvailablePeriod({
    required this.period,
    required this.label,
    required this.startTime,
    required this.available,
    this.blockedBy,
    this.willBlock,
  });

  factory AvailablePeriod.fromJson(Map<String, dynamic> json) {
    return AvailablePeriod(
      period: json['period'] as String,
      label: json['label'] as String,
      startTime: json['startTime'] as String,
      available: json['available'] as bool,
      blockedBy: json['blockedBy'] as String?,
      willBlock: json['willBlock'] != null
          ? (json['willBlock'] as List).map((e) => BlockedPeriod.fromJson(e)).toList()
          : null,
    );
  }
}

// Model for availability response
class DayAvailability {
  final String date;
  final bool isFull;
  final List<AvailableTimeSlot> availableTimeSlots; // For backward compatibility
  final List<AvailablePeriod>? availablePeriods; // New period-based structure
  final List<AvailablePeriod>? allPeriods; // All periods with status
  final List<Booking> existingBookings;

  DayAvailability({
    required this.date,
    required this.isFull,
    this.availableTimeSlots = const [],
    this.availablePeriods,
    this.allPeriods,
    required this.existingBookings,
  });

  factory DayAvailability.fromJson(Map<String, dynamic> json) {
    return DayAvailability(
      date: json['date'] as String,
      isFull: json['isFull'] as bool,
      availableTimeSlots: json['availableTimeSlots'] != null
          ? (json['availableTimeSlots'] as List)
              .map((e) => AvailableTimeSlot.fromJson(e))
              .toList()
          : [],
      availablePeriods: json['availablePeriods'] != null
          ? (json['availablePeriods'] as List)
              .map((e) => AvailablePeriod.fromJson(e))
              .toList()
          : null,
      allPeriods: json['allPeriods'] != null
          ? (json['allPeriods'] as List)
              .map((e) => AvailablePeriod.fromJson(e))
              .toList()
          : null,
      existingBookings: (json['existingBookings'] as List)
          .map((e) => Booking.fromJson(e))
          .toList(),
    );
  }
}
