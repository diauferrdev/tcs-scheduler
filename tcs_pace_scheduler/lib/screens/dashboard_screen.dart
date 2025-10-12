import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/app_layout.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/universal_update_service.dart';
import '../models/dashboard.dart';
import '../models/booking.dart';

class DashboardScreen extends StatefulWidget {
  final bool skipLayout;

  const DashboardScreen({super.key, this.skipLayout = false});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();

  // Data
  DashboardStats? _stats;
  List<Booking> _allBookings = [];
  List<SectorData> _sectors = [];
  List<TopCompany> _topCompanies = [];

  // Loading states
  bool _loadingStats = true;
  bool _loadingBookings = true;
  bool _loadingSectors = true;
  bool _loadingCompanies = true;

  // Filters
  final int _selectedYear = DateTime.now().year;

  // Error
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllData();

    // Check for updates IMMEDIATELY after login to prevent bugs
    // Blocks UI if app is outdated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UniversalUpdateService().checkForUpdate(context);
      }
    });
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadStats(),
      _loadBookings(),
      _loadSectors(),
      _loadTopCompanies(),
    ]);
  }

  Future<void> _loadStats() async {
    try {
      setState(() => _loadingStats = true);
      final response = await _apiService.getDashboardStats();
      setState(() {
        _stats = DashboardStats.fromJson(response);
        _loadingStats = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingStats = false;
      });
    }
  }

  Future<void> _loadBookings() async {
    try {
      setState(() => _loadingBookings = true);
      final response = await _apiService.getBookings();
      final bookingsData = (response['bookings'] as List?) ?? [];
      setState(() {
        _allBookings = bookingsData.map((e) => Booking.fromJson(e)).toList();
        _loadingBookings = false;
      });
    } catch (e) {
      debugPrint('Error loading bookings: $e');
      setState(() => _loadingBookings = false);
    }
  }

  Future<void> _loadSectors() async {
    try {
      setState(() => _loadingSectors = true);
      final data = await _apiService.getBookingsBySector(_selectedYear);
      setState(() {
        _sectors = data.map((e) => SectorData.fromJson(e)).toList();
        _loadingSectors = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingSectors = false;
      });
    }
  }

  Future<void> _loadTopCompanies() async {
    try {
      setState(() => _loadingCompanies = true);
      final data = await _apiService.getTopCompanies(10);
      setState(() {
        _topCompanies = data.map((e) => TopCompany.fromJson(e)).toList();
        _loadingCompanies = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingCompanies = false;
      });
    }
  }

  // Advanced analytics calculations
  double _calculateConversionRate() {
    if (_allBookings.isEmpty) return 0;
    final wonCount = _allBookings.where((b) => b.dealStatus == DealStatus.WON).length;
    final totalDeals = _allBookings.where((b) => b.dealStatus != null).length;
    return totalDeals > 0 ? (wonCount / totalDeals * 100) : 0;
  }

  double _calculatePartnerEventsPercentage() {
    if (_allBookings.isEmpty) return 0;
    final partnerCount = _allBookings.where((b) => b.eventType == EventType.PARTNER).length;
    return (partnerCount / _allBookings.length * 100);
  }

  double _calculateReturnRate() {
    if (_allBookings.isEmpty) return 0;
    final returningCount = _allBookings.where((b) => b.lastInnovationDay != null).length;
    return (returningCount / _allBookings.length * 100);
  }

  double _calculateSupporterRatio() {
    final allAttendees = _allBookings
        .where((b) => b.attendees != null)
        .expand((b) => b.attendees!)
        .toList();
    if (allAttendees.isEmpty) return 0;
    final supporters = allAttendees.where((a) => a.tcsSupporter == TCSSupporter.SUPPORTER).length;
    return (supporters / allAttendees.length * 100);
  }

  double _calculateAverageAttendees() {
    if (_allBookings.isEmpty) return 0;
    final total = _allBookings.fold<int>(0, (sum, b) => sum + b.expectedAttendees);
    return total / _allBookings.length;
  }

  Map<String, int> _getDealPipelineBySector() {
    final Map<String, int> pipeline = {};
    for (var booking in _allBookings) {
      if (booking.companySector != null) {
        final sector = booking.companySector!;
        pipeline[sector] = (pipeline[sector] ?? 0) + 1;
      }
    }
    return pipeline;
  }

  Map<String, dynamic> _getEventTypeDistribution() {
    final tcsCount = _allBookings.where((b) => b.eventType == EventType.TCS || b.eventType == null).length;
    final partnerCount = _allBookings.where((b) => b.eventType == EventType.PARTNER).length;
    return {'TCS': tcsCount, 'PARTNER': partnerCount};
  }

  Map<String, int> _getCompanySizeDistribution() {
    final Map<String, int> dist = {};
    for (var booking in _allBookings) {
      if (booking.companySize != null) {
        final size = booking.companySize!;
        dist[size] = (dist[size] ?? 0) + 1;
      }
    }
    return dist;
  }

  Map<String, dynamic> _getSupporterBreakdown() {
    final allAttendees = _allBookings
        .where((b) => b.attendees != null)
        .expand((b) => b.attendees!)
        .toList();

    final supporters = allAttendees.where((a) => a.tcsSupporter == TCSSupporter.SUPPORTER).length;
    final neutrals = allAttendees.where((a) => a.tcsSupporter == TCSSupporter.NEUTRAL).length;
    final detractors = allAttendees.where((a) => a.tcsSupporter == TCSSupporter.DETRACTOR).length;

    return {
      'SUPPORTER': supporters,
      'NEUTRAL': neutrals,
      'DETRACTOR': detractors,
    };
  }

  Map<String, int> _getFocusAreasDistribution() {
    final Map<String, int> focusAreas = {};
    final allAttendees = _allBookings
        .where((b) => b.attendees != null)
        .expand((b) => b.attendees!)
        .toList();

    for (var attendee in allAttendees) {
      if (attendee.focusAreas != null && attendee.focusAreas!.isNotEmpty) {
        final areas = attendee.focusAreas!.split(',').map((e) => e.trim()).toList();
        for (var area in areas) {
          if (area.isNotEmpty) {
            focusAreas[area] = (focusAreas[area] ?? 0) + 1;
          }
        }
      }
    }

    // Sort by count and get top 10
    final sorted = focusAreas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(10));
  }

  Map<int, Map<int, int>> _getEngagementHeatmap() {
    final Map<int, Map<int, int>> heatmap = {};

    for (var booking in _allBookings) {
      final dayOfWeek = booking.date.weekday; // 1-7 (Monday-Sunday)
      final hour = int.tryParse(booking.startTime.split(':')[0]) ?? 0;

      if (!heatmap.containsKey(dayOfWeek)) {
        heatmap[dayOfWeek] = {};
      }
      heatmap[dayOfWeek]![hour] = (heatmap[dayOfWeek]![hour] ?? 0) + 1;
    }

    return heatmap;
  }

  Map<String, double> _getAverageDurationByEventType() {
    final tcsBookings = _allBookings.where((b) => b.eventType == EventType.TCS || b.eventType == null).toList();
    final partnerBookings = _allBookings.where((b) => b.eventType == EventType.PARTNER).toList();

    double getDurationHours(VisitDuration duration) {
      switch (duration) {
        case VisitDuration.ONE_HOUR:
          return 1.0;
        case VisitDuration.TWO_HOURS:
          return 2.0;
        case VisitDuration.THREE_HOURS:
          return 3.0;
        case VisitDuration.FOUR_HOURS:
          return 4.0;
        case VisitDuration.FIVE_HOURS:
          return 5.0;
        case VisitDuration.SIX_HOURS:
          return 6.0;
      }
    }

    final tcsAvg = tcsBookings.isEmpty
        ? 0.0
        : tcsBookings.fold<double>(0, (sum, b) => sum + getDurationHours(b.duration)) / tcsBookings.length;
    final partnerAvg = partnerBookings.isEmpty
        ? 0.0
        : partnerBookings.fold<double>(0, (sum, b) => sum + getDurationHours(b.duration)) / partnerBookings.length;

    return {'TCS': tcsAvg, 'PARTNER': partnerAvg};
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final screenWidth = MediaQuery.of(context).size.width;

    final content = Stack(
      children: [
        Container(
          color: isDark ? Colors.black : const Color(0xFFF9FAFB),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 24),

                // Error message
                if (_error != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _error = null),
                      icon: const Icon(Icons.close, color: Colors.red),
                    ),
                  ],
                ),
              ),

            // Stat Cards Grid (2 columns)
            _buildStatCardsGrid(isDark, screenWidth),
            const SizedBox(height: 24),

                // Advanced Charts Grid
                _buildChartsGrid(isDark, screenWidth),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );

    return widget.skipLayout ? content : AppLayout(child: content);
  }

  Widget _buildStatCardsGrid(bool isDark, double screenWidth) {
    final statCards = [
      _buildStatCard(
        'Total Bookings',
        _loadingStats ? '...' : (_stats?.totalBookings.toString() ?? '0'),
        Icons.calendar_today,
        isDark,
        trend: _loadingStats ? null : '+${_stats?.thisMonthBookings ?? 0} this month',
      ),
      _buildStatCard(
        'Conversion Rate',
        _loadingBookings ? '...' : '${_calculateConversionRate().toStringAsFixed(1)}%',
        Icons.trending_up,
        isDark,
        trend: 'WON / Total Deals',
      ),
      _buildStatCard(
        'Avg Attendees/Event',
        _loadingBookings ? '...' : _calculateAverageAttendees().toStringAsFixed(1),
        Icons.people,
        isDark,
      ),
      _buildStatCard(
        'Partner Events',
        _loadingBookings ? '...' : '${_calculatePartnerEventsPercentage().toStringAsFixed(1)}%',
        Icons.handshake,
        isDark,
      ),
      _buildStatCard(
        'Return Rate',
        _loadingBookings ? '...' : '${_calculateReturnRate().toStringAsFixed(1)}%',
        Icons.repeat,
        isDark,
        trend: 'Companies returning',
      ),
      _buildStatCard(
        'Supporter Ratio',
        _loadingBookings ? '...' : '${_calculateSupporterRatio().toStringAsFixed(1)}%',
        Icons.thumb_up,
        isDark,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Always show 2 cards per row
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: statCards.map((card) {
            final itemWidth = (constraints.maxWidth - 16) / 2;
            return SizedBox(
              width: itemWidth,
              child: card,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildChartsGrid(bool isDark, double screenWidth) {
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    final columns = isDesktop ? 4 : (isTablet ? 2 : 1);

    final charts = [
      // Row 1
      GridItem(widget: _buildDealPipelineChart(isDark), columnSpan: 2),
      GridItem(widget: _buildEventTypeChart(isDark), columnSpan: 2),

      // Row 2
      GridItem(widget: _buildCompanySizeChart(isDark), columnSpan: 2),
      GridItem(widget: _buildSectorPerformanceChart(isDark), columnSpan: 2),

      // Row 3
      GridItem(widget: _buildSupporterAnalysisChart(isDark), columnSpan: 2),
      GridItem(widget: _buildFocusAreasChart(isDark), columnSpan: 2),

      // Row 4
      GridItem(widget: _buildEngagementHeatmapChart(isDark), columnSpan: 2),
      GridItem(widget: _buildDurationByTypeChart(isDark), columnSpan: 2),

      // Row 5
      GridItem(widget: _buildTopCompaniesCard(isDark), columnSpan: 4),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: charts.map((item) {
            final baseWidth = (constraints.maxWidth - (16 * (columns - 1))) / columns;
            final width = baseWidth * item.columnSpan + (16 * (item.columnSpan - 1));
            return SizedBox(
              width: width,
              child: item.widget,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, bool isDark, {String? trend}) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                icon,
                size: 16,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              if (trend != null)
                Text(
                  trend,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDealPipelineChart(bool isDark) {
    return _buildChartContainer(
      title: 'Deal Pipeline by Sector',
      isDark: isDark,
      child: _loadingBookings
          ? _buildLoadingIndicator(isDark)
          : () {
              final pipeline = _getDealPipelineBySector();
              if (pipeline.isEmpty) {
                return _buildNoData(isDark);
              }

              final sorted = pipeline.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final top5 = sorted.take(5).toList();

              return Column(
                children: [
                  SizedBox(
                    height: 160,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: top5.first.value.toDouble() * 1.4,
                        barTouchData: BarTouchData(enabled: false),
                        extraLinesData: ExtraLinesData(extraLinesOnTop: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: top5.first.value > 5 ? (top5.first.value / 5).ceilToDouble() : 1,
                              getTitlesWidget: (value, meta) {
                                if (value == 0 || value == meta.max) return const SizedBox.shrink();
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(
                          top5.length,
                          (index) => BarChartGroupData(
                            x: index,
                            showingTooltipIndicators: [],
                            barRods: [
                              BarChartRodData(
                                toY: top5[index].value.toDouble(),
                                color: _getChartColor(index),
                                width: 32,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: top5.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildLegendItem(
                        '${item.key} (${item.value})',
                        _getChartColor(index),
                        isDark,
                      );
                    }).toList(),
                  ),
                ],
              );
            }(),
    );
  }

  Widget _buildEventTypeChart(bool isDark) {
    return _buildChartContainer(
      title: 'Event Type Distribution',
      isDark: isDark,
      child: _loadingBookings
          ? _buildLoadingIndicator(isDark)
          : () {
              final dist = _getEventTypeDistribution();
              final total = dist['TCS']! + dist['PARTNER']!;

              if (total == 0) {
                return _buildNoData(isDark);
              }

              return Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 140,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 35,
                        sections: [
                          PieChartSectionData(
                            color: const Color(0xFF3B82F6),
                            value: dist['TCS']!.toDouble(),
                            title: '${(dist['TCS']! / total * 100).toStringAsFixed(1)}%',
                            radius: 45,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: const Color(0xFF8B5CF6),
                            value: dist['PARTNER']!.toDouble(),
                            title: '${(dist['PARTNER']! / total * 100).toStringAsFixed(1)}%',
                            radius: 45,
                            titleStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem('TCS (${dist['TCS']})', const Color(0xFF3B82F6), isDark),
                      const SizedBox(width: 24),
                      _buildLegendItem('PARTNER (${dist['PARTNER']})', const Color(0xFF8B5CF6), isDark),
                    ],
                  ),
                ],
              );
            }(),
    );
  }

  Widget _buildCompanySizeChart(bool isDark) {
    return _buildChartContainer(
      title: 'Company Size Distribution',
      isDark: isDark,
      child: _loadingBookings
          ? _buildLoadingIndicator(isDark)
          : () {
              final dist = _getCompanySizeDistribution();
              if (dist.isEmpty) {
                return _buildNoData(isDark);
              }

              final total = dist.values.fold<int>(0, (sum, v) => sum + v);

              return Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: dist.entries.toList().asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          final percentage = (item.value / total * 100).toStringAsFixed(1);

                          return PieChartSectionData(
                            color: _getChartColor(index),
                            value: item.value.toDouble(),
                            title: '$percentage%',
                            radius: 42,
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: dist.entries.toList().asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildLegendItem(
                        '${item.key} (${item.value})',
                        _getChartColor(index),
                        isDark,
                      );
                    }).toList(),
                  ),
                ],
              );
            }(),
    );
  }

  Widget _buildSectorPerformanceChart(bool isDark) {
    return _buildChartContainer(
      title: 'Top Sectors',
      isDark: isDark,
      child: _loadingSectors
          ? _buildLoadingIndicator(isDark)
          : _sectors.isEmpty
              ? _buildNoData(isDark)
              : () {
                  final top5 = _sectors.take(5).toList();

                  return Column(
                    children: [
                      SizedBox(
                        height: 160,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: top5.first.count.toDouble() * 1.4,
                            barTouchData: BarTouchData(enabled: false),
                            extraLinesData: ExtraLinesData(extraLinesOnTop: false),
                            titlesData: FlTitlesData(
                              show: true,
                              bottomTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  interval: top5.first.count > 5 ? (top5.first.count / 5).ceilToDouble() : 1,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0 || value == meta.max) return const SizedBox.shrink();
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                        fontSize: 10,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) {
                                return FlLine(
                                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  strokeWidth: 1,
                                );
                              },
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: List.generate(
                              top5.length,
                              (index) => BarChartGroupData(
                                x: index,
                                showingTooltipIndicators: [],
                                barRods: [
                                  BarChartRodData(
                                    toY: top5[index].count.toDouble(),
                                    color: _getChartColor(index),
                                    width: 32,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: top5.asMap().entries.map((entry) {
                          final index = entry.key;
                          final sector = entry.value;
                          return _buildLegendItem(
                            '${sector.sector} (${sector.count})',
                            _getChartColor(index),
                            isDark,
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }(),
    );
  }

  Widget _buildSupporterAnalysisChart(bool isDark) {
    return _buildChartContainer(
      title: 'Supporter Analysis',
      isDark: isDark,
      child: _loadingBookings
          ? _buildLoadingIndicator(isDark)
          : () {
              final breakdown = _getSupporterBreakdown();
              final total = breakdown.values.fold<int>(0, (sum, v) => sum + (v as int));

              if (total == 0) {
                return _buildNoData(isDark);
              }

              return Column(
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 30,
                        sections: [
                          PieChartSectionData(
                            color: const Color(0xFF10B981),
                            value: breakdown['SUPPORTER']!.toDouble(),
                            title: '${(breakdown['SUPPORTER']! / total * 100).toStringAsFixed(1)}%',
                            radius: 42,
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: const Color(0xFFF59E0B),
                            value: breakdown['NEUTRAL']!.toDouble(),
                            title: '${(breakdown['NEUTRAL']! / total * 100).toStringAsFixed(1)}%',
                            radius: 42,
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          PieChartSectionData(
                            color: const Color(0xFFEF4444),
                            value: breakdown['DETRACTOR']!.toDouble(),
                            title: '${(breakdown['DETRACTOR']! / total * 100).toStringAsFixed(1)}%',
                            radius: 42,
                            titleStyle: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildLegendItem('Supporter (${breakdown['SUPPORTER']})', const Color(0xFF10B981), isDark),
                      _buildLegendItem('Neutral (${breakdown['NEUTRAL']})', const Color(0xFFF59E0B), isDark),
                      _buildLegendItem('Detractor (${breakdown['DETRACTOR']})', const Color(0xFFEF4444), isDark),
                    ],
                  ),
                ],
              );
            }(),
    );
  }

  Widget _buildFocusAreasChart(bool isDark) {
    return _buildChartContainer(
      title: 'Top Focus Areas',
      isDark: isDark,
      child: _loadingBookings
          ? _buildLoadingIndicator(isDark)
          : () {
              final focusAreas = _getFocusAreasDistribution();
              if (focusAreas.isEmpty) {
                return _buildNoData(isDark);
              }

              final entries = focusAreas.entries.toList();
              final top5 = entries.take(5).toList();

              return Column(
                children: [
                  SizedBox(
                    height: 160,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: top5.first.value.toDouble() * 1.4,
                        barTouchData: BarTouchData(enabled: false),
                        extraLinesData: ExtraLinesData(extraLinesOnTop: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: top5.first.value > 5 ? (top5.first.value / 5).ceilToDouble() : 1,
                              getTitlesWidget: (value, meta) {
                                if (value == 0 || value == meta.max) return const SizedBox.shrink();
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(
                          top5.length,
                          (index) => BarChartGroupData(
                            x: index,
                            showingTooltipIndicators: [],
                            barRods: [
                              BarChartRodData(
                                toY: top5[index].value.toDouble(),
                                color: _getChartColor(index),
                                width: 32,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(4),
                                  topRight: Radius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: top5.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildLegendItem(
                        '${item.key} (${item.value})',
                        _getChartColor(index),
                        isDark,
                      );
                    }).toList(),
                  ),
                ],
              );
            }(),
    );
  }

  Widget _buildEngagementHeatmapChart(bool isDark) {
    return _buildChartContainer(
      title: 'Booking Frequency by Day & Hour',
      isDark: isDark,
      child: _loadingBookings
          ? _buildLoadingIndicator(isDark)
          : () {
              final heatmap = _getEngagementHeatmap();
              if (heatmap.isEmpty) {
                return _buildNoData(isDark);
              }

              final List<Map<String, dynamic>> hourlyData = [];

              for (int hour = 8; hour <= 18; hour++) {
                int totalForHour = 0;
                for (var dayData in heatmap.values) {
                  totalForHour += dayData[hour] ?? 0;
                }
                hourlyData.add({'hour': hour, 'count': totalForHour});
              }

              if (hourlyData.every((d) => d['count'] == 0)) {
                return _buildNoData(isDark);
              }

              final maxCount = hourlyData.fold<int>(0, (max, d) => d['count'] > max ? d['count'] : max);

              return SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxCount.toDouble() * 1.2,
                    barTouchData: BarTouchData(enabled: false),
                    extraLinesData: ExtraLinesData(extraLinesOnTop: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < hourlyData.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${hourlyData[value.toInt()]['hour']}h',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                    fontSize: 8,
                                  ),
                                ),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: maxCount > 5 ? (maxCount / 5).ceilToDouble() : 1,
                          getTitlesWidget: (value, meta) {
                            if (value == 0 || value == meta.max) return const SizedBox.shrink();
                            return Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(
                      hourlyData.length,
                      (index) => BarChartGroupData(
                        x: index,
                        showingTooltipIndicators: [],
                        barRods: [
                          BarChartRodData(
                            toY: hourlyData[index]['count'].toDouble(),
                            color: const Color(0xFF06B6D4),
                            width: 14,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }(),
    );
  }

  Widget _buildDurationByTypeChart(bool isDark) {
    return _buildChartContainer(
      title: 'Avg Duration by Event Type',
      isDark: isDark,
      child: _loadingBookings
          ? _buildLoadingIndicator(isDark)
          : () {
              final avgDuration = _getAverageDurationByEventType();
              final tcsAvg = avgDuration['TCS']!;
              final partnerAvg = avgDuration['PARTNER']!;

              if (tcsAvg == 0 && partnerAvg == 0) {
                return _buildNoData(isDark);
              }

              final maxY = tcsAvg > partnerAvg ? tcsAvg : partnerAvg;

              return SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY * 1.4,
                    barTouchData: BarTouchData(enabled: false),
                    extraLinesData: ExtraLinesData(extraLinesOnTop: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value == 0) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('TCS', style: TextStyle(fontSize: 12)),
                              );
                            }
                            if (value == 1) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text('PARTNER', style: TextStyle(fontSize: 12)),
                              );
                            }
                            return const Text('');
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: maxY > 2 ? (maxY / 4).ceilToDouble() : 0.5,
                          getTitlesWidget: (value, meta) {
                            if (value == 0 || value == meta.max) return const SizedBox.shrink();
                            return Text(
                              '${value.toStringAsFixed(1)}h',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                fontSize: 10,
                              ),
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        showingTooltipIndicators: [],
                        barRods: [
                          BarChartRodData(
                            toY: tcsAvg,
                            color: const Color(0xFF3B82F6),
                            width: 40,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        showingTooltipIndicators: [],
                        barRods: [
                          BarChartRodData(
                            toY: partnerAvg,
                            color: const Color(0xFF8B5CF6),
                            width: 40,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }(),
    );
  }

  Widget _buildTopCompaniesCard(bool isDark) {
    return _buildChartContainer(
      title: 'Top Companies',
      isDark: isDark,
      child: _loadingCompanies
          ? _buildLoadingIndicator(isDark)
          : _topCompanies.isEmpty
              ? _buildNoData(isDark)
              : Table(
                  columnWidths: const {
                    0: FixedColumnWidth(60),
                    1: FlexColumnWidth(),
                    2: FixedColumnWidth(80),
                  },
                  children: [
                    TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Rank',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Company',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            'Visits',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    ..._topCompanies.asMap().entries.map((entry) {
                      final index = entry.key;
                      final company = entry.value;
                      return TableRow(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                            ),
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              company.company,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              company.visits.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
    );
  }

  Widget _buildChartContainer({
    required String title,
    required bool isDark,
    Widget? dropdown,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (dropdown != null) dropdown,
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator(bool isDark) {
    return SizedBox(
      height: 200,
      child: Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  Widget _buildNoData(bool isDark) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Text(
          'No data available',
          style: TextStyle(
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Color _getChartColor(int index) {
    final colors = [
      const Color(0xFF3B82F6), // blue
      const Color(0xFF8B5CF6), // purple
      const Color(0xFF10B981), // green
      const Color(0xFFF59E0B), // amber
      const Color(0xFFEF4444), // red
      const Color(0xFF06B6D4), // cyan
      const Color(0xFFEC4899), // pink
      const Color(0xFF6366F1), // indigo
      const Color(0xFF14B8A6), // teal
      const Color(0xFFF97316), // orange
    ];
    return colors[index % colors.length];
  }
}

class GridItem {
  final Widget widget;
  final int columnSpan;

  GridItem({required this.widget, required this.columnSpan});
}
