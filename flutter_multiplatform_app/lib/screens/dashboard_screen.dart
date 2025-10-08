import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/app_layout.dart';
import '../providers/theme_provider.dart';
import '../services/api_service.dart';
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
  List<MonthlyBookingData> _monthlyBookings = [];
  List<TrendsData> _trends = [];
  List<SectorData> _sectors = [];
  List<InterestData> _interests = [];
  List<TopCompany> _topCompanies = [];

  // Loading states
  bool _loadingStats = true;
  bool _loadingMonthly = true;
  bool _loadingTrends = true;
  bool _loadingSectors = true;
  bool _loadingInterests = true;
  bool _loadingCompanies = true;

  // Filters
  int _selectedYear = DateTime.now().year;
  int _selectedTrendMonths = 6;

  // Error
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadStats(),
      _loadMonthlyBookings(),
      _loadTrends(),
      _loadSectors(),
      _loadInterests(),
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

  Future<void> _loadMonthlyBookings() async {
    try {
      setState(() => _loadingMonthly = true);
      final data = await _apiService.getBookingsByMonth(_selectedYear);
      setState(() {
        _monthlyBookings = data.map((e) => MonthlyBookingData.fromJson(e)).toList();
        _loadingMonthly = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingMonthly = false;
      });
    }
  }

  Future<void> _loadTrends() async {
    try {
      setState(() => _loadingTrends = true);
      final data = await _apiService.getTrends(_selectedTrendMonths);
      setState(() {
        _trends = data.map((e) => TrendsData.fromJson(e)).toList();
        _loadingTrends = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingTrends = false;
      });
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

  Future<void> _loadInterests() async {
    try {
      setState(() => _loadingInterests = true);
      final data = await _apiService.getBookingsByInterest(_selectedYear);
      setState(() {
        _interests = data.map((e) => InterestData.fromJson(e)).toList();
        _loadingInterests = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingInterests = false;
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final content = Container(
        color: isDark ? Colors.black : const Color(0xFFF9FAFB),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 16 : 24),
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
                    color: Colors.red.withOpacity(0.1),
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

              // Stat Cards
              _buildStatCards(isDark, isMobile),
              const SizedBox(height: 24),

              // Charts Grid
              if (isMobile)
                Column(
                  children: [
                    _buildMonthlyBookingsChart(isDark),
                    const SizedBox(height: 24),
                    _buildTrendsChart(isDark),
                    const SizedBox(height: 24),
                    _buildSectorsChart(isDark),
                    const SizedBox(height: 24),
                    _buildInterestsChart(isDark),
                    const SizedBox(height: 24),
                    _buildTopCompaniesCard(isDark),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildMonthlyBookingsChart(isDark)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildTrendsChart(isDark)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildSectorsChart(isDark)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildInterestsChart(isDark)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildTopCompaniesCard(isDark),
                  ],
                ),
            ],
          ),
        ),
      );

    return widget.skipLayout ? content : AppLayout(child: content);
  }

  Widget _buildStatCards(bool isDark, bool isMobile) {
    final stats = _stats;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = isMobile ? 2 : (constraints.maxWidth > 1200 ? 6 : 3);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: isMobile ? 1.5 : 2,
          children: [
            _buildStatCard(
              'Total Bookings',
              _loadingStats ? '...' : (stats?.totalBookings.toString() ?? '0'),
              Icons.calendar_today,
              isDark,
            ),
            _buildStatCard(
              'This Month',
              _loadingStats ? '...' : (stats?.thisMonthBookings.toString() ?? '0'),
              Icons.trending_up,
              isDark,
            ),
            _buildStatCard(
              'Companies',
              _loadingStats ? '...' : (stats?.uniqueCompanies.toString() ?? '0'),
              Icons.business,
              isDark,
            ),
            _buildStatCard(
              'Attendees',
              _loadingStats ? '...' : (stats?.totalAttendeesThisYear.toString() ?? '0'),
              Icons.people,
              isDark,
            ),
            _buildStatCard(
              'Pending',
              _loadingStats ? '...' : (stats?.pendingBookings.toString() ?? '0'),
              Icons.hourglass_empty,
              isDark,
            ),
            _buildStatCard(
              'This Year',
              _loadingStats ? '...' : (stats?.thisYearBookings.toString() ?? '0'),
              Icons.event_available,
              isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, bool isDark) {
    return Container(
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
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              Icon(
                icon,
                size: 16,
                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyBookingsChart(bool isDark) {
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
              Text(
                'Monthly Bookings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              DropdownButton<int>(
                value: _selectedYear,
                dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                underline: Container(),
                items: List.generate(5, (index) {
                  final year = DateTime.now().year - index;
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedYear = value);
                    _loadMonthlyBookings();
                    _loadSectors();
                    _loadInterests();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: _loadingMonthly
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  )
                : _monthlyBookings.isEmpty
                    ? Center(
                        child: Text(
                          'No data available',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      )
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: _monthlyBookings.fold<int>(0, (max, data) {
                                final total = data.threeHours + data.sixHours;
                                return total > max ? total : max;
                              }).toDouble() *
                              1.2,
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipColor: (group) => isDark ? const Color(0xFF27272A) : Colors.white,
                              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                return BarTooltipItem(
                                  '${_monthlyBookings[groupIndex].month}\n${rod.toY.round()}',
                                  TextStyle(
                                    color: isDark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
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
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 && value.toInt() < _monthlyBookings.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _monthlyBookings[value.toInt()].month.substring(0, 3),
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
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                strokeWidth: 1,
                              );
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(
                            _monthlyBookings.length,
                            (index) {
                              final data = _monthlyBookings[index];
                              return BarChartGroupData(
                                x: index,
                                barRods: [
                                  BarChartRodData(
                                    toY: data.threeHours.toDouble(),
                                    color: const Color(0xFF3B82F6),
                                    width: 16,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                  BarChartRodData(
                                    toY: data.sixHours.toDouble(),
                                    color: const Color(0xFF8B5CF6),
                                    width: 16,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      topRight: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('3 Hours', const Color(0xFF3B82F6), isDark),
              const SizedBox(width: 24),
              _buildLegendItem('6 Hours', const Color(0xFF8B5CF6), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsChart(bool isDark) {
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
              Text(
                'Trends',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              DropdownButton<int>(
                value: _selectedTrendMonths,
                dropdownColor: isDark ? const Color(0xFF18181B) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                underline: Container(),
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3 months')),
                  DropdownMenuItem(value: 6, child: Text('6 months')),
                  DropdownMenuItem(value: 12, child: Text('12 months')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedTrendMonths = value);
                    _loadTrends();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: _loadingTrends
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  )
                : _trends.isEmpty
                    ? Center(
                        child: Text(
                          'No data available',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          maxY: _trends.fold<int>(0, (max, data) {
                                final maxVal = data.bookings > data.attendees ? data.bookings : data.attendees;
                                return maxVal > max ? maxVal : max;
                              }).toDouble() *
                              1.2,
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipColor: (touchedSpot) => isDark ? const Color(0xFF27272A) : Colors.white,
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final data = _trends[spot.x.toInt()];
                                  final isBookings = spot.barIndex == 0;
                                  return LineTooltipItem(
                                    '${data.month}\n${isBookings ? 'Bookings' : 'Attendees'}: ${spot.y.round()}',
                                    TextStyle(
                                      color: isDark ? Colors.white : Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 && value.toInt() < _trends.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        _trends[value.toInt()].month.substring(0, 3),
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
                            horizontalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return FlLine(
                                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                                strokeWidth: 1,
                              );
                            },
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            LineChartBarData(
                              spots: List.generate(
                                _trends.length,
                                (index) => FlSpot(index.toDouble(), _trends[index].bookings.toDouble()),
                              ),
                              isCurved: true,
                              color: const Color(0xFF3B82F6),
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: const Color(0xFF3B82F6).withOpacity(0.1),
                              ),
                            ),
                            LineChartBarData(
                              spots: List.generate(
                                _trends.length,
                                (index) => FlSpot(index.toDouble(), _trends[index].attendees.toDouble()),
                              ),
                              isCurved: true,
                              color: const Color(0xFF10B981),
                              barWidth: 3,
                              dotData: const FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                color: const Color(0xFF10B981).withOpacity(0.1),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Bookings', const Color(0xFF3B82F6), isDark),
              const SizedBox(width: 24),
              _buildLegendItem('Attendees', const Color(0xFF10B981), isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectorsChart(bool isDark) {
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
          Text(
            'Bookings by Sector',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          _loadingSectors
              ? const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _sectors.isEmpty
                  ? SizedBox(
                      height: 300,
                      child: Center(
                        child: Text(
                          'No data available',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 250,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 60,
                              sections: _sectors.asMap().entries.map((entry) {
                                final index = entry.key;
                                final data = entry.value;
                                final color = _getChartColor(index);
                                final total = _sectors.fold<int>(0, (sum, s) => sum + s.count);
                                final percentage = (data.count / total * 100).toStringAsFixed(1);

                                return PieChartSectionData(
                                  color: color,
                                  value: data.count.toDouble(),
                                  title: '$percentage%',
                                  radius: 50,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: _sectors.asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            return _buildLegendItem(
                              '${data.sector} (${data.count})',
                              _getChartColor(index),
                              isDark,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
        ],
      ),
    );
  }

  Widget _buildInterestsChart(bool isDark) {
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
          Text(
            'Bookings by Interest Area',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          _loadingInterests
              ? const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator()),
                )
              : _interests.isEmpty
                  ? SizedBox(
                      height: 300,
                      child: Center(
                        child: Text(
                          'No data available',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 250,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 60,
                              sections: _interests.asMap().entries.map((entry) {
                                final index = entry.key;
                                final data = entry.value;
                                final color = _getChartColor(index);
                                final total = _interests.fold<int>(0, (sum, i) => sum + i.count);
                                final percentage = (data.count / total * 100).toStringAsFixed(1);

                                return PieChartSectionData(
                                  color: color,
                                  value: data.count.toDouble(),
                                  title: '$percentage%',
                                  radius: 50,
                                  titleStyle: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 16,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: _interests.asMap().entries.map((entry) {
                            final index = entry.key;
                            final data = entry.value;
                            return _buildLegendItem(
                              '${data.area} (${data.count})',
                              _getChartColor(index),
                              isDark,
                            );
                          }).toList(),
                        ),
                      ],
                    ),
        ],
      ),
    );
  }

  Widget _buildTopCompaniesCard(bool isDark) {
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
          Text(
            'Top Companies',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 24),
          _loadingCompanies
              ? const Center(child: CircularProgressIndicator())
              : _topCompanies.isEmpty
                  ? Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                        ),
                      ),
                    )
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
        ],
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
            fontSize: 12,
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
