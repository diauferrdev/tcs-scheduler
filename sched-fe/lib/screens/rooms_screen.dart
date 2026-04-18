import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/room_booking.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  final ApiService _apiService = ApiService();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String? _error;
  Map<String, List<Map<String, dynamic>>> _roomAvailability = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    // Auto-refresh every 30s when viewing today
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isSameDay(_selectedDate, DateTime.now()) && mounted) {
        _loadAvailability();
      }
    });
  }

  Future<void> _loadAvailability() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await _apiService.get('/api/rooms/availability/$dateStr');

      // Parse availability data — extract booked slots per room
      final availability = response['availability'] as List? ?? [];
      _roomAvailability = {};
      for (final roomData in availability) {
        final roomName = roomData['room'] as String;
        final slots = (roomData['bookedSlots'] as List? ?? [])
            .map((s) => s as Map<String, dynamic>)
            .toList();
        _roomAvailability[roomName] = slots;
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int _weekOffset = 0;

  List<DateTime> _getWeekDates([int offset = 0]) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)).add(Duration(days: offset * 7));
    return List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Map<String, dynamic>> _slotsForRoom(RoomType room) {
    return _roomAvailability[room.name] ?? [];
  }


  int _parseHour(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]);
  }

  int _parseMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  /// Check if room is currently in use (APPROVED booking covering right now)
  bool _isRoomBusyNow(RoomType room) {
    if (!_isSameDay(_selectedDate, DateTime.now())) return false;
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    for (final s in _slotsForRoom(room)) {
      if (s['status'] == 'APPROVED') {
        final start = _parseMinutes(s['startTime'] as String);
        final end = _parseMinutes(s['endTime'] as String);
        if (nowMinutes >= start && nowMinutes < end) return true;
      }
    }
    return false;
  }

  /// Get usage percentage for the day (0.0 to 1.0) — only APPROVED count
  double _usagePercent(RoomType room) {
    final slots = _slotsForRoom(room).where((s) => s['status'] == 'APPROVED');
    final bookedMinutes = <int>{};
    for (final s in slots) {
      final start = _parseMinutes(s['startTime'] as String);
      final end = _parseMinutes(s['endTime'] as String);
      for (int m = start; m < end; m++) {
        bookedMinutes.add(m);
      }
    }
    return bookedMinutes.length / (12.0 * 60); // 12 hours in minutes
  }

  /// Available hours — only APPROVED block availability
  int _availableHoursApproved(RoomType room) {
    final slots = _slotsForRoom(room).where((s) => s['status'] == 'APPROVED');
    final bookedHours = <int>{};
    for (final s in slots) {
      final start = _parseHour(s['startTime'] as String);
      final end = _parseHour(s['endTime'] as String);
      for (int h = start; h < end; h++) {
        bookedHours.add(h);
      }
    }
    return 12 - bookedHours.length;
  }

  void _showRoomDetail(RoomType room) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final slots = _slotsForRoom(room);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _RoomDetailSheet(
        room: room,
        slots: slots,
        selectedDate: _selectedDate,
        isDark: isDark,
        onBook: () {
          Navigator.pop(context);
          _showBookingForm(room);
        },
      ),
    );
  }

  void _showBookingForm(RoomType room) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BookingFormSheet(
        room: room,
        selectedDate: _selectedDate,
        isDark: isDark,
        onSubmit: (data) async {
          Navigator.pop(context);
          await _submitBooking(data);
        },
      ),
    );
  }

  Future<void> _submitBooking(Map<String, dynamic> data) async {
    try {
      await _apiService.post('/api/rooms', data);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room booking submitted successfully')),
      );

      _loadAvailability();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to book room: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _buildDateSelector(isDark),
        Expanded(child: _buildBody(isDark)),
      ],
    );
  }

  Widget _buildDateSelector(bool isDark) {
    final weekDates = _getWeekDates(_weekOffset);
    final today = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(_selectedDate),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _isSameDay(_selectedDate, today)
                    ? null
                    : () {
                        setState(() => _selectedDate = today);
                        _loadAvailability();
                      },
                icon: const Icon(Icons.today, size: 16),
                label: const Text('Today'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.3),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Week navigation with swipe
          GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                setState(() {
                  if (details.primaryVelocity! < 0) {
                    _weekOffset++;
                  } else if (details.primaryVelocity! > 0 && _weekOffset > 0) {
                    _weekOffset--;
                  }
                  // Auto-select first weekday of new week
                  final newWeek = _getWeekDates(_weekOffset);
                  final firstWeekday = newWeek.firstWhere((d) => !_isWeekend(d), orElse: () => newWeek.first);
                  _selectedDate = firstWeekday;
                });
                _loadAvailability();
              }
            },
            child: Row(
              children: [
                // Previous week arrow
                GestureDetector(
                  onTap: _weekOffset > 0 ? () {
                    setState(() {
                      _weekOffset--;
                      final newWeek = _getWeekDates(_weekOffset);
                      _selectedDate = newWeek.firstWhere((d) => !_isWeekend(d), orElse: () => newWeek.first);
                    });
                    _loadAvailability();
                  } : null,
                  child: Icon(Icons.chevron_left, size: 20, color: _weekOffset > 0 ? (isDark ? Colors.white : Colors.black) : Colors.transparent),
                ),
                ...weekDates.where((date) => !_isWeekend(date)).map((date) {
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, today);
              final isPast = date.isBefore(DateTime(today.year, today.month, today.day));
              final userRole = context.read<AuthProvider>().user?.role;
              final canAccessPast = userRole == UserRole.MANAGER || userRole == UserRole.ADMIN;
              final isDisabled = isPast && !canAccessPast;

              return Expanded(child: GestureDetector(
                onTap: isDisabled ? null : () {
                  setState(() => _selectedDate = date);
                  _loadAvailability();
                },
                child: Opacity(
                  opacity: isDisabled ? 0.3 : 1.0,
                  child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected && !isDisabled
                        ? (isDark ? Colors.white : Colors.black)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isToday && !isSelected
                        ? Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.3),
                          )
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('EEE').format(date).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white60 : Colors.black45),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : (isDark ? Colors.white : Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
                ),
              ));
            }).toList(),
                // Next week arrow
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _weekOffset++;
                      final newWeek = _getWeekDates(_weekOffset);
                      _selectedDate = newWeek.firstWhere((d) => !_isWeekend(d), orElse: () => newWeek.first);
                    });
                    _loadAvailability();
                  },
                  child: Icon(Icons.chevron_right, size: 20, color: isDark ? Colors.white : Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: isDark ? Colors.white : Colors.black,
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading rooms',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAvailability,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAvailability,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: MediaQuery.of(context).size.width > 900 ? 1.3 : 0.95,
        ),
        itemCount: RoomBooking.displayOrder.length,
        itemBuilder: (context, index) {
          final room = RoomBooking.displayOrder[index];
          return _buildRoomCard(room, isDark);
        },
      ),
    );
  }

  Widget _buildRoomCard(RoomType room, bool isDark) {
    final available = _availableHoursApproved(room);
    final slots = _slotsForRoom(room);
    final approvedCount = slots.where((s) => s['status'] == 'APPROVED').length;
    final pendingCount = slots.where((s) => s['status'] == 'PENDING').length;
    final isBusy = _isRoomBusyNow(room);
    final usage = _usagePercent(room);

    return InkWell(
      onTap: () => _showRoomDetail(room),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isBusy
                ? Colors.red.withValues(alpha: 0.6)
                : (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
            width: isBusy ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image — expands to fill available space
            Expanded(
              child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/images/paceport-saopaulo.jpg',
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  // Dark overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.6)],
                      ),
                    ),
                  ),
                  // Status badge on image
                  Positioned(
                    top: 8,
                    right: 8,
                    child: isBusy
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle, size: 6, color: Colors.white),
                                SizedBox(width: 4),
                                Text('BUSY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5)),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (available > 6 ? Colors.green : available > 0 ? Colors.orange : Colors.red).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              available == 12 ? 'Available' : '${available}h free',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                  ),
                  // Room icon + name on image
                  Positioned(
                    bottom: 8,
                    left: 10,
                    child: Row(
                      children: [
                        Icon(RoomBooking.roomIcon(room), size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          RoomBooking.roomLabel(room),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black54)]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Text(
              'Capacity: ${RoomBooking.roomCapacity(room)}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.black45,
              ),
            ),
            const SizedBox(height: 6),
            // Usage bar
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: usage,
                minHeight: 4,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  usage > 0.75
                      ? Colors.red
                      : usage > 0.5
                          ? Colors.orange
                          : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${(usage * 100).round()}% used',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const Spacer(),
                if (approvedCount > 0) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$approvedCount',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (pendingCount > 0) ...[
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$pendingCount',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white60 : Colors.black45,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ],
  ),
),
    );
  }
}

