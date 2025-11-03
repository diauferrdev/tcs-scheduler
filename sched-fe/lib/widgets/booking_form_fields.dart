// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';

/// Data class to hold all booking form state
class BookingFormData {
  // Visit Type & Duration
  String visitType;
  int? selectedDuration;

  // Section 1: Account & Company Information
  final TextEditingController accountNameController;
  final TextEditingController companyNameController;
  String? companySector;
  String? companyVertical;
  String? companySize;

  // Section 2: Visit Details
  final TextEditingController venueController;
  final TextEditingController overallThemeController;
  DateTime? lastInnovationDay;

  // Section 3: Event Type & Deal Information
  String eventType;
  final TextEditingController partnerNameController;
  String dealStatus;
  bool attachHeadApproval;
  List<String>? attachments;

  // Section 4: Attendees
  List<AttendeeFormData> attendees;

  // Section 5: Additional Notes
  final TextEditingController additionalNotesController;

  BookingFormData({
    this.visitType = 'INNOVATION_EXCHANGE',
    this.selectedDuration,
    TextEditingController? accountNameController,
    TextEditingController? companyNameController,
    this.companySector,
    this.companyVertical,
    this.companySize,
    TextEditingController? venueController,
    TextEditingController? overallThemeController,
    this.lastInnovationDay,
    this.eventType = 'TCS',
    TextEditingController? partnerNameController,
    this.dealStatus = 'SWON',
    this.attachHeadApproval = false,
    this.attachments,
    List<AttendeeFormData>? attendees,
    TextEditingController? additionalNotesController,
  })  : accountNameController = accountNameController ?? TextEditingController(),
        companyNameController = companyNameController ?? TextEditingController(),
        venueController = venueController ?? TextEditingController(),
        overallThemeController = overallThemeController ?? TextEditingController(),
        partnerNameController = partnerNameController ?? TextEditingController(),
        additionalNotesController = additionalNotesController ?? TextEditingController(),
        attendees = attendees ?? [AttendeeFormData()];

  void dispose() {
    accountNameController.dispose();
    companyNameController.dispose();
    venueController.dispose();
    overallThemeController.dispose();
    partnerNameController.dispose();
    additionalNotesController.dispose();
    for (var attendee in attendees) {
      attendee.dispose();
    }
  }

  /// Load data from an existing Booking
  factory BookingFormData.fromBooking(Booking booking) {
    final formData = BookingFormData(
      visitType: booking.visitType.name,
      selectedDuration: _durationToInt(booking.duration.name),
      accountNameController: TextEditingController(text: booking.accountName),
      companyNameController: TextEditingController(text: booking.companyName),
      companySector: booking.companySector,
      companyVertical: booking.companyVertical,
      companySize: booking.companySize,
      venueController: TextEditingController(text: booking.venue ?? ''),
      overallThemeController: TextEditingController(text: booking.overallTheme ?? ''),
      lastInnovationDay: booking.lastInnovationDay,
      eventType: booking.eventType?.name ?? 'TCS',
      partnerNameController: TextEditingController(text: booking.partnerName ?? ''),
      dealStatus: booking.dealStatus?.name ?? 'SWON',
      attachHeadApproval: booking.attachHeadApproval,
      attachments: booking.attachments,
      attendees: booking.attendees?.map((a) => AttendeeFormData.fromAttendee(a)).toList() ?? [AttendeeFormData()],
      additionalNotesController: TextEditingController(text: booking.additionalNotes ?? ''),
    );
    return formData;
  }

  static int _durationToInt(String duration) {
    switch (duration) {
      case 'ONE_HOUR':
        return 1;
      case 'TWO_HOURS':
        return 2;
      case 'THREE_HOURS':
        return 3;
      case 'FOUR_HOURS':
        return 4;
      case 'FIVE_HOURS':
        return 5;
      case 'SIX_HOURS':
        return 6;
      default:
        return 4;
    }
  }

  int getFinalDuration() {
    if (visitType == 'PACE_TOUR') {
      return 2;
    } else if (visitType == 'PACE_EXPERIENCE') {
      return 4;
    } else {
      return selectedDuration ?? 6;
    }
  }

