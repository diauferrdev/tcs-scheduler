class DashboardStats {
  final int totalBookings;
  final int thisMonthBookings;
  final double avgAttendees;
  final StatusDistribution statusDistribution;
  final StatusBreakdown statusBreakdown;
  final VisitTypeDistribution visitTypeDistribution;
  final Map<String, int> organizationTypeDistribution;
  final Map<String, int> verticalDistribution;
  final List<MonthlyTrend> monthlyTrend;
  final Map<String, int> timeSlotDistribution;
  final List<TopCompany> topCompanies;

  DashboardStats({
    required this.totalBookings,
    required this.thisMonthBookings,
    required this.avgAttendees,
    required this.statusDistribution,
    required this.statusBreakdown,
    required this.visitTypeDistribution,
    required this.organizationTypeDistribution,
    required this.verticalDistribution,
    required this.monthlyTrend,
    required this.timeSlotDistribution,
    required this.topCompanies,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      totalBookings: json['totalBookings'] as int,
      thisMonthBookings: json['thisMonthBookings'] as int,
      avgAttendees: (json['avgAttendees'] as num).toDouble(),
      statusDistribution: StatusDistribution.fromJson(json['statusDistribution'] as Map<String, dynamic>),
      statusBreakdown: StatusBreakdown.fromJson(json['statusBreakdown'] as Map<String, dynamic>),
      visitTypeDistribution: VisitTypeDistribution.fromJson(json['visitTypeDistribution'] as Map<String, dynamic>),
      organizationTypeDistribution: Map<String, int>.from(json['organizationTypeDistribution'] as Map),
      verticalDistribution: Map<String, int>.from(json['verticalDistribution'] as Map),
      monthlyTrend: (json['monthlyTrend'] as List)
          .map((e) => MonthlyTrend.fromJson(e as Map<String, dynamic>))
          .toList(),
      timeSlotDistribution: Map<String, int>.from(json['timeSlotDistribution'] as Map),
      topCompanies: (json['topCompanies'] as List)
          .map((e) => TopCompany.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StatusDistribution {
  final int pending;
  final int approved;
  final int notApproved;

  StatusDistribution({
    required this.pending,
    required this.approved,
    required this.notApproved,
  });

  factory StatusDistribution.fromJson(Map<String, dynamic> json) {
    return StatusDistribution(
      pending: json['pending'] as int,
      approved: json['approved'] as int,
      notApproved: json['notApproved'] as int,
    );
  }
}

class StatusBreakdown {
  final int created;
  final int underReview;
  final int needEdit;
  final int needReschedule;
  final int approved;
  final int notApproved;

  StatusBreakdown({
    required this.created,
    required this.underReview,
    required this.needEdit,
    required this.needReschedule,
    required this.approved,
    required this.notApproved,
  });

  factory StatusBreakdown.fromJson(Map<String, dynamic> json) {
    return StatusBreakdown(
      created: json['created'] as int,
      underReview: json['underReview'] as int,
      needEdit: json['needEdit'] as int,
      needReschedule: json['needReschedule'] as int,
      approved: json['approved'] as int,
      notApproved: json['notApproved'] as int,
    );
  }
}

class VisitTypeDistribution {
  final int paceTour;
  final int paceExperience;
  final int innovationExchange;

  VisitTypeDistribution({
    required this.paceTour,
    required this.paceExperience,
    required this.innovationExchange,
  });

  factory VisitTypeDistribution.fromJson(Map<String, dynamic> json) {
    return VisitTypeDistribution(
      paceTour: json['PACE_TOUR'] as int? ?? 0,
      paceExperience: json['PACE_EXPERIENCE'] as int? ?? 0,
      innovationExchange: json['INNOVATION_EXCHANGE'] as int? ?? 0,
      // QUICK_TOUR is deprecated and ignored
    );
  }

  int get total => paceTour + paceExperience + innovationExchange;
}

class MonthlyTrend {
  final String month;
  final int count;
  final int approved;

  MonthlyTrend({
    required this.month,
    required this.count,
    required this.approved,
  });

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) {
    return MonthlyTrend(
      month: json['month'] as String,
      count: json['count'] as int,
      approved: json['approved'] as int,
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