class _RoomDetailSheet extends StatelessWidget {
  final RoomType room;
  final List<Map<String, dynamic>> slots;
  final DateTime selectedDate;
  final bool isDark;
  final VoidCallback onBook;

  const _RoomDetailSheet({
    required this.room,
    required this.slots,
    required this.selectedDate,
    required this.isDark,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      RoomBooking.roomIcon(room),
                      size: 24,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            RoomBooking.roomLabel(room),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          Text(
                            'Capacity: ${RoomBooking.roomCapacity(room)} | ${DateFormat('EEE, MMM d').format(selectedDate)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: onBook,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Book'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Divider(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                height: 1,
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: _buildTimelineItems(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 30-min slot height in pixels
  static const double _slotHeight = 32.0;

  int _toMinutes(String time) {
    final p = time.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  String _fromMinutes(int m) =>
      '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

  /// Build timeline: free 30-min slots are individual, bookings span their exact duration
  List<Widget> _buildTimelineItems() {
    final sorted = List<Map<String, dynamic>>.from(slots)
      ..sort((a, b) => (a['startTime'] as String).compareTo(b['startTime'] as String));

    final items = <Widget>[];
    int cursor = 8 * 60; // 08:00 in minutes
    const endOfDay = 20 * 60;

    for (final slot in sorted) {
      final startMin = _toMinutes(slot['startTime'] as String);
      final endMin = _toMinutes(slot['endTime'] as String);

      // Free 30-min slots before this booking
      while (cursor < startMin && cursor < endOfDay) {
        items.add(_buildFreeSlot(cursor));
        cursor += 30;
      }

      // Booked block spanning exact duration
      final durationSlots = ((endMin - startMin) / 30).ceil();
      final isApproved = slot['status'] == 'APPROVED';
      items.add(_buildBookedBlock(slot, durationSlots, isApproved));
      cursor = endMin > cursor ? endMin : cursor;
      // Round up to next 30-min boundary
      if (cursor % 30 != 0) cursor = cursor + (30 - cursor % 30);
    }

    // Remaining free 30-min slots
    while (cursor < endOfDay) {
      items.add(_buildFreeSlot(cursor));
      cursor += 30;
    }

    return items;
  }

  Widget _buildFreeSlot(int minutes) {
    return Container(
      height: _slotHeight,
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              _fromMinutes(minutes),
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : Colors.black26),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A).withValues(alpha: 0.2) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookedBlock(Map<String, dynamic> slot, int durationSlots, bool isApproved) {
    final startTime = slot['startTime'] as String;
    final endTime = slot['endTime'] as String;
    final purpose = slot['purpose'] as String? ?? '';
    final bookedBy = slot['bookedByName'] as String? ?? 'Unknown';
    final blockHeight = (durationSlots * (_slotHeight + 1)).clamp(34.0, 600.0);
    return Container(
      height: blockHeight,
      margin: const EdgeInsets.only(bottom: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 50,
            child: Text(startTime, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isApproved ? Colors.green : Colors.orange)),
          ),
          Expanded(
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () => _showBookingDetail(context, slot),
                child: Container(
                  decoration: BoxDecoration(
                    color: isApproved ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isApproved ? Colors.green.withValues(alpha: 0.35) : Colors.orange.withValues(alpha: 0.35)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(isApproved ? Icons.check_circle : Icons.schedule, size: 12, color: isApproved ? Colors.green : Colors.orange),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text('$startTime – $endTime', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: isApproved ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(isApproved ? 'Confirmed' : 'Pending', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: isApproved ? Colors.green : Colors.orange)),
                          ),
                        ],
                      ),
                      if (purpose.isNotEmpty && durationSlots >= 2) ...[
                        const SizedBox(height: 2),
                        Text(purpose, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                      if (durationSlots >= 2)
                        Text(bookedBy, style: TextStyle(fontSize: 9, color: isDark ? Colors.white30 : Colors.black26)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingDetail(BuildContext context, Map<String, dynamic> slot) {
    final startTime = slot['startTime'] as String? ?? '';
    final endTime = slot['endTime'] as String? ?? '';
    final purpose = slot['purpose'] as String? ?? '';
    final bookedBy = slot['bookedByName'] as String? ?? 'Unknown';
    final status = slot['status'] as String? ?? 'PENDING';

    final isApproved = status == 'APPROVED';
    final isPending = status == 'PENDING';
    final statusColor = isApproved
        ? Colors.green
        : isPending
            ? Colors.orange
            : Colors.red;
    final statusLabel = isApproved
        ? 'Approved'
        : isPending
            ? 'Pending'
            : 'Rejected';

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  RoomBooking.roomIcon(room),
                  size: 22,
                  color: isDark ? Colors.white : Colors.black,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    RoomBooking.roomLabel(room),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow(Icons.calendar_today, 'Date', DateFormat('EEE, MMM d, yyyy').format(selectedDate)),
            const SizedBox(height: 12),
            _detailRow(Icons.access_time, 'Time', '$startTime - $endTime'),
            const SizedBox(height: 12),
            _detailRow(Icons.subject, 'Purpose', purpose.isNotEmpty ? purpose : '-'),
            const SizedBox(height: 12),
            _detailRow(Icons.person_outline, 'Booked by', bookedBy),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: isDark ? Colors.white38 : Colors.black38),
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
      ],
    );
  }
}

class _BookingFormSheet extends StatefulWidget {
  final RoomType room;
  final DateTime selectedDate;
  final bool isDark;
  final Future<void> Function(Map<String, dynamic> data) onSubmit;

  const _BookingFormSheet({
    required this.room,
    required this.selectedDate,
    required this.isDark,
    required this.onSubmit,
  });

  @override
  State<_BookingFormSheet> createState() => _BookingFormSheetState();
}

class _BookingFormSheetState extends State<_BookingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  final _attendeesController = TextEditingController(text: '1');

  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String? _selectedVertical;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // If today, start from next 30-min slot; otherwise 09:00
    final now = TimeOfDay.now();
    final isToday = widget.selectedDate.year == DateTime.now().year &&
        widget.selectedDate.month == DateTime.now().month &&
        widget.selectedDate.day == DateTime.now().day;
    if (isToday) {
      // Round up to next 30-min slot
      final mins = now.hour * 60 + now.minute;
      final nextSlot = ((mins / 30).ceil()) * 30;
      final startMins = nextSlot < 8 * 60 ? 8 * 60 : (nextSlot >= 19 * 60 + 30 ? 19 * 60 + 30 : nextSlot);
      _startTime = TimeOfDay(hour: startMins ~/ 60, minute: startMins % 60);
      final endMins = startMins + 30;
      _endTime = TimeOfDay(hour: endMins ~/ 60, minute: endMins % 60);
    } else {
      _startTime = const TimeOfDay(hour: 9, minute: 0);
      _endTime = const TimeOfDay(hour: 10, minute: 0);
    }
  }

  final List<String> _verticals = [
    'BFSI',
    'RETAIL_CPG',
    'LIFE_SCIENCES_HEALTHCARE',
    'MANUFACTURING',
    'HI_TECH',
    'CMT',
    'ERU',
    'TRAVEL_HOSPITALITY',
    'PUBLIC_SERVICES',
    'BUSINESS_SERVICES',
  ];

  @override
  void dispose() {
    _purposeController.dispose();
    _attendeesController.dispose();
    super.dispose();
  }

  void _pickTime(bool isStart) {
    final isDark = widget.isDark;
    final currentValue = isStart ? _startTime : _endTime;

    // Build available hours and minutes
    final now = DateTime.now();
    final isToday = widget.selectedDate.year == now.year &&
        widget.selectedDate.month == now.month &&
        widget.selectedDate.day == now.day;
    final nowMins = now.hour * 60 + now.minute;

    // Min time: for start=08:00 (or now if today), for end=startTime+30min
    int minMinutes = isStart ? 8 * 60 : (_startTime.hour * 60 + _startTime.minute + 30);
    if (isToday && isStart) {
      final nextSlot = ((nowMins / 30).ceil()) * 30;
      if (nextSlot > minMinutes) minMinutes = nextSlot;
    }
    final maxMinutes = isStart ? 20 * 60 : 21 * 60;

    // Scroll wheel with hours and minutes
    int selectedHour = currentValue.hour;
    int selectedMinute = currentValue.minute;

    // If no valid slots available (e.g. too late today), show message
    if (minMinutes >= maxMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available time slots for this date')),
      );
      return;
    }

    // Clamp to valid range
    final currentMins = selectedHour * 60 + selectedMinute;
    if (currentMins < minMinutes) {
      selectedHour = minMinutes ~/ 60;
      selectedMinute = minMinutes % 60;
    }
    if (currentMins > maxMinutes) {
      selectedHour = maxMinutes ~/ 60;
      selectedMinute = maxMinutes % 60;
    }

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: 300,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Text(
                      isStart ? 'Start Time' : 'End Time',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        final picked = TimeOfDay(hour: selectedHour, minute: selectedMinute);
                        setState(() {
                          if (isStart) {
                            _startTime = picked;
                            final sMin = picked.hour * 60 + picked.minute;
                            final eMin = _endTime.hour * 60 + _endTime.minute;
                            if (eMin <= sMin) {
                              final ne = sMin + 30;
                              _endTime = TimeOfDay(hour: ne ~/ 60, minute: ne % 60);
                            }
                          } else {
                            _endTime = picked;
                          }
                        });
                        Navigator.pop(ctx);
                      },
                      child: Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (ctx) {
                    // Build filtered hour list
                    final minH = minMinutes ~/ 60;
                    final maxH = maxMinutes ~/ 60;
                    final hours = List.generate(maxH - minH + 1, (i) => minH + i);
                    final hourIndex = hours.indexOf(selectedHour).clamp(0, hours.length - 1);

                    return Row(
                      children: [
                        const SizedBox(width: 40),
                        // Hour picker (only available hours)
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(initialItem: hourIndex),
                            itemExtent: 40,
                            onSelectedItemChanged: (index) {
                              setSheetState(() => selectedHour = hours[index]);
                            },
                            children: hours.map((h) => Center(
                              child: Text(
                                h.toString().padLeft(2, '0'),
                                style: TextStyle(fontSize: 22, color: isDark ? Colors.white : Colors.black),
                              ),
                            )).toList(),
                          ),
                        ),
                        Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.black54)),
                        // Minute picker (00 and 30)
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(initialItem: selectedMinute == 30 ? 1 : 0),
                            itemExtent: 40,
                            onSelectedItemChanged: (index) {
                              setSheetState(() => selectedMinute = index == 0 ? 0 : 30);
                            },
                            children: const [
                              Center(child: Text('00', style: TextStyle(fontSize: 22))),
                              Center(child: Text('30', style: TextStyle(fontSize: 22))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 40),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;
    if (startMin >= endMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    // Block past times if booking today
    final now = DateTime.now();
    final isToday = widget.selectedDate.year == now.year &&
        widget.selectedDate.month == now.month &&
        widget.selectedDate.day == now.day;
    if (isToday && startMin <= now.hour * 60 + now.minute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot book a time in the past')),
      );
      return;
    }

    final attendees = int.tryParse(_attendeesController.text) ?? 1;
    if (attendees > RoomBooking.roomCapacity(widget.room)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Attendees exceeds room capacity of ${RoomBooking.roomCapacity(widget.room)}'),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    await widget.onSubmit({
      'room': widget.room.name,
      'date': DateFormat('yyyy-MM-dd').format(widget.selectedDate),
      'startTime': _formatTime(_startTime),
      'endTime': _formatTime(_endTime),
      'purpose': _purposeController.text.trim(),
      'attendees': attendees,
      if (_selectedVertical != null && _selectedVertical!.isNotEmpty) 'vertical': _selectedVertical,
    });

    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF27272A)
                            : const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Book ${RoomBooking.roomLabel(widget.room)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(widget.selectedDate),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Time pickers
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeField(
                          'Start Time',
                          _startTime,
                          () => _pickTime(true),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTimeField(
                          'End Time',
                          _endTime,
                          () => _pickTime(false),
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Purpose
                  Text(
                    'Purpose',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _purposeController,
                    maxLines: 2,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'What is the meeting about?',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Attendees
                  Text(
                    'Number of Attendees',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _attendeesController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Max: ${RoomBooking.roomCapacity(widget.room)}',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final n = int.tryParse(v);
                      if (n == null || n < 1) return 'Must be at least 1';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Vertical (optional)
                  Text(
                    'Vertical (optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedVertical,
                    dropdownColor:
                        isDark ? const Color(0xFF18181B) : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Select vertical',
                    ),
                    items: _verticals
                        .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(v.replaceAll('_', ' ')),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedVertical = v),
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _submitting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit Booking',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeField(
    String label,
    TimeOfDay time,
    VoidCallback onTap,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF09090B) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF27272A)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 18,
                  color: isDark ? Colors.white60 : Colors.black45,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(time),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