  String durationToEnum(int hours) {
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
      default:
        return 'FOUR_HOURS';
    }
  }

  /// Convert form data to JSON for API submission
  Map<String, dynamic> toJson(String date, String startTime) {
    return {
      'accountName': accountNameController.text.trim(),
      'companyName': companyNameController.text.trim(),
      'companySector': companySector,
      'companyVertical': companyVertical,
      'companySize': companySize,
      'date': date,
      'startTime': startTime,
      'duration': durationToEnum(getFinalDuration()),
      'visitType': visitType,
      'venue': venueController.text.trim().isNotEmpty ? venueController.text.trim() : null,
      'expectedAttendees': attendees.length,
      'overallTheme': overallThemeController.text.trim().isNotEmpty ? overallThemeController.text.trim() : null,
      'lastInnovationDay': lastInnovationDay != null ? DateFormat('yyyy-MM-dd').format(lastInnovationDay!) : null,
      'eventType': eventType,
      if (eventType == 'PARTNER' && partnerNameController.text.trim().isNotEmpty) 'partnerName': partnerNameController.text.trim(),
      'dealStatus': dealStatus,
      'attachHeadApproval': attachHeadApproval,
      if (attachments != null) 'attachments': attachments,
      'attendees': attendees.map((a) => a.toJson()).toList(),
      'additionalNotes': additionalNotesController.text.trim().isNotEmpty ? additionalNotesController.text.trim() : null,
    };
  }
}

/// Data class to hold attendee form state
class AttendeeFormData {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController roleController;
  final TextEditingController positionController;
  String tcsSupporter;
  final TextEditingController understandingController;
  final TextEditingController focusAreasController;
  final TextEditingController yearsWithTcsController;
  final TextEditingController educationController;
  final TextEditingController careerBackgroundController;
  final TextEditingController linkedinController;

  AttendeeFormData({
    TextEditingController? nameController,
    TextEditingController? emailController,
    TextEditingController? roleController,
    TextEditingController? positionController,
    this.tcsSupporter = 'NEUTRAL',
    TextEditingController? understandingController,
    TextEditingController? focusAreasController,
    TextEditingController? yearsWithTcsController,
    TextEditingController? educationController,
    TextEditingController? careerBackgroundController,
    TextEditingController? linkedinController,
  })  : nameController = nameController ?? TextEditingController(),
        emailController = emailController ?? TextEditingController(),
        roleController = roleController ?? TextEditingController(),
        positionController = positionController ?? TextEditingController(),
        understandingController = understandingController ?? TextEditingController(),
        focusAreasController = focusAreasController ?? TextEditingController(),
        yearsWithTcsController = yearsWithTcsController ?? TextEditingController(),
        educationController = educationController ?? TextEditingController(),
        careerBackgroundController = careerBackgroundController ?? TextEditingController(),
        linkedinController = linkedinController ?? TextEditingController();

  factory AttendeeFormData.fromAttendee(Attendee attendee) {
    return AttendeeFormData(
      nameController: TextEditingController(text: attendee.name),
      emailController: TextEditingController(text: attendee.email),
      roleController: TextEditingController(text: attendee.role ?? ''),
      positionController: TextEditingController(text: attendee.position ?? ''),
      tcsSupporter: attendee.tcsSupporter?.name ?? 'NEUTRAL',
      understandingController: TextEditingController(text: attendee.understandingOfTCS ?? ''),
      focusAreasController: TextEditingController(text: attendee.focusAreas ?? ''),
      yearsWithTcsController: TextEditingController(text: attendee.yearsWorkingWithTCS?.toString() ?? ''),
      educationController: TextEditingController(text: attendee.educationalQualification ?? ''),
      careerBackgroundController: TextEditingController(text: attendee.careerBackground ?? ''),
      linkedinController: TextEditingController(text: attendee.linkedinProfile ?? ''),
    );
  }

  void dispose() {
    nameController.dispose();
    emailController.dispose();
    roleController.dispose();
    positionController.dispose();
    understandingController.dispose();
    focusAreasController.dispose();
    yearsWithTcsController.dispose();
    educationController.dispose();
    careerBackgroundController.dispose();
    linkedinController.dispose();
  }

