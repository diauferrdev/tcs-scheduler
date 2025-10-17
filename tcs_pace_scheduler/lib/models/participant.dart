enum ParticipantStatus {
  PENDING,
  CONFIRMED,
  REJECTED,
}

class Participant {
  final String id;
  final String userId;
  final String bookingId;
  final ParticipantStatus status;
  final String? userName;
  final String? userEmail;

  Participant({
    required this.id,
    required this.userId,
    required this.bookingId,
    required this.status,
    this.userName,
    this.userEmail,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      id: json['id'] as String,
      userId: json['userId'] as String,
      bookingId: json['bookingId'] as String,
      status: ParticipantStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ParticipantStatus.PENDING,
      ),
      userName: json['user']?['name'] as String?,
      userEmail: json['user']?['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'bookingId': bookingId,
      'status': status.name,
      'userName': userName,
      'userEmail': userEmail,
    };
  }
}
