// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';

enum RoomType {
  PHONE_BOOTH_1,
  PHONE_BOOTH_2,
  AGILE_SPACE,
  THINKING_SPACE,
  IMMERSIVE_ROOM,
  CONFERENCE_ROOM,
  PODCAST_ROOM,
  GREEN_ROOM,
}

enum RoomBookingStatus {
  PENDING,
  APPROVED,
  REJECTED,
  CANCELLED,
}

class RoomBooking {
  final String id;
  final RoomType room;
  final DateTime date;
  final String startTime;
  final String endTime;
  final RoomBookingStatus status;
  final String bookedById;
  final String? bookedByName;
  final String? bookedByEmail;
  final String purpose;
  final int attendees;
  final String? vertical;
  final String? approvedById;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime createdAt;

  RoomBooking({
    required this.id,
    required this.room,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.bookedById,
    this.bookedByName,
    this.bookedByEmail,
    required this.purpose,
    required this.attendees,
    this.vertical,
    this.approvedById,
    this.approvedAt,
    this.rejectionReason,
    required this.createdAt,
  });

  factory RoomBooking.fromJson(Map<String, dynamic> json) {
    return RoomBooking(
      id: json['id'] as String,
      room: RoomType.values.firstWhere((e) => e.name == json['room']),
      date: DateTime.parse(json['date'] as String),
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      status: RoomBookingStatus.values.firstWhere(
        (e) => e.name == json['status'],
      ),
      bookedById: json['bookedById'] as String,
      bookedByName: json['bookedByName'] as String?,
      bookedByEmail: json['bookedByEmail'] as String?,
      purpose: json['purpose'] as String,
      attendees: json['attendees'] as int,
      vertical: json['vertical'] as String?,
      approvedById: json['approvedById'] as String?,
      approvedAt: json['approvedAt'] != null
          ? DateTime.parse(json['approvedAt'] as String)
          : null,
      rejectionReason: json['rejectionReason'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room': room.name,
      'date': date.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'status': status.name,
      'bookedById': bookedById,
      'bookedByName': bookedByName,
      'bookedByEmail': bookedByEmail,
      'purpose': purpose,
      'attendees': attendees,
      'vertical': vertical,
      'approvedById': approvedById,
      'approvedAt': approvedAt?.toIso8601String(),
      'rejectionReason': rejectionReason,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static String roomLabel(RoomType room) {
    switch (room) {
      case RoomType.PHONE_BOOTH_1:
        return 'Phone Booth 1';
      case RoomType.PHONE_BOOTH_2:
        return 'Phone Booth 2';
      case RoomType.AGILE_SPACE:
        return 'Agile Space';
      case RoomType.THINKING_SPACE:
        return 'Thinking Space';
      case RoomType.IMMERSIVE_ROOM:
        return 'Immersive Room';
      case RoomType.CONFERENCE_ROOM:
        return 'Conference Room';
      case RoomType.PODCAST_ROOM:
        return 'Podcast Room';
      case RoomType.GREEN_ROOM:
        return 'Green Room';
    }
  }

  static IconData roomIcon(RoomType room) {
    switch (room) {
      case RoomType.PHONE_BOOTH_1:
      case RoomType.PHONE_BOOTH_2:
        return Icons.phone_in_talk;
      case RoomType.AGILE_SPACE:
        return Icons.groups;
      case RoomType.THINKING_SPACE:
        return Icons.psychology;
      case RoomType.IMMERSIVE_ROOM:
        return Icons.vrpano;
      case RoomType.CONFERENCE_ROOM:
        return Icons.meeting_room;
      case RoomType.PODCAST_ROOM:
        return Icons.podcasts;
      case RoomType.GREEN_ROOM:
        return Icons.videocam;
    }
  }

  static int roomCapacity(RoomType room) {
    switch (room) {
      case RoomType.PHONE_BOOTH_1:
      case RoomType.PHONE_BOOTH_2:
        return 1;
      case RoomType.AGILE_SPACE:
        return 10;
      case RoomType.THINKING_SPACE:
        return 30;
      case RoomType.IMMERSIVE_ROOM:
        return 15;
      case RoomType.CONFERENCE_ROOM:
        return 20;
      case RoomType.PODCAST_ROOM:
        return 4;
      case RoomType.GREEN_ROOM:
        return 6;
    }
  }

  /// Display order for rooms in the UI
  static List<RoomType> get displayOrder => [
    RoomType.CONFERENCE_ROOM,
    RoomType.THINKING_SPACE,
    RoomType.AGILE_SPACE,
    RoomType.PODCAST_ROOM,
    RoomType.IMMERSIVE_ROOM,
    RoomType.GREEN_ROOM,
    RoomType.PHONE_BOOTH_1,
    RoomType.PHONE_BOOTH_2,
  ];
}
