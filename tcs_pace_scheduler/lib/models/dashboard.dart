class DashboardStats {
  final int totalBookings;
  final int thisMonthBookings;
  final int thisYearBookings;
  final int pendingBookings;
  final int uniqueCompanies;
  final int totalAttendeesThisYear;

  DashboardStats({
    required this.totalBookings,
    required this.thisMonthBookings,
    required this.thisYearBookings,
    required this.pendingBookings,
    required this.uniqueCompanies,
    required this.totalAttendeesThisYear,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalBookings: json['totalBookings'] as int,
      thisMonthBookings: json['thisMonthBookings'] as int,
      thisYearBookings: json['thisYearBookings'] as int,
      pendingBookings: json['pendingBookings'] as int,
      uniqueCompanies: json['uniqueCompanies'] as int,
      totalAttendeesThisYear: json['totalAttendeesThisYear'] as int,
    );
  }
}

class MonthlyBookingData {
  final String month;
  final int threeHours;
  final int sixHours;

  MonthlyBookingData({
    required this.month,
    required this.threeHours,
    required this.sixHours,
  });

  factory MonthlyBookingData.fromJson(Map<String, dynamic> json) {
    return MonthlyBookingData(
      month: json['month'] as String,
      threeHours: json['threeHours'] as int,
      sixHours: json['sixHours'] as int,
    );
  }
}

class TrendsData {
  final String month;
  final int bookings;
  final int attendees;

  TrendsData({
    required this.month,
    required this.bookings,
    required this.attendees,
  });

  factory TrendsData.fromJson(Map<String, dynamic> json) {
    return TrendsData(
      month: json['month'] as String,
      bookings: json['bookings'] as int,
      attendees: json['attendees'] as int,
    );
  }
}

class SectorData {
  final String sector;
  final int count;

  SectorData({
    required this.sector,
    required this.count,
  });

  factory SectorData.fromJson(Map<String, dynamic> json) {
    return SectorData(
      sector: (json['sector'] as String?) ?? 'Unknown',
      count: json['count'] as int,
    );
  }
}

class InterestData {
  final String area;
  final int count;

  InterestData({
    required this.area,
    required this.count,
  });

  factory InterestData.fromJson(Map<String, dynamic> json) {
    return InterestData(
      area: (json['area'] as String?) ?? 'Unknown',
      count: json['count'] as int,
    );
  }
}

class TopCompany {
  final String company;
  final int visits;

  TopCompany({
    required this.company,
    required this.visits,
  });

  factory TopCompany.fromJson(Map<String, dynamic> json) {
    return TopCompany(
      company: json['company'] as String,
      visits: json['visits'] as int,
    );
  }
}

class HourlyBookingData {
  final int hour;
  final int bookings;

  HourlyBookingData({
    required this.hour,
    required this.bookings,
  });

  factory HourlyBookingData.fromJson(Map<String, dynamic> json) {
    return HourlyBookingData(
      hour: json['hour'] as int,
      bookings: json['bookings'] as int,
    );
  }
}

class ResponseRateData {
  final int total;
  final int confirmed;
  final int pending;
  final int declined;
  final double confirmationRate;

  ResponseRateData({
    required this.total,
    required this.confirmed,
    required this.pending,
    required this.declined,
    required this.confirmationRate,
  });

  factory ResponseRateData.fromJson(Map<String, dynamic> json) {
    return ResponseRateData(
      total: json['total'] as int,
      confirmed: json['confirmed'] as int,
      pending: json['pending'] as int,
      declined: json['declined'] as int,
      confirmationRate: (json['confirmationRate'] as num).toDouble(),
    );
  }
}

class TimeSlotData {
  final String timeSlot;
  final int bookings;

  TimeSlotData({
    required this.timeSlot,
    required this.bookings,
  });

  factory TimeSlotData.fromJson(Map<String, dynamic> json) {
    return TimeSlotData(
      timeSlot: json['timeSlot'] as String,
      bookings: json['bookings'] as int,
    );
  }
}

class ClientInsightData {
  final int totalClients;
  final int repeatVisitors;
  final int newClients;
  final double repeatRate;
  final List<TopCompany> topCompanies;

  ClientInsightData({
    required this.totalClients,
    required this.repeatVisitors,
    required this.newClients,
    required this.repeatRate,
    required this.topCompanies,
  });

  factory ClientInsightData.fromJson(Map<String, dynamic> json) {
    return ClientInsightData(
      totalClients: json['totalClients'] as int,
      repeatVisitors: json['repeatVisitors'] as int,
      newClients: json['newClients'] as int,
      repeatRate: (json['repeatRate'] as num).toDouble(),
      topCompanies: (json['topCompanies'] as List)
          .map((e) => TopCompany.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BookingTrendData {
  final String period;
  final int bookings;
  final double growthRate;

  BookingTrendData({
    required this.period,
    required this.bookings,
    required this.growthRate,
  });

  factory BookingTrendData.fromJson(Map<String, dynamic> json) {
    return BookingTrendData(
      period: json['period'] as String,
      bookings: json['bookings'] as int,
      growthRate: (json['growthRate'] as num).toDouble(),
    );
  }
}
