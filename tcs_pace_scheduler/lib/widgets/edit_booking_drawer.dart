import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../widgets/booking_form_fields.dart';
import '../utils/toast_notification.dart';

/// Drawer for editing booking details when status is NEED_EDIT
/// Shows multi-step form: Step 3 (Base Information) → Step 4 (Questionnaire if applicable)
class EditBookingDrawer extends StatefulWidget {
  final Booking booking;
  final VoidCallback onClose;
  final VoidCallback onSuccess;

  const EditBookingDrawer({
    super.key,
    required this.booking,
    required this.onClose,
    required this.onSuccess,
  });

  @override
  State<EditBookingDrawer> createState() => _EditBookingDrawerState();
}

class _EditBookingDrawerState extends State<EditBookingDrawer> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  int _currentStep = 3; // Start at Step 3 (Base Information)
  bool _submitting = false;

  // Step 1 & 2 data (read-only from existing booking)
  String? _engagementType;
  String? _visitType;

  // Step 3: Base Information
  final _requesterNameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  String? _vertical;
  final _organizationNameController = TextEditingController();
  String? _organizationType;
  final _organizationTypeOtherController = TextEditingController();
  final _organizationDescriptionController = TextEditingController();
  final _objectiveInterestController = TextEditingController();
  List<String> _targetAudience = [];

  // Attendees (optional)
  List<AttendeeFormData> _attendees = [];

  // Step 4: Questionnaire
  final _questionnaireAnswers = <String, String>{
    'q1': '',
    'q2': '',
    'q3': '',
    'q4': '',
    'q5': '',
  };

  @override
  void initState() {
    super.initState();
    _prefillFromBooking();
  }

  void _prefillFromBooking() {
    final booking = widget.booking;

    setState(() {
      // Step 1 & 2: Read-only
      _engagementType = booking.engagementType?.name ??
          (booking.visitType == VisitType.INNOVATION_EXCHANGE ? 'INNOVATION_EXCHANGE' : 'VISIT');
      _visitType = booking.visitType.name;

      // Step 3: Base Information
      _requesterNameController.text = booking.requesterName ?? '';
      _employeeIdController.text = booking.employeeId ?? '';
      _vertical = booking.vertical?.name;
      _organizationNameController.text = booking.organizationName ?? booking.companyName;
      _organizationType = booking.organizationType?.name;
      _organizationTypeOtherController.text = booking.organizationTypeOther ?? '';
      _organizationDescriptionController.text = booking.organizationDescription ?? '';
      _objectiveInterestController.text = booking.objectiveInterest ?? '';
      _targetAudience = booking.targetAudience?.map((a) => a.name).toList() ?? [];

      // Attendees
      if (booking.attendees != null && booking.attendees!.isNotEmpty) {
        _attendees = booking.attendees!.map((a) => AttendeeFormData.fromAttendee(a)).toList();
      }

      // Step 4: Questionnaire
      if (booking.questionnaireAnswers != null) {
        booking.questionnaireAnswers!.forEach((key, value) {
          if (_questionnaireAnswers.containsKey(key)) {
            _questionnaireAnswers[key] = value.toString();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _requesterNameController.dispose();
    _employeeIdController.dispose();
    _organizationNameController.dispose();
    _organizationTypeOtherController.dispose();
    _organizationDescriptionController.dispose();
    _objectiveInterestController.dispose();
    for (var attendee in _attendees) {
      attendee.dispose();
    }
    super.dispose();
  }

  bool _requiresQuestionnaire() {
    if (_engagementType == 'INNOVATION_EXCHANGE') return true;
    if (_engagementType == 'VISIT' && _visitType == 'PACE_EXPERIENCE') return true;
    return false;
  }

  String _durationToEnum(int hours) {
    switch (hours) {
      case 1:
        return 'ONE_HOUR';
      case 2:
        return 'TWO_HOURS';
      case 3:
        return 'THREE_HOURS';
      case 4:
        return 'FOUR_HOURS';
      case 5:
        return 'FIVE_HOURS';
      case 6:
        return 'SIX_HOURS';
      case 7:
        return 'SEVEN_HOURS';
      default:
        return 'TWO_HOURS';
    }
  }

  Map<String, dynamic> _buildUpdateData() {
    final updateData = {
      // Base Information
      'requesterName': _requesterNameController.text.trim(),
      'employeeId': _employeeIdController.text.trim(),
      'vertical': _vertical,
      'organizationName': _organizationNameController.text.trim(),
      'organizationType': _organizationType,
      if (_organizationType == 'OTHER')
        'organizationTypeOther': _organizationTypeOtherController.text.trim(),
      if (_organizationDescriptionController.text.trim().isNotEmpty)
        'organizationDescription': _organizationDescriptionController.text.trim(),
      if (_objectiveInterestController.text.trim().isNotEmpty)
        'objectiveInterest': _objectiveInterestController.text.trim(),
      'targetAudience': _targetAudience,

      // Questionnaire (if applicable)
      if (_requiresQuestionnaire())
        'questionnaireAnswers': _questionnaireAnswers,

      // Attendees
      if (_attendees.isNotEmpty)
        'attendees': _attendees.map((a) => a.toJson()).toList(),
      'expectedAttendees': _attendees.isNotEmpty ? _attendees.length : 1,

      // Status change: After editing a NEED_EDIT booking, return to UNDER_REVIEW for manager approval
      'status': 'UNDER_REVIEW',

      // Legacy compatibility
      'companyName': _organizationNameController.text.trim(),
      'accountName': _organizationNameController.text.trim(),
    };

    return updateData;
  }

  Future<void> _handleNext() async {
    if (_currentStep == 3) {
      // Validate base information
      if (!_formKey.currentState!.validate()) {
        ToastNotification.show(
          context,
          message: 'Please fill in all required fields',
          type: ToastType.error,
        );
        return;
      }

      // If requires questionnaire, go to step 4
      if (_requiresQuestionnaire()) {
        setState(() => _currentStep = 4);
      } else {
        // Otherwise, submit directly
        await _submitUpdate();
      }
    } else if (_currentStep == 4) {
      // Validate questionnaire
      bool allAnswered = _questionnaireAnswers.values.every((answer) => answer.trim().isNotEmpty);
      if (!allAnswered) {
        ToastNotification.show(
          context,
          message: 'Please answer all questions',
          type: ToastType.error,
        );
        return;
      }
      await _submitUpdate();
    }
  }

  Future<void> _submitUpdate() async {
    setState(() => _submitting = true);

    try {
      final updateData = _buildUpdateData();
      await _apiService.updateBooking(widget.booking.id, updateData);

      if (mounted) {
        ToastNotification.show(
          context,
          message: 'Booking updated successfully! Status changed to Under Review.',
          type: ToastType.success,
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ToastNotification.show(
          context,
          message: 'Error updating booking: $e',
          type: ToastType.error,
        );
      }
    }
  }

  void _handleBack() {
    if (_currentStep == 4) {
      setState(() => _currentStep = 3);
    }
  }

  // Attendee management
  void _addAttendee() {
    setState(() {
      if (_attendees.length < 10) {
        _attendees.add(AttendeeFormData());
      }
    });
  }

  void _removeAttendee(int index) {
    setState(() {
      _attendees[index].dispose();
      _attendees.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(isDark),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: _currentStep == 3
                    ? _buildStep3BaseInfo(isDark)
                    : _buildStep4Questionnaire(isDark),
              ),
            ),
          ),

          // Footer with navigation buttons
          _buildFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
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
              IconButton(
                onPressed: widget.onClose,
                icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentStep == 3 ? 'Edit Base Information' : 'Edit Questionnaire',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentStep == 3
                          ? 'Update organization and requester details'
                          : 'Update questionnaire answers',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date/Time info (read-only)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(widget.booking.date),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  widget.booking.startTime,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.lock_outline,
                  size: 14,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3BaseInfo(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Requester Name
        TextFormField(
          controller: _requesterNameController,
          decoration: InputDecoration(
            labelText: 'Your Name',
            hintText: 'Enter your full name',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Employee ID
        TextFormField(
          controller: _employeeIdController,
          decoration: InputDecoration(
            labelText: 'Employee ID',
            hintText: 'Enter your TCS employee ID',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.badge),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Employee ID is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Vertical
        DropdownButtonFormField<String>(
          value: _vertical,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'TCS Vertical',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.business_center),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          items: const [
            DropdownMenuItem(
              value: 'BFSI',
              child: Text('BFSI (Banking, Financial Services & Insurance)', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'RETAIL_CPG',
              child: Text('Retail & CPG', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'LIFE_SCIENCES_HEALTHCARE',
              child: Text('Life Sciences & Healthcare', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'MANUFACTURING',
              child: Text('Manufacturing', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'HI_TECH',
              child: Text('Hi-Tech', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'CMT',
              child: Text('CMT (Communications, Media & Technology)', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'ERU',
              child: Text('ERU (Energy, Resources & Utilities)', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'TRAVEL_HOSPITALITY',
              child: Text('Travel & Hospitality', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'PUBLIC_SERVICES',
              child: Text('Public Services', overflow: TextOverflow.ellipsis),
            ),
            DropdownMenuItem(
              value: 'BUSINESS_SERVICES',
              child: Text('Business Services', overflow: TextOverflow.ellipsis),
            ),
          ],
          validator: (value) {
            if (value == null) {
              return 'Please select a vertical';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {
              _vertical = value;
            });
          },
        ),
        const SizedBox(height: 16),

        // Organization Name
        TextFormField(
          controller: _organizationNameController,
          decoration: InputDecoration(
            labelText: 'Organization Name',
            hintText: 'Enter the organization/company name',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.business),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Organization name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Organization Type
        DropdownButtonFormField<String>(
          value: _organizationType,
          decoration: InputDecoration(
            labelText: 'Organization Type',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.category),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          items: const [
            DropdownMenuItem(value: 'EXISTING_CUSTOMER', child: Text('Existing Customer')),
            DropdownMenuItem(value: 'PROSPECT', child: Text('Prospect')),
            DropdownMenuItem(value: 'PARTNER', child: Text('Partner')),
            DropdownMenuItem(value: 'GOVERNMENTAL_INSTITUTION', child: Text('Governmental Institution')),
            DropdownMenuItem(value: 'OTHER', child: Text('Other')),
          ],
          validator: (value) {
            if (value == null) {
              return 'Please select organization type';
            }
            return null;
          },
          onChanged: (value) {
            setState(() {
              _organizationType = value;
            });
          },
        ),
        const SizedBox(height: 16),

        // Organization Type Other (conditional)
        if (_organizationType == 'OTHER') ...[
          TextFormField(
            controller: _organizationTypeOtherController,
            decoration: InputDecoration(
              labelText: 'Specify Organization Type',
              hintText: 'Please specify the type',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.edit),
              filled: true,
              fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
            ),
            validator: (value) {
              if (_organizationType == 'OTHER' && (value == null || value.trim().isEmpty)) {
                return 'Please specify organization type';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
        ],

        // Organization Description
        TextFormField(
          controller: _organizationDescriptionController,
          decoration: InputDecoration(
            labelText: 'Organization Description (optional)',
            hintText: 'Brief description of the organization',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Objective/Interest
        TextFormField(
          controller: _objectiveInterestController,
          decoration: InputDecoration(
            labelText: 'Objective / Interest in Pace (optional)',
            hintText: 'What do you hope to learn or achieve?',
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // Target Audience (Multi-select)
        _buildTargetAudienceMultiSelect(isDark),
        const SizedBox(height: 24),

        // Attendees Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attendees (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            if (_attendees.length < 10)
              TextButton.icon(
                onPressed: _addAttendee,
                icon: Icon(Icons.add, color: isDark ? Colors.white : Colors.black, size: 18),
                label: Text(
                  'Add Attendee',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Add information about attendees for this visit (optional)',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),

        // Attendees List
        if (_attendees.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _attendees.length,
            itemBuilder: (context, index) {
              return AttendeeCard(
                attendee: _attendees[index],
                index: index,
                onRemove: () => _removeAttendee(index),
                onUpdate: setState,
                enabled: true,
                initiallyExpanded: index == _attendees.length - 1,
              );
            },
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people_outline,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'No attendees added yet. Click "Add Attendee" to add visitor information.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTargetAudienceMultiSelect(bool isDark) {
    const availableOptions = [
      'C-Level',
      'Technology Leaders',
      'Business Leaders',
      'Innovation Team',
      'Technical Team',
    ];

    return InkWell(
      onTap: () async {
        final selectedItems = List<String>.from(_targetAudience);

        await showDialog(
          context: context,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
                  title: Text(
                    'Select Target Audience',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: availableOptions.map((option) {
                        final isSelected = selectedItems.contains(option);
                        return CheckboxListTile(
                          title: Text(
                            option,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          value: isSelected,
                          activeColor: Colors.black,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedItems.add(option);
                              } else {
                                selectedItems.remove(option);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _targetAudience = selectedItems;
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Confirm'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Target Audience',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.groups),
          filled: true,
          fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: _targetAudience.isEmpty
            ? Text(
                'Select target audience',
                style: TextStyle(
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _targetAudience.map((audience) {
                  return Chip(
                    label: Text(
                      audience,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    backgroundColor: isDark ? const Color(0xFF27272A) : const Color(0xFFF3F4F6),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    onDeleted: () {
                      setState(() {
                        _targetAudience.remove(audience);
                      });
                    },
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildStep4Questionnaire(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF18181B) : const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF27272A) : const Color(0xFFBAE6FD),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: isDark ? Colors.blue[300] : Colors.blue[700],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Update your questionnaire answers to help us prepare a tailored experience.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.blue[200] : Colors.blue[900],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildQuestionField(
          'q1',
          '1. What are the main technology areas you want to explore?',
          isDark,
        ),
        const SizedBox(height: 20),

        _buildQuestionField(
          'q2',
          '2. What are your key business challenges or focus areas?',
          isDark,
        ),
        const SizedBox(height: 20),

        _buildQuestionField(
          'q3',
          '3. Who will be attending and what are their roles?',
          isDark,
        ),
        const SizedBox(height: 20),

        _buildQuestionField(
          'q4',
          '4. What specific problems are you looking to solve?',
          isDark,
        ),
        const SizedBox(height: 20),

        _buildQuestionField(
          'q5',
          '5. What do you hope to take away from this session?',
          isDark,
        ),
      ],
    );
  }

  Widget _buildQuestionField(String key, String question, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: _questionnaireAnswers[key],
          decoration: InputDecoration(
            hintText: 'Your answer...',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          maxLines: 3,
          onChanged: (value) {
            _questionnaireAnswers[key] = value;
          },
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button (only show in step 4)
          if (_currentStep == 4) ...[
            Expanded(
              flex: 2,
              child: OutlinedButton(
                onPressed: _submitting ? null : _handleBack,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  side: BorderSide(
                    color: isDark ? const Color(0xFF27272A) : const Color(0xFFE5E7EB),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Next/Update button
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: _submitting ? null : _handleNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: Colors.grey[400],
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _currentStep == 3 && _requiresQuestionnaire()
                              ? Icons.arrow_forward
                              : Icons.check_circle,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _currentStep == 3 && _requiresQuestionnaire()
                              ? 'Next'
                              : 'Update Booking',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
