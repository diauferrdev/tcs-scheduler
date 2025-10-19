import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/app_layout.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
import '../services/universal_update_service.dart';
import '../models/dashboard.dart';

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

            // Stat Cards Grid
            _buildStatCardsGrid(isDark, screenWidth),
            const SizedBox(height: 24),

            // Mini Insights Row (Desktop only)
            if (screenWidth >= 1024) ...[
              _buildMiniInsightsRow(isDark, screenWidth),
              const SizedBox(height: 24),
            ],

            // Charts Grid
            _buildChartsGrid(isDark, screenWidth),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );

    return widget.skipLayout ? content : AppLayout(child: content);
  }

  Widget _buildStatCardsGrid(bool isDark, double screenWidth) {
    if (_loading || _stats == null) {
      return _buildLoadingCards(isDark);
    }

    final total = _stats!.statusDistribution.pending +
        _stats!.statusDistribution.approved +
        _stats!.statusDistribution.notApproved;
    final approvalRate = total > 0
        ? (_stats!.statusDistribution.approved / total * 100)
        : 0.0;

    final statCards = [
      _buildStatCard(
        'Total Bookings',
        _stats!.totalBookings.toString(),
        Icons.calendar_today,
        isDark,
        trend: '+${_stats!.thisMonthBookings} this month',
      ),
      _buildStatCard(
        'Avg Attendees',
        _stats!.avgAttendees.toStringAsFixed(1),
        Icons.people,
        isDark,
        trend: 'per booking',
      ),
      _buildStatCard(
        'Approved',
        _stats!.statusDistribution.approved.toString(),
        Icons.check_circle,
        isDark,
        trend: '${approvalRate.toStringAsFixed(1)}% approval rate',
      ),
      _buildStatCard(
        'Pending',
        _stats!.statusDistribution.pending.toString(),
        Icons.pending,
        isDark,
        trend: 'awaiting review',
      ),
      _buildStatCard(
        'Not Approved',
        _stats!.statusDistribution.notApproved.toString(),
        Icons.cancel,
        isDark,
      ),
      _buildStatCard(
        'This Month',
        _stats!.thisMonthBookings.toString(),
        Icons.today,
        isDark,
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
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: approvalRate / 100,
                  strokeWidth: 8,
                  backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    approvalRate >= 70 ? const Color(0xFF10B981) :
                    approvalRate >= 50 ? const Color(0xFFF59E0B) :
                    const Color(0xFFEF4444),
                  ),
                ),
              ),
              Text(
                '${approvalRate.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFunnel(bool isDark) {
    if (_stats == null) return const SizedBox.shrink();

    final breakdown = _stats!.statusBreakdown;
    final total = breakdown.created + breakdown.underReview +
                  breakdown.needEdit + breakdown.needReschedule +
                  breakdown.approved + breakdown.notApproved;

    if (total == 0) return const SizedBox.shrink();

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
            'Conversion Funnel',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 2,
                minY: 0,
                maxY: total.toDouble() * 1.2,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (touchedSpot) => isDark
                        ? const Color(0xFF27272A)
                        : const Color(0xFF1F2937),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final labels = ['Created', 'Review', 'Approved'];
                      final values = [breakdown.created, breakdown.underReview, breakdown.approved];
                      return LineTooltipItem(
                        '${labels[group.spotIndex]}\n${values[group.spotIndex]}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (total / 3).ceilToDouble(),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: (total / 3).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == meta.max) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 8,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 18,
                      getTitlesWidget: (value, meta) {
                        const labels = ['Created', 'Review', 'Approved'];
                        if (value.toInt() >= 0 && value.toInt() < labels.length) {
                          return Text(
                            labels[value.toInt()],
                            style: TextStyle(
                              fontSize: 7,
                              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: const Color(0xFF10B981),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: const Color(0xFF10B981),
                          strokeWidth: 2,
                          strokeColor: isDark ? Colors.black : Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    ),
                    spots: [
                      FlSpot(0, breakdown.created.toDouble()),
                      FlSpot(1, breakdown.underReview.toDouble()),
                      FlSpot(2, breakdown.approved.toDouble()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMostPopularVisit(bool isDark) {
    if (_stats == null) return const SizedBox.shrink();

    final dist = _stats!.visitTypeDistribution;
    final total = dist.total;
    if (total == 0) return const SizedBox.shrink();

    final types = [
      ('PACE Tour', dist.paceTour, const Color(0xFF3B82F6)),
      ('PACE Experience', dist.paceExperience, const Color(0xFF8B5CF6)),
      ('Innovation Exch.', dist.innovationExchange, const Color(0xFF10B981)),
      ('Quick Tour', dist.quickTour, const Color(0xFFF59E0B)),
    ];
    types.sort((a, b) => b.$2.compareTo(a.$2));
    final popular = types.first;
    final percentage = (popular.$2 / total * 100);

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
            'Most Popular',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                // Chart on the left
                SizedBox(
                  width: 65,
                  height: 65,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 65,
                        height: 65,
                        child: CircularProgressIndicator(
                          value: popular.$2 / total,
                          strokeWidth: 7,
                          backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                          valueColor: AlwaysStoppedAnimation<Color>(popular.$3),
                        ),
                      ),
                      Icon(
                        Icons.star,
                        size: 28,
                        color: popular.$3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Data on the right - centered
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Visit type name - MAIN HIGHLIGHT
                      Text(
                        popular.$1,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: popular.$3,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      // Visit count - SECONDARY
                      Text(
                        '${popular.$2} visits',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      // Percentage - TERTIARY
                      Text(
                        '${percentage.toStringAsFixed(0)}% of total',
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeakTimeCard(bool isDark) {
    if (_stats == null || _stats!.timeSlotDistribution.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by time (chronologically)
    final sorted = _stats!.timeSlotDistribution.entries.toList()
      ..sort((a, b) {
        final hourA = int.tryParse(a.key.split(':')[0]) ?? 0;
        final hourB = int.tryParse(b.key.split(':')[0]) ?? 0;
        return hourA.compareTo(hourB);
      });

    final maxValue = sorted.fold<int>(0, (max, e) => e.value > max ? e.value : max);
    final peakEntry = sorted.reduce((a, b) => a.value > b.value ? a : b);

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
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue.toDouble() * 1.2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => isDark
                        ? const Color(0xFF27272A)
                        : const Color(0xFF1F2937),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tooltipMargin: 4,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final timeSlot = sorted[group.x.toInt()].key;
                      final count = sorted[group.x.toInt()].value;
                      return BarTooltipItem(
                        '$timeSlot\n$count bookings',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sorted.length) {
                          final timeSlot = sorted[value.toInt()].key;
                          final isPeak = timeSlot == peakEntry.key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              timeSlot,
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: isPeak ? FontWeight.bold : FontWeight.normal,
                                color: isPeak
                                    ? const Color(0xFF06B6D4)
                                    : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: (maxValue / 3).ceilToDouble(),
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == meta.max) return const SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 8,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
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
                  horizontalInterval: (maxValue / 3).ceilToDouble(),
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  sorted.length,
                  (index) {
                    final isPeak = sorted[index].key == peakEntry.key;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: sorted[index].value.toDouble(),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: isPeak
                                ? [
                                    const Color(0xFF06B6D4),
                                    const Color(0xFF0891B2),
                                  ]
                                : [
                                    isDark ? const Color(0xFF3F3F46) : const Color(0xFFD1D5DB),
                                    isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                  ],
                          ),
                          width: 10,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(3),
                            topRight: Radius.circular(3),
                          ),
                        ),
                      ],
                    );
                  },
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

              // Row 3: Time Slot Distribution (full width)
              _buildTimeSlotChart(isDark),
              const SizedBox(height: 16),

              _buildMonthlyTrendChart(isDark),
              const SizedBox(height: 16),

              // Row 5: Top Companies & Visit Performance Radar (two columns)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: columnWidth, child: _buildTopCompaniesCard(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: columnWidth, child: _buildVisitPerformanceRadar(isDark)),
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: columnWidth, child: _buildTopCompaniesCard(isDark)),
                  const SizedBox(width: 16),
                  SizedBox(width: columnWidth, child: _buildVisitPerformanceRadar(isDark)),
                ],
              ),
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
              _buildVisitPerformanceRadar(isDark),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, bool isDark, {String? trend}) {
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
                  Text(
                    trend,
                    style: TextStyle(
                      fontSize: 9,
                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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

              return Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 35,
                          sections: [
                            if (dist.paceTour > 0)
                              PieChartSectionData(
                                color: const Color(0xFF3B82F6),
                                value: dist.paceTour.toDouble(),
                                title: '${(dist.paceTour / total * 100).toStringAsFixed(1)}%',
                                radius: 45,
                                titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            if (dist.paceExperience > 0)
                              PieChartSectionData(
                                color: const Color(0xFF8B5CF6),
                                value: dist.paceExperience.toDouble(),
                                title: '${(dist.paceExperience / total * 100).toStringAsFixed(1)}%',
                                radius: 45,
                                titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            if (dist.innovationExchange > 0)
                              PieChartSectionData(
                                color: const Color(0xFF10B981),
                                value: dist.innovationExchange.toDouble(),
                                title: '${(dist.innovationExchange / total * 100).toStringAsFixed(1)}%',
                                radius: 45,
                                titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            if (dist.quickTour > 0)
                              PieChartSectionData(
                                color: const Color(0xFFF59E0B),
                                value: dist.quickTour.toDouble(),
                                title: '${(dist.quickTour / total * 100).toStringAsFixed(1)}%',
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
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      if (dist.paceTour > 0)
                        _buildLegendItem('PACE Tour (${dist.paceTour})', const Color(0xFF3B82F6), isDark),
                      if (dist.paceExperience > 0)
                        _buildLegendItem('PACE Experience (${dist.paceExperience})', const Color(0xFF8B5CF6), isDark),
                      if (dist.innovationExchange > 0)
                        _buildLegendItem('Innovation Exchange (${dist.innovationExchange})', const Color(0xFF10B981), isDark),
                      if (dist.quickTour > 0)
                        _buildLegendItem('Quick Tour (${dist.quickTour})', const Color(0xFFF59E0B), isDark),
                    ],
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

              final sections = <PieChartSectionData>[];
              final legends = <Widget>[];
              int colorIndex = 0;

              void addSection(int value, String label, Color color) {
                if (value > 0) {
                  sections.add(
                    PieChartSectionData(
                      color: color,
                      value: value.toDouble(),
                      title: '${(value / total * 100).toStringAsFixed(1)}%',
                      radius: 40,
                      titleStyle: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  );
                  legends.add(_buildLegendItem('$label ($value)', color, isDark));
                }
              }

              addSection(breakdown.created, 'Created', _getChartColor(colorIndex++));
              addSection(breakdown.underReview, 'Under Review', _getChartColor(colorIndex++));
              addSection(breakdown.needEdit, 'Need Edit', _getChartColor(colorIndex++));
              addSection(breakdown.needReschedule, 'Need Reschedule', _getChartColor(colorIndex++));
              addSection(breakdown.approved, 'Approved', _getChartColor(colorIndex++));
              addSection(breakdown.notApproved, 'Not Approved', _getChartColor(colorIndex++));

              return Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 30,
                          sections: sections,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: legends,
                  ),
                ],
              );
            }(),
    );
  }

  Widget _buildOrganizationTypeChart(bool isDark) {
    return _buildChartContainer(
      title: 'Organization Type Distribution',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              final dist = _stats!.organizationTypeDistribution;
              if (dist.isEmpty) {
                return _buildNoData(isDark);
              }

              final sorted = dist.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              final top5 = sorted.take(5).toList();

              return Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: top5.first.value.toDouble() * 1.4,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
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
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: top5.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildLegendItem(
                        '${_formatOrgType(item.key)} (${item.value})',
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
              final top5 = sorted.take(5).toList();

              return Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: top5.first.value.toDouble() * 1.4,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
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
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: top5.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildLegendItem(
                        '${_formatVertical(item.key)} (${item.value})',
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

  Widget _buildTimeSlotChart(bool isDark) {
    return _buildChartContainer(
      title: 'Popular Time Slots',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              final dist = _stats!.timeSlotDistribution;
              if (dist.isEmpty) {
                return _buildNoData(isDark);
              }

              final sorted = dist.entries.toList()
                ..sort((a, b) {
                  final hourA = int.tryParse(a.key.split(':')[0]) ?? 0;
                  final hourB = int.tryParse(b.key.split(':')[0]) ?? 0;
                  return hourA.compareTo(hourB);
                });

              final maxCount = sorted.fold<int>(0, (max, e) => e.value > max ? e.value : max);

              return SizedBox(
                height: 240,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxCount.toDouble() * 1.2,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < sorted.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  sorted[value.toInt()].key,
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
                      sorted.length,
                      (index) => BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: sorted[index].value.toDouble(),
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
                child: LineChart(
                  LineChartData(
                    maxY: maxY * 1.2,
                    minY: 0,
                    lineBarsData: [
                      LineChartBarData(
                        spots: trend.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value.count.toDouble());
                        }).toList(),
                        isCurved: true,
                        color: const Color(0xFF3B82F6),
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        ),
                      ),
                      LineChartBarData(
                        spots: trend.asMap().entries.map((e) {
                          return FlSpot(e.key.toDouble(), e.value.approved.toDouble());
                        }).toList(),
                        isCurved: true,
                        color: const Color(0xFF10B981),
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() >= 0 && value.toInt() < trend.length) {
                              final month = trend[value.toInt()].month;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  month.substring(5), // MM
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                    fontSize: 10,
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
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : _stats!.topCompanies.isEmpty
              ? _buildNoData(isDark)
              : SingleChildScrollView(
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(70),
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
                      ..._stats!.topCompanies.asMap().entries.map((entry) {
                        final index = entry.key;
                        final company = entry.value;
                        final rank = index + 1;

                        // Trophy colors for top 3
                        IconData? trophyIcon;
                        Color? trophyColor;
                        if (rank == 1) {
                          trophyIcon = Icons.emoji_events;
                          trophyColor = const Color(0xFFFFD700); // Gold
                        } else if (rank == 2) {
                          trophyIcon = Icons.emoji_events;
                          trophyColor = const Color(0xFFC0C0C0); // Silver
                        } else if (rank == 3) {
                          trophyIcon = Icons.emoji_events;
                          trophyColor = const Color(0xFFCD7F32); // Bronze
                        }

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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (trophyIcon != null) ...[
                                    Icon(
                                      trophyIcon,
                                      size: 18,
                                      color: trophyColor,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    '$rank',
                                    style: TextStyle(
                                      fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
                                      color: trophyColor ?? (isDark ? Colors.white : Colors.black),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                company.company,
                                style: TextStyle(
                                  fontWeight: rank <= 3 ? FontWeight.bold : FontWeight.normal,
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
                ),
    );
  }

  Widget _buildVisitPerformanceRadar(bool isDark) {
    return _buildChartContainer(
      title: 'Visit Type Performance',
      isDark: isDark,
      child: _loading || _stats == null
          ? _buildLoadingIndicator(isDark)
          : () {
              final dist = _stats!.visitTypeDistribution;
              final total = dist.total;

              if (total == 0) {
                return _buildNoData(isDark);
              }

              return Center(
                child: SizedBox(
                  height: 240,
                  child: RadarChart(
                    RadarChartData(
                      radarShape: RadarShape.polygon,
                      radarBorderData: BorderSide(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                        width: 2,
                      ),
                      gridBorderData: BorderSide(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      tickBorderData: BorderSide(
                        color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      tickCount: 4,
                      ticksTextStyle: TextStyle(
                        fontSize: 8,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                      radarBackgroundColor: Colors.transparent,
                      titleTextStyle: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                      titlePositionPercentageOffset: 0.15,
                      dataSets: [
                        RadarDataSet(
                          fillColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                          borderColor: const Color(0xFF3B82F6),
                          borderWidth: 2,
                          dataEntries: [
                            RadarEntry(value: dist.paceTour.toDouble()),
                            RadarEntry(value: dist.paceExperience.toDouble()),
                            RadarEntry(value: dist.innovationExchange.toDouble()),
                            RadarEntry(value: dist.quickTour.toDouble()),
                          ],
                        ),
                      ],
                      getTitle: (index, angle) {
                        const titles = [
                          'PACE\nTour',
                          'PACE\nExperience',
                          'Innovation\nExchange',
                          'Quick\nTour',
                        ];
                        return RadarChartTitle(
                          text: titles[index],
                          angle: angle,
                        );
                      },
                    ),
                  ),
                ),
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

  String _formatOrgType(String type) {
    return type.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _formatVertical(String vertical) {
    return vertical.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