  Map<String, dynamic> toJson() {
    return {
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'role': roleController.text.trim().isNotEmpty ? roleController.text.trim() : null,
      'position': positionController.text.trim().isNotEmpty ? positionController.text.trim() : null,
      'tcsSupporter': tcsSupporter,
      'understandingOfTCS': understandingController.text.trim().isNotEmpty ? understandingController.text.trim() : null,
      'focusAreas': focusAreasController.text.trim().isNotEmpty ? focusAreasController.text.trim() : null,
      'yearsWorkingWithTCS': yearsWithTcsController.text.trim().isNotEmpty ? int.parse(yearsWithTcsController.text.trim()) : null,
      'educationalQualification': educationController.text.trim().isNotEmpty ? educationController.text.trim() : null,
      'careerBackground': careerBackgroundController.text.trim().isNotEmpty ? careerBackgroundController.text.trim() : null,
      'linkedinProfile': linkedinController.text.trim().isNotEmpty ? linkedinController.text.trim() : null,
    };
  }
}

/// Widget builder for Section 1: Account & Company Information
class AccountCompanySection extends StatelessWidget {
  final BookingFormData formData;
  final Function(VoidCallback) onUpdate;
  final bool enabled;

  const AccountCompanySection({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: formData.accountNameController,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'Account Name',
            hintText: 'Enter account name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.account_circle),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Account name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: formData.companyNameController,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'Company Name',
            hintText: 'Enter company name',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.business),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Company name is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: formData.companySector,
          onChanged: enabled
              ? (value) {
                  onUpdate(() {
                    formData.companySector = value;
                  });
                }
              : null,
          decoration: const InputDecoration(
            labelText: 'Company Sector (optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.category),
          ),
          items: const [
            DropdownMenuItem(value: 'Technology', child: Text('Technology')),
            DropdownMenuItem(value: 'Finance', child: Text('Finance')),
            DropdownMenuItem(value: 'Healthcare', child: Text('Healthcare')),
            DropdownMenuItem(value: 'Retail', child: Text('Retail')),
            DropdownMenuItem(value: 'Manufacturing', child: Text('Manufacturing')),
            DropdownMenuItem(value: 'Energy', child: Text('Energy')),
            DropdownMenuItem(value: 'Telecommunications', child: Text('Telecommunications')),
            DropdownMenuItem(value: 'Government', child: Text('Government')),
            DropdownMenuItem(value: 'Education', child: Text('Education')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: formData.companyVertical,
          onChanged: enabled
              ? (value) {
                  onUpdate(() {
                    formData.companyVertical = value;
                  });
                }
              : null,
          decoration: const InputDecoration(
            labelText: 'Company Vertical (optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.vertical_align_center),
          ),
          items: const [
            DropdownMenuItem(value: 'Banking', child: Text('Banking')),
            DropdownMenuItem(value: 'Insurance', child: Text('Insurance')),
            DropdownMenuItem(value: 'Capital Markets', child: Text('Capital Markets')),
            DropdownMenuItem(value: 'Healthcare Provider', child: Text('Healthcare Provider')),
            DropdownMenuItem(value: 'Life Sciences', child: Text('Life Sciences')),
            DropdownMenuItem(value: 'E-commerce', child: Text('E-commerce')),
            DropdownMenuItem(value: 'Logistics', child: Text('Logistics')),
            DropdownMenuItem(value: 'Oil & Gas', child: Text('Oil & Gas')),
            DropdownMenuItem(value: 'Utilities', child: Text('Utilities')),
            DropdownMenuItem(value: 'Mining', child: Text('Mining')),
            DropdownMenuItem(value: 'Telecommunications', child: Text('Telecommunications')),
            DropdownMenuItem(value: 'Media', child: Text('Media')),
            DropdownMenuItem(value: 'Public Sector', child: Text('Public Sector')),
            DropdownMenuItem(value: 'Higher Education', child: Text('Higher Education')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: formData.companySize,
          onChanged: enabled
              ? (value) {
                  onUpdate(() {
                    formData.companySize = value;
                  });
                }
              : null,
          decoration: const InputDecoration(
            labelText: 'Company Size (optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.groups),
          ),
          items: const [
            DropdownMenuItem(value: '1-50', child: Text('1-50 employees')),
            DropdownMenuItem(value: '51-200', child: Text('51-200 employees')),
            DropdownMenuItem(value: '201-500', child: Text('201-500 employees')),
            DropdownMenuItem(value: '501-1000', child: Text('501-1000 employees')),
            DropdownMenuItem(value: '1001-5000', child: Text('1001-5000 employees')),
            DropdownMenuItem(value: '5000+', child: Text('5000+ employees')),
          ],
        ),
      ],
    );
  }
}

/// Widget builder for Section 2: Visit Details
class VisitDetailsSection extends StatelessWidget {
  final BookingFormData formData;
  final Function(VoidCallback) onUpdate;
  final bool enabled;

