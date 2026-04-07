import 'package:flutter/material.dart';

/// Drawer 1: Select Engagement Type (Pace Visit, Innovation Exchange, or Hackathon)
class EngagementTypeDrawer extends StatefulWidget {
  final Function(String engagementType) onNext;
  final DateTime? selectedDate;

  const EngagementTypeDrawer({
    super.key,
    required this.onNext,
    this.selectedDate,
  });

  @override
  State<EngagementTypeDrawer> createState() => _EngagementTypeDrawerState();
}

class _EngagementTypeDrawerState extends State<EngagementTypeDrawer> {
  String? _selectedEngagementType;

  static const _prepRequiredTypes = {'INNOVATION_EXCHANGE', 'HACKATHON'};
  static const int _requiredPrepBusinessDays = 3;

  /// Count business days between [from] and [to] (exclusive of both endpoints).
  int _businessDaysBetween(DateTime from, DateTime to) {
    int count = 0;
    DateTime day = DateTime(from.year, from.month, from.day).add(const Duration(days: 1));
    final target = DateTime(to.year, to.month, to.day);
    while (day.isBefore(target)) {
      if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
        count++;
      }
      day = day.add(const Duration(days: 1));
    }
    return count;
  }

  /// Add [n] business days to [from], skipping weekends.
  DateTime _addBusinessDays(DateTime from, int n) {
    DateTime day = DateTime(from.year, from.month, from.day);
    int added = 0;
    while (added < n) {
      day = day.add(const Duration(days: 1));
      if (day.weekday != DateTime.saturday && day.weekday != DateTime.sunday) {
        added++;
      }
    }
    return day;
  }

  bool _isGreyedOut(String value) {
    if (!_prepRequiredTypes.contains(value)) return false;
    if (widget.selectedDate == null) return false;
    final today = DateTime.now();
    return _businessDaysBetween(today, widget.selectedDate!) < _requiredPrepBusinessDays;
  }

  String _nextAvailableDateLabel() {
    final next = _addBusinessDays(DateTime.now(), _requiredPrepBusinessDays);
    return '${next.day.toString().padLeft(2, '0')}/${next.month.toString().padLeft(2, '0')}/${next.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF18181B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[700] : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                  tooltip: 'Close',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select Engagement Type',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose the type of engagement',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildEngagementCard(
                    'PACE_VISIT',
                    'Pace Visit',
                    'Quick tour or full-day experience',
                    Icons.tour,
                    isDark,
                  ),
                  const SizedBox(height: 16),

                  _buildEngagementCard(
                    'INNOVATION_EXCHANGE',
                    'Innovation Exchange',
                    'Multi-day innovation session with 5 weeks preparation',
                    Icons.lightbulb_outline,
                    isDark,
                  ),
                  const SizedBox(height: 16),

                  _buildEngagementCard(
                    'HACKATHON',
                    'Hackathon',
                    'Multi-day collaborative hackathon event',
                    Icons.code,
                    isDark,
                  ),
                ],
              ),
            ),
          ),

          // Next button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: ElevatedButton(
              onPressed: _selectedEngagementType != null
                  ? () {
                      widget.onNext(_selectedEngagementType!);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Next',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementCard(
    String value,
    String title,
    String subtitle,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _selectedEngagementType == value;
    final greyedOut = _isGreyedOut(value);

    return Opacity(
      opacity: greyedOut ? 0.4 : 1.0,
      child: InkWell(
        onTap: greyedOut
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Requires $_requiredPrepBusinessDays prep days. Next available: ${_nextAvailableDateLabel()}',
                    ),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            : () {
                setState(() {
                  _selectedEngagementType = value;
                });
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected && !greyedOut
                ? (isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB))
                : (isDark ? const Color(0xFF0A0A0B) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected && !greyedOut
                  ? Colors.black
                  : (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
              width: isSelected && !greyedOut ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected && !greyedOut
                      ? Colors.black
                      : (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: isSelected && !greyedOut
                      ? Colors.white
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    if (greyedOut) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Requires $_requiredPrepBusinessDays prep days. Next available: ${_nextAvailableDateLabel()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected && !greyedOut)
                const Icon(Icons.check_circle, color: Colors.black, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
