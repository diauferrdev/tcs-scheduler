import 'package:flutter/material.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../widgets/pending_approval_card.dart';
import '../widgets/reschedule_dialog.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  final ApiService _apiService = ApiService();
  List<Booking> _pendingBookings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPendingBookings();
  }

  Future<void> _loadPendingBookings() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final response = await _apiService.getBookings(status: 'PENDING_APPROVAL');
      final bookingsData = (response['bookings'] as List?) ?? [];

      setState(() {
        _pendingBookings = bookingsData
            .map((e) => Booking.fromJson(e))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date)); // Sort by date
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showRescheduleDialog(Booking booking) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RescheduleDialog(
        booking: booking,
        onRescheduled: _loadPendingBookings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? Colors.black : const Color(0xFFF9FAFB),
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pending Approvals',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Review and approve requests',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Count badge
                  if (!_loading && _pendingBookings.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF59E0B),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.pending_actions,
                            color: Color(0xFFF59E0B),
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_pendingBookings.length}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 32),

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
                        onPressed: _loadPendingBookings,
                        icon: const Icon(Icons.refresh, color: Colors.red),
                        tooltip: 'Retry',
                      ),
                    ],
                  ),
                ),

              // Loading state
              if (_loading)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      children: [
                        CircularProgressIndicator(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading pending bookings...',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                )

              // Empty state
              else if (_pendingBookings.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 80,
                          color: isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'All Clear!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No bookings pending approval',
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton.icon(
                          onPressed: _loadPendingBookings,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ),
                )

              // List of pending bookings
              else
                Column(
                  children: _pendingBookings.map((booking) {
                    return PendingApprovalCard(
                      booking: booking,
                      onApproved: _loadPendingBookings,
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
    );
  }
}
