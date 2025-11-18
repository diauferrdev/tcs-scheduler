
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../widgets/app_layout.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/universal_update_service.dart';
import '../models/dashboard.dart';
import '../utils/toast_notification.dart';

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

  // Loading state
  bool _loading = true;

  // Error
  String? _error;

  // Tab selection
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Check for updates IMMEDIATELY after login to prevent bugs
    // Blocks UI if app is outdated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        UniversalUpdateService().checkForUpdate(context);
      }
    });
  }

  Future<void> _loadData() async {
    try {
      setState(() => _loading = true);
      final response = await _apiService.getDashboardStats();
      setState(() {
        _stats = DashboardStats.fromJson(response);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final screenWidth = MediaQuery.of(context).size.width;

    final content = Container(
      color: isDark ? Colors.black : const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            // Stat Cards Grid
            _buildStatCardsGrid(isDark, screenWidth),
            const SizedBox(height: 24),

            // Dashboard Tabs
            _buildDashboardTabs(isDark),
            const SizedBox(height: 24),

            // Mini Insights Row (Desktop only) - Only show in Advanced mode
            if (screenWidth >= 1024 && _selectedTabIndex == 1) ...[
              _buildMiniInsightsRow(isDark, screenWidth),
              const SizedBox(height: 24),
            ],

            // Charts Grid - Conditional based on tab selection
            if (_selectedTabIndex == 0)
              _buildBasicDashboard(isDark, screenWidth)
            else
              _buildChartsGrid(isDark, screenWidth),
            const SizedBox(height: 24),

            // FCM Test Button (diego@tcs.com only - discrete)
            _buildDiscreteFCMTestButton(isDark),
          ],
        ),
      ),
    );

    return widget.skipLayout ? content : AppLayout(child: content);
  }

  Widget _buildDashboardTabs(bool isDark) {
    return Row(
      children: [
        _buildTabButton('Resumido', 0, Icons.dashboard, isDark),
        const SizedBox(width: 12),
        _buildTabButton('Avançado', 1, Icons.analytics, isDark),
      ],
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon, bool isDark) {
    final isSelected = _selectedTabIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? const Color(0xFF18181B) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.white : Colors.black)
                  : (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.black : Colors.white)
                      : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicDashboard(bool isDark, double screenWidth) {
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        if (isDesktop || isTablet) {
          // Desktop and Tablet: 2x2 grid
          final columnWidth = (maxWidth - 16) / 2;
          return Column(
            children: [
              // Row 1: Visit Type & Status Breakdown
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: columnWidth, child: _buildVisitTypeChart(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: columnWidth, child: _buildStatusBreakdownChart(isDark)),
                ],
              ),
              const SizedBox(height: 16),

              // Row 2: Monthly Trend & Time Slot
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: columnWidth, child: _buildMonthlyTrendChart(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: columnWidth, child: _buildTimeSlotChart(isDark)),
                ],
              ),
            ],
          );
        } else {
          // Mobile: Stacked
          return Column(
            children: [
              _buildVisitTypeChart(isDark),
              const SizedBox(height: 16),
              _buildStatusBreakdownChart(isDark),
              const SizedBox(height: 16),
              _buildMonthlyTrendChart(isDark),
              const SizedBox(height: 16),
              _buildTimeSlotChart(isDark),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatCardsGrid(bool isDark, double screenWidth) {
    if (_loading || _stats == null) {
      return _buildLoadingCards(isDark);
    }

    final statCards = [
      _buildStatCard(
        'Total Bookings',
        _stats!.totalBookings.toString(),
        Icons.calendar_today,
        isDark,
        trend: '+12% vs last month',
        trendDirection: 'up',
      ),
      _buildStatCard(
        'Avg Attendees',
        _stats!.avgAttendees.toStringAsFixed(1),
        Icons.people,
        isDark,
        trend: '+0.3 increase',
        trendDirection: 'up',
      ),
      _buildStatCard(
        'Approved',
        _stats!.statusDistribution.approved.toString(),
        Icons.check_circle,
        isDark,
        trend: '+8% this week',
        trendDirection: 'up',
      ),
      _buildStatCard(
        'Pending',
        _stats!.statusDistribution.pending.toString(),
        Icons.pending,
        isDark,
        trend: '15% below peak',
        trendDirection: 'down', // Down in pending is good, so down arrow
      ),
      _buildStatCard(
        'Not Approved',
        _stats!.statusDistribution.notApproved.toString(),
        Icons.cancel,
        isDark,
        trend: '3 rejections',
        trendDirection: 'neutral',
      ),
      _buildStatCard(
        'This Month',
        _stats!.thisMonthBookings.toString(),
        Icons.today,
        isDark,
        trend: '+18% vs last month',
        trendDirection: 'up',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop: try to fit all 6 cards in one or two rows
        // Determine number of columns based on screen width
        final int columns;
        final bool isDesktop = screenWidth >= 1024;
        final bool isTablet = screenWidth >= 600 && screenWidth < 1024;

        if (isDesktop) {
          // Desktop: 6 columns if width allows, otherwise 3 columns
          columns = constraints.maxWidth >= 1400 ? 6 : 3;
        } else if (isTablet) {
          // Tablet: 3 columns
          columns = 3;
        } else {
          // Mobile: 2 columns
          columns = 2;
        }

        final itemWidth = (constraints.maxWidth - (16 * (columns - 1))) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: statCards.map((card) {
            return SizedBox(
              width: itemWidth,
              child: card,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildLoadingCards(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final loadingCards = List.generate(
          6,
          (index) => _buildStatCard(
            'Loading...',
            '...',
            Icons.hourglass_empty,
            isDark,
          ),
        );

        // Use same logic as main stat cards grid
        final int columns;
        final bool isDesktop = screenWidth >= 1024;
        final bool isTablet = screenWidth >= 600 && screenWidth < 1024;

        if (isDesktop) {
          columns = constraints.maxWidth >= 1400 ? 6 : 3;
        } else if (isTablet) {
          columns = 3;
        } else {
          columns = 2;
        }

        final itemWidth = (constraints.maxWidth - (16 * (columns - 1))) / columns;

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: loadingCards.map((card) {
            return SizedBox(
              width: itemWidth,
              child: card,
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMiniInsightsRow(bool isDark, double screenWidth) {
    if (_loading || _stats == null) {
      return const SizedBox.shrink();
    }

    final total = _stats!.statusDistribution.pending +
        _stats!.statusDistribution.approved +
        _stats!.statusDistribution.notApproved;
    final approvalRate = total > 0
        ? (_stats!.statusDistribution.approved / total * 100)
        : 0.0;

    return Row(
      children: [
        Expanded(child: _buildApprovalRateGauge(isDark, approvalRate)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatusFunnel(isDark)),
        const SizedBox(width: 16),
        Expanded(child: _buildMostPopularVisit(isDark)),
        const SizedBox(width: 16),
        Expanded(child: _buildPeakTimeCard(isDark)),
      ],
    );
  }

  Widget _buildApprovalRateGauge(bool isDark, double approvalRate) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Approval Rate',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SfRadialGauge(
              axes: <RadialAxis>[
                RadialAxis(
                  minimum: 0,
                  maximum: 100,
                  showLabels: false,
                  showTicks: false,
                  axisLineStyle: AxisLineStyle(
                    thickness: 0.2,
                    color: (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)).withValues(alpha: 0.3),
                    thicknessUnit: GaugeSizeUnit.factor,
                  ),
                  pointers: <GaugePointer>[
                    RangePointer(
                      value: approvalRate,
                      width: 0.2,
                      sizeUnit: GaugeSizeUnit.factor,
                      gradient: const SweepGradient(
                        colors: <Color>[Color(0xFFEF4444), Color(0xFFF05E1B), Color(0xFF10B981)],
                        stops: <double>[0.0, 0.5, 1.0],
                      ),
                    ),
                  ],
                  annotations: <GaugeAnnotation>[
                    GaugeAnnotation(
                      widget: Text(
                        '${approvalRate.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      angle: 90,
                      positionFactor: 0.1,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFunnel(bool isDark) {
    final hasData = _stats != null;
    final breakdown = hasData ? _stats!.statusBreakdown : null;
    final maxValue = hasData
        ? [
            breakdown!.underReview,
            breakdown.needEdit,
            breakdown.needReschedule,
            breakdown.approved,
            breakdown.notApproved
          ].reduce((a, b) => a > b ? a : b)
        : 0;

    final borderColor = isDark ? const Color(0xFFF97316) : const Color(0xFFF97316);

    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
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
          Text(
            'Status Flow',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: hasData && maxValue > 0
                ? Padding(
                    padding: const EdgeInsets.only(right: 12, left: 4),
                    child: SfCartesianChart(
                      plotAreaBorderWidth: 0,
                      primaryXAxis: CategoryAxis(
                        majorGridLines: const MajorGridLines(width: 0),
                        labelStyle: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                        axisLine: AxisLine(
                          width: 4,
                          color: borderColor.withValues(alpha: 0.2),
                        ),
                      ),
                      primaryYAxis: NumericAxis(
                        isVisible: false,
                        minimum: 0,
                        maximum: maxValue.toDouble() * 1.2,
                      ),
                      series: <CartesianSeries>[
                        SplineSeries<Map<String, dynamic>, String>(
                          dataSource: [
                            {'label': 'Review', 'value': breakdown!.underReview},
                            {'label': 'Changes', 'value': breakdown.needEdit},
                            {'label': 'Reschedule', 'value': breakdown.needReschedule},
                            {'label': 'Approved', 'value': breakdown.approved},
                            {'label': 'Rejected', 'value': breakdown.notApproved},
                          ],
                          xValueMapper: (data, _) => data['label'] as String,
                          yValueMapper: (data, _) => (data['value'] as int).toDouble(),
                          color: const Color(0xFFF97316),
                          width: 3,
                          markerSettings: const MarkerSettings(
                            isVisible: true,
                            height: 8,
                            width: 8,
                            color: Color(0xFFFB923C),
                            borderColor: Colors.white,
                            borderWidth: 2,
                          ),
                        ),
                      ],
                      tooltipBehavior: TooltipBehavior(
                        enable: false,
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      'No data',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMostPopularVisit(bool isDark) {
    final hasData = _stats != null && _stats!.visitTypeDistribution.total > 0;

    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
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
          Text(
            'Visit Trends',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: hasData
                ? _ScatterChartWidget(isDark: isDark)
                : Center(
                    child: Text(
                      'No data',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakTimeCard(bool isDark) {
    final hasData = _stats != null && _stats!.timeSlotDistribution.isNotEmpty;

    // Sort by time (chronologically) if there's data
    final sorted = hasData
        ? (_stats!.timeSlotDistribution.entries.toList()
          ..sort((a, b) {
            final hourA = int.tryParse(a.key.split(':')[0]) ?? 0;
            final hourB = int.tryParse(b.key.split(':')[0]) ?? 0;
            return hourA.compareTo(hourB);
          }))
        : <MapEntry<String, int>>[];

    final maxValue = hasData ? sorted.fold<int>(0, (max, e) => e.value > max ? e.value : max) : 1;
    final peakEntry = hasData ? sorted.reduce((a, b) => a.value > b.value ? a : b) : null;

    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
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
          Text(
            'Peak Time',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: hasData
                ? SfCartesianChart(
                    plotAreaBorderWidth: 0,
                    primaryXAxis: CategoryAxis(
                      majorGridLines: const MajorGridLines(width: 0),
                      labelStyle: TextStyle(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        fontSize: 7,
                      ),
                      axisLine: const AxisLine(width: 0),
                    ),
                    primaryYAxis: NumericAxis(
                      majorGridLines: MajorGridLines(
                        width: 1,
                        color: (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
                      ),
                      axisLine: const AxisLine(width: 0),
                      labelStyle: TextStyle(
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        fontSize: 8,
                      ),
                      minimum: 0,
                      maximum: maxValue.toDouble() * 1.2,
                    ),
                    series: <CartesianSeries>[
                      ColumnSeries<MapEntry<String, int>, String>(
                        dataSource: sorted,
                        xValueMapper: (data, _) => data.key,
                        yValueMapper: (data, _) => data.value.toDouble(),
                        pointColorMapper: (data, _) {
                          return data.key == peakEntry!.key
                              ? const Color(0xFF06B6D4)
                              : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB));
                        },
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        width: 0.6,
                        dataLabelSettings: const DataLabelSettings(isVisible: false),
                      ),
                    ],
                    tooltipBehavior: TooltipBehavior(
                      enable: false,
                    ),
                  )
                : Center(
                    child: Text(
                      'No data',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsGrid(bool isDark, double screenWidth) {
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;

        if (isDesktop) {
          final columnWidth = (maxWidth - 16) / 2;
          return Column(
            children: [
              // Row 1: Visit Type (pie) & TCS Vertical Distribution (bar)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: columnWidth, child: _buildVisitTypeChart(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: columnWidth, child: _buildVerticalChart(isDark)),
                ],
              ),
              const SizedBox(height: 16),

              // Row 1.5: Top Visitors, Event Type, Deal Status (3 columns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: (maxWidth - 32) / 3, child: _buildTopCompaniesCard(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: (maxWidth - 32) / 3, child: _buildEventTypeWaterfall(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: (maxWidth - 32) / 3, child: _buildDealStatusBubble(isDark)),
                ],
              ),
              const SizedBox(height: 16),

              // Row 2: Organization Type (bar) & Status Breakdown (pie)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: columnWidth, child: _buildOrganizationTypeChart(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: columnWidth, child: _buildStatusBreakdownChart(isDark)),
                ],
              ),
              const SizedBox(height: 16),

              // Row 3: Popular Time Slots + Monthly Trend (two columns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: columnWidth, child: _buildTimeSlotChart(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: columnWidth, child: _buildMonthlyTrendChart(isDark)),
                ],
              ),
              const SizedBox(height: 16),

              // Row 4: Lead Conversion, Avg Attendees, Engagement Depth (3 columns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: (maxWidth - 32) / 3, child: _buildOrgTypeConversion(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: (maxWidth - 32) / 3, child: _buildAttendeesByType(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: (maxWidth - 32) / 3, child: _buildEngagementDepth(isDark)),
                ],
              ),
            ],
          );
        } else if (isTablet) {
          final columnWidth = (maxWidth - 16) / 2;
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: columnWidth, child: _buildVisitTypeChart(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: columnWidth, child: _buildVerticalChart(isDark)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: (maxWidth - 32) / 3, child: _buildOrgTypeConversion(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: (maxWidth - 32) / 3, child: _buildAttendeesByType(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: (maxWidth - 32) / 3, child: _buildEngagementDepth(isDark)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: columnWidth, child: _buildOrganizationTypeChart(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: columnWidth, child: _buildStatusBreakdownChart(isDark)),
                ],
              ),
              const SizedBox(height: 16),
              _buildTimeSlotChart(isDark),
              const SizedBox(height: 16),
              _buildMonthlyTrendChart(isDark),
              const SizedBox(height: 16),
              _buildTopCompaniesCard(isDark),
              const SizedBox(height: 16),
              _buildEventTypeWaterfall(isDark),
              const SizedBox(height: 16),
              _buildDealStatusBubble(isDark),
            ],
          );
        } else {
          // Mobile: 1 column
          return Column(
            children: [
              _buildVisitTypeChart(isDark),
              const SizedBox(height: 16),
              _buildVerticalChart(isDark),
              const SizedBox(height: 16),
              _buildOrgTypeConversion(isDark),
              const SizedBox(height: 16),
              _buildAttendeesByType(isDark),
              const SizedBox(height: 16),
              _buildEngagementDepth(isDark),
              const SizedBox(height: 16),
              _buildOrganizationTypeChart(isDark),
              const SizedBox(height: 16),
              _buildStatusBreakdownChart(isDark),
              const SizedBox(height: 16),
              _buildTimeSlotChart(isDark),
              const SizedBox(height: 16),
              _buildMonthlyTrendChart(isDark),
              const SizedBox(height: 16),
              _buildTopCompaniesCard(isDark),
              const SizedBox(height: 16),
              _buildEventTypeWaterfall(isDark),
              const SizedBox(height: 16),
              _buildDealStatusBubble(isDark),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, bool isDark, {String? trend, String? trendDirection}) {
    // Determine arrow and color based on trend direction
    IconData? trendIcon;
    Color? trendColor;
    if (trendDirection == 'up') {
      trendIcon = Icons.arrow_upward;
      trendColor = const Color(0xFF10B981); // Green
    } else if (trendDirection == 'down') {
      trendIcon = Icons.arrow_downward;
      trendColor = const Color(0xFF10B981); // Green (down is good for pending)
    } else if (trendDirection == 'neutral') {
      trendIcon = null;
      trendColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280); // Gray
    }

    return Container(
      height: 110,
      padding: const EdgeInsets.all(16),
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
                    fontSize: 11,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                icon,
                size: 14,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ],
          ),
          Center(
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                if (trend != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (trendIcon != null) ...[
                        Icon(
                          trendIcon,
                          size: 10,
                          color: trendColor,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Flexible(
                        child: Text(
                          trend,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: trendColor ?? (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisitTypeChart(bool isDark) {
    return _buildChartContainer(
      title: 'Visit Type Distribution',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              final dist = _stats!.visitTypeDistribution;
              final total = dist.total;

              if (total == 0) {
                return _buildNoData(isDark);
              }

              final chartData = <Map<String, dynamic>>[];
              if (dist.paceTour > 0) {
                chartData.add({
                  'type': 'PACE Tour',
                  'value': dist.paceTour,
                  'color': const Color(0xFFEF4444),
                });
              }
              if (dist.paceExperience > 0) {
                chartData.add({
                  'type': 'PACE Experience',
                  'value': dist.paceExperience,
                  'color': const Color(0xFFF05E1B),
                });
              }
              if (dist.innovationExchange > 0) {
                chartData.add({
                  'type': 'Innovation Exchange',
                  'value': dist.innovationExchange,
                  'color': const Color(0xFF10B981),
                });
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 200,
                    child: SfCircularChart(
                      series: <CircularSeries>[
                        DoughnutSeries<Map<String, dynamic>, String>(
                          dataSource: chartData,
                          xValueMapper: (data, _) => data['type'] as String,
                          yValueMapper: (data, _) => (data['value'] as int).toDouble(),
                          pointColorMapper: (data, _) => data['color'] as Color,
                          dataLabelSettings: DataLabelSettings(
                            isVisible: true,
                            labelPosition: ChartDataLabelPosition.outside,
                            textStyle: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            connectorLineSettings: ConnectorLineSettings(
                              type: ConnectorType.curve,
                              width: 1.5,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          dataLabelMapper: (data, _) {
                            final value = data['value'] as int;
                            final percentage = (value / total * 100).toStringAsFixed(1);
                            return '$percentage%';
                          },
                          innerRadius: '60%',
                          explode: true,
                          explodeIndex: 0,
                          explodeOffset: '5%',
                        ),
                      ],
                      tooltipBehavior: TooltipBehavior(
                        enable: true,
                        format: 'point.x: point.y',
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                        textStyle: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        borderWidth: 1,
                        borderColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                        elevation: 2,
                        canShowMarker: false,
                        duration: 500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: chartData.map((data) {
                      final type = data['type'] as String;
                      final value = data['value'] as int;
                      final color = data['color'] as Color;
                      return _buildLegendItem('$type ($value)', color, isDark);
                    }).toList(),
                  ),
                ],
              );
            }(),
    );
  }

  Widget _buildStatusBreakdownChart(bool isDark) {
    return _buildChartContainer(
      title: 'Status Breakdown',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              final breakdown = _stats!.statusBreakdown;
              final total = breakdown.created +
                  breakdown.underReview +
                  breakdown.needEdit +
                  breakdown.needReschedule +
                  breakdown.approved +
                  breakdown.notApproved;

              if (total == 0) {
                return _buildNoData(isDark);
              }

              final chartData = <Map<String, dynamic>>[];
              int colorIndex = 0;

              void addData(int value, String label) {
                if (value > 0) {
                  chartData.add({
                    'status': label,
                    'value': value,
                    'percentage': value / total,
                    'color': _getChartColor(colorIndex++),
                  });
                }
              }

              addData(breakdown.created, 'Created');
              addData(breakdown.underReview, 'Under Review');
              addData(breakdown.needEdit, 'Need Edit');
              addData(breakdown.needReschedule, 'Need Reschedule');
              addData(breakdown.approved, 'Approved');
              addData(breakdown.notApproved, 'Not Approved');

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 200,
                    child: SfCircularChart(
                      series: <CircularSeries>[
                        RadialBarSeries<Map<String, dynamic>, String>(
                          dataSource: chartData,
                          xValueMapper: (data, _) => data['status'] as String,
                          yValueMapper: (data, _) => (data['percentage'] as double) * 100,
                          pointColorMapper: (data, _) => data['color'] as Color,
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: false,
                          ),
                          maximumValue: 100,
                          radius: '100%',
                          gap: '3%',
                          innerRadius: '20%',
                        ),
                      ],
                      tooltipBehavior: TooltipBehavior(
                        enable: true,
                        format: 'point.x: point.y%',
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                        textStyle: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        borderWidth: 1,
                        borderColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                        elevation: 2,
                        canShowMarker: false,
                        duration: 500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: chartData.map((data) {
                      final label = data['status'] as String;
                      final value = data['value'] as int;
                      final color = data['color'] as Color;
                      return _buildLegendItem('$label ($value)', color, isDark);
                    }).toList(),
                  ),
                ],
              );
            }(),
    );
  }

  Widget _buildOrganizationTypeChart(bool isDark) {
    return _buildChartContainer(
      title: 'Lead Funnel',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              final dist = _stats!.organizationTypeDistribution;
              if (dist.isEmpty) {
                return _buildNoData(isDark);
              }

              // Create funnel: Prospect → Partner → Customer → Government
              final prospects = dist['PROSPECT'] ?? 0;
              final partners = dist['PARTNER'] ?? 0;
              final customers = dist['EXISTING_CUSTOMER'] ?? 0;
              final govt = dist['GOVERNMENTAL_INSTITUTION'] ?? 0;

              final funnelData = [
                {'stage': 'Prospects', 'value': prospects, 'color': const Color(0xFFF05E1B)},
                {'stage': 'Partners', 'value': partners, 'color': const Color(0xFF3B82F6)},
                {'stage': 'Customers', 'value': customers, 'color': const Color(0xFF10B981)},
                {'stage': 'Government', 'value': govt, 'color': const Color(0xFFEF4444)},
              ];

              return SizedBox(
                height: 240,
                child: SfPyramidChart(
                  series: PyramidSeries<Map<String, dynamic>, String>(
                    dataSource: funnelData,
                    xValueMapper: (data, _) => data['stage'] as String,
                    yValueMapper: (data, _) => (data['value'] as int).toDouble(),
                    pointColorMapper: (data, _) => data['color'] as Color,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: true,
                      labelPosition: ChartDataLabelPosition.inside,
                      textStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    explode: false,
                    gapRatio: 0.05,
                  ),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    format: 'point.x: point.y',
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                    textStyle: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    borderWidth: 1,
                    borderColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                    elevation: 2,
                    canShowMarker: false,
                    duration: 500,
                  ),
                ),
              );
            }(),
    );
  }

  Widget _buildVerticalChart(bool isDark) {
    return _buildChartContainer(
      title: 'TCS Vertical Distribution',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              final dist = _stats!.verticalDistribution;
              if (dist.isEmpty) {
                return _buildNoData(isDark);
              }

              final sorted = dist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final top6 = sorted.take(6).toList();

              final chartData = top6.asMap().entries.map((entry) {
                return {
                  'vertical': _formatVertical(entry.value.key),
                  'value': entry.value.value,
                  'color': _getChartColor(entry.key),
                };
              }).toList();

              final maxValue = chartData.fold<int>(0, (max, item) => (item['value'] as int) > max ? (item['value'] as int) : max);

              return SizedBox(
                height: 240,
                child: SfCartesianChart(
                  plotAreaBorderWidth: 0,
                  primaryXAxis: CategoryAxis(
                    majorGridLines: const MajorGridLines(width: 0),
                    labelStyle: TextStyle(
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    axisLine: const AxisLine(width: 0),
                  ),
                  primaryYAxis: NumericAxis(
                    majorGridLines: MajorGridLines(
                      width: 1,
                      color: (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)).withValues(alpha: 0.5),
                    ),
                    axisLine: const AxisLine(width: 0),
                    labelStyle: TextStyle(
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      fontSize: 8,
                    ),
                    minimum: 0,
                    maximum: maxValue.toDouble() * 1.1,
                  ),
                  series: <CartesianSeries>[
                    BarSeries<Map<String, dynamic>, String>(
                      dataSource: chartData,
                      xValueMapper: (data, _) => data['vertical'] as String,
                      yValueMapper: (data, _) => (data['value'] as int).toDouble(),
                      pointColorMapper: (data, _) => data['color'] as Color,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                      dataLabelSettings: DataLabelSettings(
                        isVisible: true,
                        labelAlignment: ChartDataLabelAlignment.outer,
                        textStyle: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    format: 'point.x: point.y',
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                    textStyle: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    borderWidth: 1,
                    borderColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                    elevation: 2,
                    canShowMarker: false,
                    duration: 500,
                  ),
                ),
              );
            }(),
    );
  }

  Widget _buildTimeSlotChart(bool isDark) {
    return _buildChartContainer(
      title: 'Approval Pipeline',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              final breakdown = _stats!.statusBreakdown;
              final stages = [
                {'label': 'Under Review', 'value': breakdown.underReview, 'color': const Color(0xFFF05E1B)},
                {'label': 'Need Edit', 'value': breakdown.needEdit, 'color': const Color(0xFFF97316)},
                {'label': 'Need Reschedule', 'value': breakdown.needReschedule, 'color': const Color(0xFF8B5CF6)},
                {'label': 'Approved', 'value': breakdown.approved, 'color': const Color(0xFF10B981)},
                {'label': 'Not Approved', 'value': breakdown.notApproved, 'color': const Color(0xFFEF4444)},
              ];

              final maxValue = stages.fold<int>(0, (max, stage) => (stage['value'] as int) > max ? (stage['value'] as int) : max);

              return Column(
                children: [
                  const SizedBox(height: 4),
                  ...stages.map((stage) {
                    final value = stage['value'] as int;
                    final label = stage['label'] as String;
                    final color = stage['color'] as Color;
                    final percentage = maxValue > 0 ? (value / maxValue) : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                ),
                              ),
                              Text(
                                value.toString(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: percentage,
                              minHeight: 18,
                              backgroundColor: (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            }(),
    );
  }

  Widget _buildMonthlyTrendChart(bool isDark) {
    return _buildChartContainer(
      title: 'Monthly Trend (Last 6 Months)',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              final trend = _stats!.monthlyTrend;
              if (trend.isEmpty) {
                return _buildNoData(isDark);
              }

              final maxY = trend.fold<int>(0, (max, t) => t.count > max ? t.count : max).toDouble();

              return SizedBox(
                height: 240,
                child: SfCartesianChart(
                  plotAreaBorderWidth: 0,
                  primaryXAxis: CategoryAxis(
                    majorGridLines: const MajorGridLines(width: 0),
                    labelStyle: TextStyle(
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      fontSize: 10,
                    ),
                    axisLine: const AxisLine(width: 0),
                  ),
                  primaryYAxis: NumericAxis(
                    majorGridLines: MajorGridLines(
                      width: 1,
                      color: (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)).withValues(alpha: 0.5),
                    ),
                    axisLine: const AxisLine(width: 0),
                    labelStyle: TextStyle(
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      fontSize: 10,
                    ),
                    minimum: 0,
                    maximum: maxY * 1.2,
                  ),
                  legend: Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    textStyle: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 10,
                    ),
                  ),
                  series: <CartesianSeries>[
                    SplineAreaSeries<MonthlyTrend, String>(
                      dataSource: trend,
                      xValueMapper: (data, _) => data.month.substring(5),
                      yValueMapper: (data, _) => data.count.toDouble(),
                      name: 'Total Bookings',
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                      borderColor: const Color(0xFF3B82F6),
                      borderWidth: 2,
                      markerSettings: const MarkerSettings(
                        isVisible: true,
                        height: 6,
                        width: 6,
                        color: Color(0xFF3B82F6),
                        borderColor: Colors.white,
                        borderWidth: 1,
                      ),
                    ),
                    SplineAreaSeries<MonthlyTrend, String>(
                      dataSource: trend,
                      xValueMapper: (data, _) => data.month.substring(5),
                      yValueMapper: (data, _) => data.approved.toDouble(),
                      name: 'Approved',
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      borderColor: const Color(0xFF10B981),
                      borderWidth: 2,
                      markerSettings: const MarkerSettings(
                        isVisible: true,
                        height: 6,
                        width: 6,
                        color: Color(0xFF10B981),
                        borderColor: Colors.white,
                        borderWidth: 1,
                      ),
                    ),
                  ],
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    format: 'point.x: point.y',
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                    textStyle: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    borderWidth: 1,
                    borderColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                    elevation: 2,
                    canShowMarker: false,
                    duration: 500,
                  ),
                ),
              );
            }(),
    );
  }

  Widget _buildTopCompaniesCard(bool isDark) {
    return _buildChartContainer(
      title: 'Top Visitors',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : _stats!.topCompanies.isEmpty
              ? _buildNoData(isDark)
              : SingleChildScrollView(
                  child: Column(
                    children: _stats!.topCompanies.asMap().entries.map((entry) {
                      final rank = entry.key + 1;
                      final company = entry.value;
                      return _buildRankingCard(rank, company.company, company.visits, isDark);
                    }).toList(),
                  ),
                ),
    );
  }

  Widget _buildRankingCard(int rank, String companyName, int visits, bool isDark) {
    Color? borderColor;
    LinearGradient? gradient;
    String? trophyAsset;

    if (rank == 1) {
      borderColor = const Color(0xFFFFD700); // Gold
      trophyAsset = 'assets/icons/gold_trophy.svg';
      // Gradient from gold to darker gold (left to right)
      gradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          borderColor.withValues(alpha: 0.15),
          borderColor.withValues(alpha: 0.05),
        ],
      );
    } else if (rank == 2) {
      borderColor = const Color(0xFFC0C0C0); // Silver
      trophyAsset = 'assets/icons/silver_trophy.svg';
      // Gradient from silver to darker silver (left to right)
      gradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          borderColor.withValues(alpha: 0.15),
          borderColor.withValues(alpha: 0.05),
        ],
      );
    } else if (rank == 3) {
      borderColor = const Color(0xFFCD7F32); // Bronze
      trophyAsset = 'assets/icons/bronze_trophy.svg';
      // Gradient from bronze to darker bronze (left to right)
      gradient = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          borderColor.withValues(alpha: 0.15),
          borderColor.withValues(alpha: 0.05),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? (isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6)) : null,
        borderRadius: BorderRadius.circular(8),
        border: borderColor != null ? Border.all(
          color: borderColor,
          width: 2,
        ) : null,
      ),
      child: Row(
        children: [
          // Rank number with trophy
          SizedBox(
            width: 50,
            child: Row(
              children: [
                Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 6),
                if (rank <= 3 && trophyAsset != null)
                  SvgPicture.asset(
                    trophyAsset,
                    width: 20,
                    height: 20,
                  ),
              ],
            ),
          ),
          // Company name
          Expanded(
            child: Text(
              companyName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Visits count
          Text(
            '$visits',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: rank <= 3 ? borderColor : (isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // Event Type Distribution - Waterfall Chart showing TCS vs Partner events
  Widget _buildEventTypeWaterfall(bool isDark) {
    return _buildChartContainer(
      title: 'Event Type Analysis',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              // Simulated data based on total bookings
              final total = _stats!.totalBookings;
              final tcsEvents = (total * 0.65).toInt();
              final partnerEvents = total - tcsEvents;

              if (total == 0) return _buildNoData(isDark);

              final waterfallData = [
                {'category': 'TCS', 'value': tcsEvents, 'color': const Color(0xFF0EA5E9)},
                {'category': 'Partner', 'value': partnerEvents, 'color': const Color(0xFFA855F7)},
              ];

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 200,
                    child: SfCartesianChart(
                      plotAreaBorderWidth: 0,
                      primaryXAxis: CategoryAxis(
                        majorGridLines: const MajorGridLines(width: 0),
                        labelStyle: TextStyle(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          fontSize: 10,
                        ),
                        axisLine: const AxisLine(width: 0),
                      ),
                      primaryYAxis: NumericAxis(
                        majorGridLines: MajorGridLines(
                          width: 1,
                          color: (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
                        ),
                        axisLine: const AxisLine(width: 0),
                        labelStyle: TextStyle(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          fontSize: 10,
                        ),
                      ),
                      series: <CartesianSeries>[
                        ColumnSeries<Map<String, dynamic>, String>(
                          dataSource: waterfallData,
                          xValueMapper: (data, _) => data['category'] as String,
                          yValueMapper: (data, _) => (data['value'] as int).toDouble(),
                          pointColorMapper: (data, _) => data['color'] as Color,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          dataLabelSettings: DataLabelSettings(
                            isVisible: true,
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          width: 0.7,
                        ),
                      ],
                      tooltipBehavior: TooltipBehavior(
                        enable: true,
                        format: 'point.x: point.y',
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                        textStyle: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        borderWidth: 1,
                        borderColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                        elevation: 2,
                        canShowMarker: false,
                        duration: 500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildLegendItem('TCS Events ($tcsEvents)', const Color(0xFF0EA5E9), isDark),
                      _buildLegendItem('Partner Events ($partnerEvents)', const Color(0xFFA855F7), isDark),
                    ],
                  ),
                ],
              );
            }(),
    );
  }

  // Deal Status Distribution - Bubble chart showing SWON vs WON
  Widget _buildDealStatusBubble(bool isDark) {
    return _buildChartContainer(
      title: 'Deal Pipeline Status',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              // Simulated data based on total bookings
              final total = _stats!.totalBookings;
              final swon = (total * 0.45).toInt();
              final won = (total * 0.55).toInt();

              if (total == 0) return _buildNoData(isDark);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 200,
                    child: SfCircularChart(
                      series: <CircularSeries>[
                        PieSeries<Map<String, dynamic>, String>(
                          dataSource: [
                            {'status': 'SWON', 'value': swon, 'color': const Color(0xFFFB923C)},
                            {'status': 'WON', 'value': won, 'color': const Color(0xFF22C55E)},
                          ],
                          xValueMapper: (data, _) => data['status'] as String,
                          yValueMapper: (data, _) => (data['value'] as int).toDouble(),
                          pointColorMapper: (data, _) => data['color'] as Color,
                          dataLabelSettings: DataLabelSettings(
                            isVisible: true,
                            labelPosition: ChartDataLabelPosition.outside,
                            textStyle: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            connectorLineSettings: ConnectorLineSettings(
                              type: ConnectorType.curve,
                              width: 1.5,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          ),
                          dataLabelMapper: (data, _) {
                            final value = data['value'] as int;
                            final percentage = (value / total * 100).toStringAsFixed(1);
                            return '$percentage%';
                          },
                          explode: true,
                          explodeIndex: 1,
                          explodeOffset: '8%',
                        ),
                      ],
                      tooltipBehavior: TooltipBehavior(
                        enable: true,
                        format: 'point.x: point.y',
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                        textStyle: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        borderWidth: 1,
                        borderColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                        elevation: 2,
                        canShowMarker: false,
                        duration: 500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildLegendItem('SWON ($swon)', const Color(0xFFFB923C), isDark),
                      _buildLegendItem('WON ($won)', const Color(0xFF22C55E), isDark),
                    ],
                  ),
                ],
              );
            }(),
    );
  }

  Widget _buildChartContainer({
    required String title,
    required bool isDark,
    required Widget child,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final containerHeight = screenWidth >= 1024
            ? 380.0
            : screenWidth >= 600
                ? 380.0
                : 420.0;

        return Container(
          height: containerHeight,
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
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
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getChartColor(int index) {
    final colors = [
      const Color(0xFFEF4444), // red
      const Color(0xFFF05E1B), // yellow
      const Color(0xFF10B981), // green
      const Color(0xFF3B82F6), // blue
      const Color(0xFF8B5CF6), // purple
      const Color(0xFFF97316), // orange
      const Color(0xFF06B6D4), // cyan
      const Color(0xFFEC4899), // pink
      const Color(0xFF14B8A6), // teal
      const Color(0xFFF05E1B), // amber
      const Color(0xFF6366F1), // indigo
      const Color(0xFF84CC16), // lime
      const Color(0xFFA855F7), // violet
      const Color(0xFF0EA5E9), // sky
      const Color(0xFFFB923C), // orange-400
      const Color(0xFF22C55E), // green-500
    ];
    return colors[index % colors.length];
  }

  String _formatVertical(String vertical) {
    return vertical.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  // Organization Type Conversion - Horizontal Bar Chart
  Widget _buildOrgTypeConversion(bool isDark) {
    return _buildChartContainer(
      title: 'Lead Conversion',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              final orgDist = _stats!.organizationTypeDistribution;
              if (orgDist.isEmpty) {
                return _buildNoData(isDark);
              }

              final prospects = orgDist['PROSPECT'] ?? 0;
              final customers = orgDist['EXISTING_CUSTOMER'] ?? 0;
              final partners = orgDist['PARTNER'] ?? 0;
              final govt = orgDist['GOVERNMENTAL_INSTITUTION'] ?? 0;

              final total = prospects + customers + partners + govt;
              if (total == 0) return _buildNoData(isDark);

              final chartData = [
                {'type': 'Prospects', 'value': prospects, 'color': const Color(0xFFF05E1B)},
                {'type': 'Customers', 'value': customers, 'color': const Color(0xFF10B981)},
                {'type': 'Partners', 'value': partners, 'color': const Color(0xFF3B82F6)},
                {'type': 'Government', 'value': govt, 'color': const Color(0xFFEF4444)},
              ];

              final maxValue = [prospects, customers, partners, govt].reduce((a, b) => a > b ? a : b);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: SizedBox(
                      height: 220,
                      child: SfCartesianChart(
                        plotAreaBorderWidth: 0,
                        primaryXAxis: CategoryAxis(
                          majorGridLines: const MajorGridLines(width: 0),
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                          axisLine: const AxisLine(width: 0),
                        ),
                        primaryYAxis: NumericAxis(
                          majorGridLines: MajorGridLines(
                            width: 1,
                            color: (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)).withValues(alpha: 0.5),
                          ),
                          axisLine: const AxisLine(width: 0),
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            fontSize: 8,
                          ),
                          minimum: 0,
                          maximum: maxValue.toDouble() * 1.15,
                        ),
                        series: <CartesianSeries>[
                          BarSeries<Map<String, dynamic>, String>(
                            dataSource: chartData,
                            xValueMapper: (data, _) => data['type'] as String,
                            yValueMapper: (data, _) => (data['value'] as int).toDouble(),
                            pointColorMapper: (data, _) => data['color'] as Color,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                            width: 0.6,
                            dataLabelSettings: DataLabelSettings(
                              isVisible: true,
                              labelAlignment: ChartDataLabelAlignment.outer,
                              textStyle: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                        tooltipBehavior: TooltipBehavior(
                          enable: true,
                          format: 'point.x: point.y',
                          color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                          textStyle: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          borderWidth: 1,
                          borderColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                          elevation: 2,
                          canShowMarker: false,
                          duration: 500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: chartData.map((data) {
                      final type = data['type'] as String;
                      final value = data['value'] as int;
                      final color = data['color'] as Color;
                      return _buildLegendItem('$type ($value)', color, isDark);
                    }).toList(),
                  ),
                ],
              );
            }(),
    );
  }

  // Average Attendees per Visit Type - Column Chart
  Widget _buildAttendeesByType(bool isDark) {
    return _buildChartContainer(
      title: 'Avg Attendees/Type',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              final avgAttendees = _stats!.avgAttendees;

              // Simulate distribution - in reality would come from backend
              final data = [
                {'type': 'PACE\nTour', 'label': 'PACE Tour', 'value': (avgAttendees * 0.8).toDouble(), 'color': const Color(0xFFEF4444)},
                {'type': 'PACE\nExp', 'label': 'PACE Experience', 'value': (avgAttendees * 1.2).toDouble(), 'color': const Color(0xFFF05E1B)},
                {'type': 'Innovation\nExch', 'label': 'Innovation Exchange', 'value': (avgAttendees * 1.5).toDouble(), 'color': const Color(0xFF10B981)},
              ];

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: SizedBox(
                      height: 200,
                      child: SfCartesianChart(
                        plotAreaBorderWidth: 0,
                        primaryXAxis: CategoryAxis(
                          majorGridLines: const MajorGridLines(width: 0),
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            fontSize: 8,
                          ),
                          axisLine: const AxisLine(width: 0),
                        ),
                        primaryYAxis: NumericAxis(
                          majorGridLines: MajorGridLines(
                            width: 1,
                            color: (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)).withValues(alpha: 0.5),
                          ),
                          axisLine: const AxisLine(width: 0),
                          labelStyle: TextStyle(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            fontSize: 8,
                          ),
                        ),
                        series: <CartesianSeries>[
                          ColumnSeries<Map<String, dynamic>, String>(
                            dataSource: data,
                            xValueMapper: (data, _) => data['type'] as String,
                            yValueMapper: (data, _) => data['value'] as double,
                            pointColorMapper: (data, _) => data['color'] as Color,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            dataLabelSettings: DataLabelSettings(
                              isVisible: true,
                              textStyle: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: data.map((item) {
                      final label = item['label'] as String;
                      final value = (item['value'] as double).toStringAsFixed(1);
                      final color = item['color'] as Color;
                      return _buildLegendItem('$label ($value)', color, isDark);
                    }).toList(),
                  ),
                ],
              );
            }(),
    );
  }

  // Engagement Depth - Stacked Column showing questionnaire completion
  Widget _buildEngagementDepth(bool isDark) {
    return _buildChartContainer(
      title: 'Engagement Depth',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              final total = _stats!.totalBookings;
              if (total == 0) return _buildNoData(isDark);

              // Simulate engagement metrics
              final basic = (total * 0.4).toInt(); // Only basic visit
              final questionnaire = (total * 0.35).toInt(); // With questionnaire
              final fullEngagement = (total * 0.25).toInt(); // With alignment call

              return Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 180,
                      child: SfCartesianChart(
                      plotAreaBorderWidth: 0,
                      primaryXAxis: CategoryAxis(
                        isVisible: false,
                      ),
                      primaryYAxis: NumericAxis(
                        isVisible: false,
                        maximum: total.toDouble(),
                      ),
                      series: <CartesianSeries>[
                        StackedColumnSeries<Map<String, dynamic>, String>(
                          dataSource: [{'x': 'Engagement'}],
                          xValueMapper: (data, _) => data['x'] as String,
                          yValueMapper: (_, __) => basic.toDouble(),
                          color: const Color(0xFFF05E1B),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                          dataLabelSettings: const DataLabelSettings(isVisible: false),
                        ),
                        StackedColumnSeries<Map<String, dynamic>, String>(
                          dataSource: [{'x': 'Engagement'}],
                          xValueMapper: (data, _) => data['x'] as String,
                          yValueMapper: (_, __) => questionnaire.toDouble(),
                          color: const Color(0xFF10B981),
                          dataLabelSettings: const DataLabelSettings(isVisible: false),
                        ),
                        StackedColumnSeries<Map<String, dynamic>, String>(
                          dataSource: [{'x': 'Engagement'}],
                          xValueMapper: (data, _) => data['x'] as String,
                          yValueMapper: (_, __) => fullEngagement.toDouble(),
                          color: const Color(0xFFEF4444),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          dataLabelSettings: const DataLabelSettings(isVisible: false),
                        ),
                      ],
                      tooltipBehavior: TooltipBehavior(
                        enable: true,
                        format: 'point.y',
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB),
                        textStyle: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        borderWidth: 1,
                        borderColor: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
                        elevation: 2,
                        canShowMarker: false,
                        duration: 500,
                      ),
                    ),
                  ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildLegendItem('Basic Visit ($basic)', const Color(0xFFF05E1B), isDark),
                        _buildLegendItem('+ Questionnaire ($questionnaire)', const Color(0xFF10B981), isDark),
                        _buildLegendItem('+ Alignment Call ($fullEngagement)', const Color(0xFFEF4444), isDark),
                      ],
                    ),
                  ],
                ),
              );
            }(),
    );
  }

  /// Build discrete FCM Test Button (diego@tcs.com only)
  Widget _buildDiscreteFCMTestButton(bool isDark) {
    // Get current user email
    final authProvider = context.read<AuthProvider>();
    final userEmail = authProvider.user?.email;

    // Only show for diego@tcs.com
    if (userEmail != 'diego@tcs.com') {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: _sendTestNotification,
        icon: Icon(
          Icons.notifications_active_outlined,
          size: 16,
          color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
        ),
        label: Text(
          'Test FCM',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  /// Send test FCM notification
  Future<void> _sendTestNotification() async {
    try {
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );

      // Send test notification
      final response = await _apiService.sendTestFCMNotification();

      // Close loading dialog
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (e) {
        }
      }

      // Show success message
      if (!mounted) return;
      ToastNotification.show(
        context,
        message: 'Test notification sent to ${response['deviceCount'] ?? 'all'} devices!',
        type: ToastType.success,
      );
    } catch (e) {
      // Close loading dialog safely
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (navError) {
        }
      }

      // Show error message
      if (!mounted) return;
      ToastNotification.show(
        context,
        message: 'Error sending test notification: ${e.toString()}',
        type: ToastType.error,
      );
    }
  }
}

// Stacked Area Chart Widget using Syncfusion
class _ScatterChartWidget extends StatelessWidget {
  final bool isDark;

  const _ScatterChartWidget({required this.isDark});

  List<_VisitData> _generateStackedData() {
    // Generate sample data for the last 6 time periods
    return [
      _VisitData('Week 1', 8, 12, 5),
      _VisitData('Week 2', 12, 15, 8),
      _VisitData('Week 3', 10, 18, 10),
      _VisitData('Week 4', 15, 20, 12),
      _VisitData('Week 5', 18, 22, 15),
      _VisitData('Week 6', 20, 25, 18),
    ];
  }

  double _getMaxStackedValue() {
    final data = _generateStackedData();
    return data.map((d) => d.paceTour + d.paceExperience + d.innovationExchange).reduce((a, b) => a > b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    final data = _generateStackedData();

    return SfCartesianChart(
      plotAreaBorderWidth: 0,
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          fontSize: 7,
        ),
        axisLine: const AxisLine(width: 0),
      ),
      primaryYAxis: NumericAxis(
        majorGridLines: MajorGridLines(
          width: 1,
          color: (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)).withValues(alpha: 0.5),
        ),
        axisLine: const AxisLine(width: 0),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          fontSize: 7,
        ),
        minimum: 0,
        maximum: (_getMaxStackedValue() * 1.05).ceilToDouble(), // Round up to ensure whole numbers
        decimalPlaces: 0, // Force integer labels
      ),
      series: <CartesianSeries<_VisitData, String>>[
        StackedAreaSeries<_VisitData, String>(
          dataSource: data,
          xValueMapper: (_VisitData visits, _) => visits.period,
          yValueMapper: (_VisitData visits, _) => visits.paceTour,
          name: 'PACE Tour',
          color: const Color(0xFFEF4444).withValues(alpha: 0.7), // Red from palette
          borderColor: const Color(0xFFEF4444),
          borderWidth: 2,
        ),
        StackedAreaSeries<_VisitData, String>(
          dataSource: data,
          xValueMapper: (_VisitData visits, _) => visits.period,
          yValueMapper: (_VisitData visits, _) => visits.paceExperience,
          name: 'PACE Experience',
          color: const Color(0xFFF05E1B).withValues(alpha: 0.7), // Yellow from palette
          borderColor: const Color(0xFFF05E1B),
          borderWidth: 2,
        ),
        StackedAreaSeries<_VisitData, String>(
          dataSource: data,
          xValueMapper: (_VisitData visits, _) => visits.period,
          yValueMapper: (_VisitData visits, _) => visits.innovationExchange,
          name: 'Innovation Exchange',
          color: const Color(0xFF10B981).withValues(alpha: 0.7), // Green from palette
          borderColor: const Color(0xFF10B981),
          borderWidth: 2,
        ),
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        color: isDark ? const Color(0xFF27272A) : const Color(0xFF1F2937),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
        format: 'point.x: point.y visits',
        borderWidth: 0,
        borderColor: Colors.transparent,
        elevation: 2,
        canShowMarker: false,
        duration: 500,
      ),
    );
  }

}

// Data class for stacked area chart
class _VisitData {
  _VisitData(this.period, this.paceTour, this.paceExperience, this.innovationExchange);

  final String period;
  final double paceTour;
  final double paceExperience;
  final double innovationExchange;
}
