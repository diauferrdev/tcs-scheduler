enum VisitDuration {
  THREE_HOURS,
  SIX_HOURS,
}

enum BookingStatus {
  PENDING,
  CONFIRMED,
  CANCELLED,
}

class Attendee {
  final String id;
  final String name;
  final String? position;
  final String? email;
  final String? phone;

  Attendee({
    required this.id,
    required this.name,
    this.position,
    this.email,
    this.phone,
  });

  factory Attendee.fromJson(Map<String, dynamic> json) {
    return Attendee(
      id: json['id'] as String,
      name: json['name'] as String,
      position: json['position'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (position != null) 'position': position,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
    };
  }
}

class Booking {
  final String id;
  final DateTime date;
  final String startTime;
  final VisitDuration duration;
  final BookingStatus status;

  // Company Information
  final String companyName;
  final String companySector;
  final String companyVertical;
  final String? companySize;

  // Contact Information
  final String contactName;
  final String contactEmail;
  final String? contactPhone;
  final String? contactPosition;

  // Business Information
  final String interestArea;
  final int expectedAttendees;
  final String? businessGoal;
  final String? additionalNotes;

  // Attendees
  final List<Attendee>? attendees;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  Booking({
    required this.id,
    required this.date,
    required this.startTime,
    required this.duration,
    required this.status,
    required this.companyName,
    required this.companySector,
    required this.companyVertical,
    this.companySize,
    required this.contactName,
    required this.contactEmail,
    this.contactPhone,
    this.contactPosition,
    required this.interestArea,
    required this.expectedAttendees,
    this.businessGoal,
    this.additionalNotes,
    this.attendees,
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
      status: BookingStatus.values.firstWhere(
        (e) => e.name == json['status'],
      ),
      companyName: json['companyName'] as String,
      companySector: json['companySector'] as String,
      companyVertical: json['companyVertical'] as String,
      companySize: json['companySize'] as String?,
      contactName: json['contactName'] as String,
      contactEmail: json['contactEmail'] as String,
      contactPhone: json['contactPhone'] as String?,
      contactPosition: json['contactPosition'] as String?,
      interestArea: json['interestArea'] as String,
      expectedAttendees: json['expectedAttendees'] as int,
      businessGoal: json['businessGoal'] as String?,
      additionalNotes: json['additionalNotes'] as String?,
      attendees: json['attendees'] != null
          ? (json['attendees'] as List).map((e) => Attendee.fromJson(e)).toList()
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      'startTime': startTime,
      'duration': duration.name,
      'companyName': companyName,
      'companySector': companySector,
      'companyVertical': companyVertical,
      if (companySize != null) 'companySize': companySize,
      'contactName': contactName,
      'contactEmail': contactEmail,
      if (contactPhone != null) 'contactPhone': contactPhone,
      if (contactPosition != null) 'contactPosition': contactPosition,
      'interestArea': interestArea,
      'expectedAttendees': expectedAttendees,
      if (businessGoal != null) 'businessGoal': businessGoal,
      if (additionalNotes != null) 'additionalNotes': additionalNotes,
      if (attendees != null) 'attendees': attendees!.map((e) => e.toJson()).toList(),
    };
  }
}
