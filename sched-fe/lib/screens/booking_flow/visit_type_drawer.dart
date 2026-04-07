import 'package:flutter/material.dart';

/// Drawer 2 (Conditional): Select Visit Type - only shown if engagement type is PACE_VISIT
class VisitTypeDrawer extends StatefulWidget {
  final Function(String visitType) onNext;
  final VoidCallback onBack;

  const VisitTypeDrawer({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<VisitTypeDrawer> createState() => _VisitTypeDrawerState();
}

class _VisitTypeDrawerState extends State<VisitTypeDrawer> {
  String? _selectedVisitType;

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
                  onPressed: widget.onBack,
                  icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Select Visit Type',
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
                    'Choose the type of visit experience',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildVisitTypeCard(
                    'PACE_TOUR',
                    'Pace Tour',
                    '2 hours (14h-16h)',
                    'Quick demonstration and overview',
                    Icons.schedule,
                    isDark,
                  ),
                  const SizedBox(height: 16),

                  _buildVisitTypeCard(
                    'PACE_VISIT_FULLDAY',
                    'Pace Visit Fullday',
                    'Up to 8 hours',
                    'Full-day immersive experience with questionnaire',
                    Icons.event,
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
              onPressed: _selectedVisitType != null
                  ? () {
                      widget.onNext(_selectedVisitType!);
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

  Widget _buildVisitTypeCard(
    String value,
    String title,
    String duration,
    String description,
    IconData icon,
    bool isDark,
  ) {
    final isSelected = _selectedVisitType == value;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedVisitType = value;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF27272A) : const Color(0xFFF9FAFB))
              : (isDark ? const Color(0xFF0A0A0B) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.black
                : (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.black
                    : (isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[600]),
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
                    duration,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.black, size: 24),
          ],
        ),
      ),
    );
  }
}