  const VisitDetailsSection({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: formData.venueController,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'Venue (optional)',
            hintText: 'e.g., Pace São Paulo',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: formData.overallThemeController,
          enabled: enabled,
          decoration: const InputDecoration(
            labelText: 'Overall Theme / Focus Area (optional)',
            hintText: 'Describe the main focus of this visit',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.topic),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: enabled
              ? () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: formData.lastInnovationDay ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: isDark
                            ? ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: Colors.white,
                                  onPrimary: Colors.black,
                                  surface: Colors.grey[850]!,
                                  onSurface: Colors.white,
                                ),
                              )
                            : ThemeData.light().copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Colors.black,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Colors.black,
                                ),
                              ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    onUpdate(() {
                      formData.lastInnovationDay = picked;
                    });
                  }
                }
              : null,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Date of Last Pace Experience (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event),
            ),
            child: Text(
              formData.lastInnovationDay != null
                  ? DateFormat('MMMM d, yyyy').format(formData.lastInnovationDay!)
                  : 'Select date',
              style: TextStyle(
                color: formData.lastInnovationDay != null
                    ? (isDark ? Colors.white : Colors.black)
                    : Colors.grey,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Widget builder for Section 3: Event Type & Deal Information
class EventDealSection extends StatelessWidget {
  final BookingFormData formData;
  final Function(VoidCallback) onUpdate;
  final bool enabled;

  const EventDealSection({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Event Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('TCS'),
                value: 'TCS',
                groupValue: formData.eventType,
                activeColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                onChanged: enabled
                    ? (value) {
                        onUpdate(() {
                          formData.eventType = value!;
                        });
                      }
                    : null,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('PARTNER'),
                value: 'PARTNER',
                groupValue: formData.eventType,
                activeColor: Colors.black,
                contentPadding: EdgeInsets.zero,
                onChanged: enabled
                    ? (value) {
                        onUpdate(() {
                          formData.eventType = value!;
                        });
                      }
                    : null,
              ),
            ),
          ],
        ),
        if (formData.eventType == 'PARTNER') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: formData.partnerNameController,
            enabled: enabled,
            decoration: const InputDecoration(
              labelText: 'Partner Name',
              hintText: 'Enter partner name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.handshake),
            ),
            validator: (value) {
              if (formData.eventType == 'PARTNER' && (value == null || value.trim().isEmpty)) {
                return 'Partner name is required for partner events';
              }
              return null;
            },
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: formData.dealStatus,
          onChanged: enabled
              ? (value) {
                  onUpdate(() {
                    formData.dealStatus = value!;
                  });
                }
              : null,
          decoration: const InputDecoration(
            labelText: 'Deal Status',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.assignment_turned_in),
          ),
          items: const [
            DropdownMenuItem(value: 'SWON', child: Text('SWON')),
            DropdownMenuItem(value: 'WON', child: Text('WON')),
          ],
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          title: const Text('Attach Head Approval'),
          value: formData.attachHeadApproval,
          activeColor: Colors.black,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: enabled
              ? (value) {
                  onUpdate(() {
                    formData.attachHeadApproval = value ?? false;
                  });
                }
              : null,
        ),
      ],
    );
  }
}

/// Widget builder for a single attendee card
class AttendeeCard extends StatelessWidget {
  final AttendeeFormData attendee;
  final int index;
  final VoidCallback? onRemove;
  final Function(VoidCallback) onUpdate;
  final bool enabled;
  final bool initiallyExpanded;

