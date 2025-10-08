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
      sector: json['sector'] as String,
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
      area: json['area'] as String,
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