  const AttendeeCard({
    super.key,
    required this.attendee,
    required this.index,
    this.onRemove,
    required this.onUpdate,
    this.enabled = true,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: isDark ? Colors.grey[850] : Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: Text(
            attendee.nameController.text.isEmpty ? 'Attendee ${index + 1}' : attendee.nameController.text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRemove != null && enabled)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onRemove,
                ),
              const Icon(Icons.expand_more),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: attendee.nameController,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'Attendee full name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required';
                      }
                      return null;
                    },
                    onChanged: (_) => onUpdate(() {}),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.emailController,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'attendee@company.com',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.roleController,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Role (optional)',
                      hintText: 'e.g., Decision Maker, Influencer',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.positionController,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Position (optional)',
                      hintText: 'Job title or position',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: attendee.tcsSupporter,
                    onChanged: enabled
                        ? (value) {
                            onUpdate(() {
                              attendee.tcsSupporter = value!;
                            });
                          }
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'TCS Supporter',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.thumb_up),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SUPPORTER', child: Text('Supporter')),
                      DropdownMenuItem(value: 'NEUTRAL', child: Text('Neutral')),
                      DropdownMenuItem(value: 'DETRACTOR', child: Text('Detractor')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.understandingController,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Understanding of TCS Innovation Capabilities (optional)',
                      hintText: 'Describe their understanding...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.focusAreasController,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Focus Areas for the Year (optional)',
                      hintText: 'Key focus areas...',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.yearsWithTcsController,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Years Working with TCS (optional)',
                      hintText: 'Number of years',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.educationController,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Educational Qualification (optional)',
                      hintText: 'Degrees, certifications...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.careerBackgroundController,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'Career Background (optional)',
                      hintText: 'Previous roles, experience...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timeline),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: attendee.linkedinController,
                    enabled: enabled,
                    decoration: const InputDecoration(
                      labelText: 'LinkedIn Profile (optional)',
                      hintText: 'https://linkedin.com/in/...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.link),
                    ),
                    keyboardType: TextInputType.url,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final uri = Uri.tryParse(value);
                        if (uri == null || !uri.hasAbsolutePath) {
                          return 'Enter a valid URL';
                        }
                      }
                      return null;
                    },
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

/// Widget builder for Section 4: Attendees
class AttendeesSection extends StatelessWidget {
  final BookingFormData formData;
  final Function(VoidCallback) onUpdate;
  final bool enabled;

  const AttendeesSection({
    super.key,
    required this.formData,
    required this.onUpdate,
    this.enabled = true,
  });

  void _addAttendee() {
    if (formData.attendees.length < 3) {
      onUpdate(() {
        formData.attendees.add(AttendeeFormData());
      });
    }
  }

  void _removeAttendee(int index) {
    if (formData.attendees.length > 1) {
      onUpdate(() {
        formData.attendees[index].dispose();
        formData.attendees.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (formData.attendees.length < 3 && enabled)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _addAttendee,
              icon: Icon(Icons.add, color: isDark ? Colors.white : Colors.black),
              label: Text(
                'Add Attendee',
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              style: TextButton.styleFrom(
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
              ),
            ),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: formData.attendees.length,
          itemBuilder: (context, index) {
            return AttendeeCard(
              attendee: formData.attendees[index],
              index: index,
              onRemove: formData.attendees.length > 1 && enabled ? () => _removeAttendee(index) : null,
              onUpdate: onUpdate,
              enabled: enabled,
              initiallyExpanded: index == 0,
            );
          },
        ),
      ],
    );
  }
}

/// Widget builder for Section 5: Additional Notes
class AdditionalNotesSection extends StatelessWidget {
  final BookingFormData formData;
  final bool enabled;

  const AdditionalNotesSection({
    super.key,
    required this.formData,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: formData.additionalNotesController,
      enabled: enabled,
      decoration: const InputDecoration(
        labelText: 'Additional Notes (optional)',
        hintText: 'Any other relevant information...',
        border: OutlineInputBorder(),
        alignLabelWithHint: true,
      ),
      maxLines: 5,
    );
  }
}
