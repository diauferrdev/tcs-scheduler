import 'package:flutter/material.dart';
import 'dart:math';
import '../../utils/toast_notification.dart';

/// Drawer 3: Base Information with simplified fields
class BaseInfoDrawer extends StatefulWidget {
  final Function(Map<String, dynamic> data) onNext;
  final VoidCallback onBack;

  const BaseInfoDrawer({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<BaseInfoDrawer> createState() => _BaseInfoDrawerState();
}

class _BaseInfoDrawerState extends State<BaseInfoDrawer> {
  final _formKey = GlobalKey<FormState>();
  final _requesterNameController = TextEditingController();
  final _employeeIdController = TextEditingController();
  String? _vertical;
  final _organizationNameController = TextEditingController();
  String? _organizationType;
  final _organizationTypeOtherController = TextEditingController();
  final _organizationDescriptionController = TextEditingController();
  final _objectiveInterestController = TextEditingController();
  List<String> _selectedTargetAudience = [];

  final List<String> _targetAudienceOptions = [
    'C-Level',
    'Technology Leaders',
    'Business Leaders',
    'Innovation Team',
    'Technical Team',
  ];

  @override
  void dispose() {
    _requesterNameController.dispose();
    _employeeIdController.dispose();
    _organizationNameController.dispose();
    _organizationTypeOtherController.dispose();
    _organizationDescriptionController.dispose();
    _objectiveInterestController.dispose();
    super.dispose();
  }

  void _fillMockData() {
    final random = Random();
    final mocks = [
      {
        'requesterName': 'João Silva',
        'employeeId': '123456',
        'vertical': 'BFSI',
        'organizationName': 'Banco do Brasil',
        'organizationType': 'EXISTING_CUSTOMER',
        'organizationDescription': 'Leading Brazilian financial institution with over 200 years of history, serving millions of customers nationwide.',
        'objectiveInterest': 'Explore AI and cloud solutions for digital banking transformation',
        'targetAudience': ['C-Level', 'Technology Leaders'],
      },
      {
        'requesterName': 'Maria Santos',
        'employeeId': '234567',
        'vertical': 'RETAIL_CPG',
        'organizationName': 'Magazine Luiza',
        'organizationType': 'EXISTING_CUSTOMER',
        'organizationDescription': 'Leading Brazilian retail company with omnichannel presence, pioneering in e-commerce and digital transformation.',
        'objectiveInterest': 'Understand AI-powered personalization and customer experience solutions',
        'targetAudience': ['Business Leaders', 'Innovation Team'],
      },
      {
        'requesterName': 'Carlos Oliveira',
        'employeeId': '345678',
        'vertical': 'LIFE_SCIENCES_HEALTHCARE',
        'organizationName': 'Hospital Sírio-Libanês',
        'organizationType': 'PROSPECT',
        'organizationDescription': 'Premier healthcare institution in Brazil, recognized for excellence in medical care and innovation.',
        'objectiveInterest': 'Explore healthcare AI solutions and telemedicine platforms',
        'targetAudience': ['C-Level', 'Technology Leaders', 'Innovation Team'],
      },
      {
        'requesterName': 'Ana Costa',
        'employeeId': '456789',
        'vertical': 'MANUFACTURING',
        'organizationName': 'Embraer',
        'organizationType': 'EXISTING_CUSTOMER',
        'organizationDescription': 'Global aerospace manufacturer and leader in commercial and executive aviation.',
        'objectiveInterest': 'Investigate IoT, predictive maintenance, and Industry 4.0 solutions',
        'targetAudience': ['Technology Leaders', 'Technical Team'],
      },
      {
        'requesterName': 'Pedro Almeida',
        'employeeId': '567890',
        'vertical': 'HI_TECH',
        'organizationName': 'Nubank',
        'organizationType': 'PARTNER',
        'organizationDescription': 'Leading digital bank in Latin America, serving millions with innovative fintech solutions.',
        'objectiveInterest': 'Learn about cloud-native architectures and microservices at scale',
        'targetAudience': ['Technology Leaders', 'Technical Team'],
      },
      {
        'requesterName': 'Fernanda Lima',
        'employeeId': '678901',
        'vertical': 'RETAIL_CPG',
        'organizationName': 'Ambev',
        'organizationType': 'EXISTING_CUSTOMER',
        'organizationDescription': 'Largest beverage company in Latin America with strong presence in beer and soft drinks.',
        'objectiveInterest': 'Explore supply chain optimization and sustainable manufacturing solutions',
        'targetAudience': ['Business Leaders', 'C-Level'],
      },
      {
        'requesterName': 'Ricardo Mendes',
        'employeeId': '789012',
        'vertical': 'CMT',
        'organizationName': 'Vivo (Telefônica Brasil)',
        'organizationType': 'EXISTING_CUSTOMER',
        'organizationDescription': 'Leading telecommunications company providing mobile, broadband, and digital services.',
        'objectiveInterest': 'Understand 5G network solutions and edge computing capabilities',
        'targetAudience': ['Technology Leaders', 'Innovation Team'],
      },
      {
        'requesterName': 'Juliana Rodrigues',
        'employeeId': '890123',
        'vertical': 'PUBLIC_SERVICES',
        'organizationName': 'Prefeitura de São Paulo',
        'organizationType': 'GOVERNMENTAL_INSTITUTION',
        'organizationDescription': 'Municipal government of São Paulo, largest city in Brazil and Latin America.',
        'objectiveInterest': 'Explore smart city solutions and citizen engagement platforms',
        'targetAudience': ['C-Level', 'Business Leaders'],
      },
    ];

    final selectedMock = mocks[random.nextInt(mocks.length)];

    setState(() {
      _requesterNameController.text = selectedMock['requesterName'] as String;
      _employeeIdController.text = selectedMock['employeeId'] as String;
      _vertical = selectedMock['vertical'] as String;
      _organizationNameController.text = selectedMock['organizationName'] as String;
      _organizationType = selectedMock['organizationType'] as String;
      _organizationDescriptionController.text = selectedMock['organizationDescription'] as String;
      _objectiveInterestController.text = selectedMock['objectiveInterest'] as String;
      _selectedTargetAudience = List<String>.from(selectedMock['targetAudience'] as List);
    });

    ToastNotification.show(
      context,
      message: '✅ ${selectedMock['organizationName']}',
      type: ToastType.success,
      duration: const Duration(seconds: 1),
    );
  }

  // Map display names to backend enum values
  String _mapTargetAudienceToEnum(String displayName) {
    const mapping = {
      'C-Level': 'EXECUTIVES',
      'Technology Leaders': 'TECHNICAL_TEAM',
      'Business Leaders': 'MIDDLE_MANAGEMENT',
      'Innovation Team': 'MIDDLE_MANAGEMENT',
      'Technical Team': 'TECHNICAL_TEAM',
    };
    return mapping[displayName] ?? 'OTHER';
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      ToastNotification.show(
        context,
        message: 'Please fill in all required fields',
        type: ToastType.error,
      );
      return;
    }

    // Convert target audience display names to enum values
    final mappedTargetAudience = _selectedTargetAudience
        .map((displayName) => _mapTargetAudienceToEnum(displayName))
        .toSet() // Remove duplicates
        .toList();

    final data = {
      'requesterName': _requesterNameController.text.trim(),
      'employeeId': _employeeIdController.text.trim(),
      'vertical': _vertical!,
      'organizationName': _organizationNameController.text.trim(),
      'organizationType': _organizationType!,
      if (_organizationType == 'OTHER')
        'organizationTypeOther': _organizationTypeOtherController.text.trim(),
      if (_organizationDescriptionController.text.trim().isNotEmpty)
        'organizationDescription': _organizationDescriptionController.text.trim(),
      if (_objectiveInterestController.text.trim().isNotEmpty)
        'objectiveInterest': _objectiveInterestController.text.trim(),
      'targetAudience': mappedTargetAudience,
    };

    widget.onNext(data);
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
                  onPressed: widget.onBack,
                  icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Base Information',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _fillMockData,
                  icon: Icon(Icons.flash_on, color: isDark ? Colors.white : Colors.black),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
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

                    // Vertical - Fixed overflow issue
                    DropdownButtonFormField<String>(
                      initialValue: _vertical,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Vertical',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.business_center),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
                      ),
                      items: [
                        const DropdownMenuItem(value: 'BFSI', child: Text('BFSI', overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(value: 'RETAIL_CPG', child: Text('Retail & CPG', overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(value: 'LIFE_SCIENCES_HEALTHCARE', child: Text('Life Sciences & Healthcare', overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(value: 'MANUFACTURING', child: Text('Manufacturing', overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(value: 'HI_TECH', child: Text('Hi-Tech', overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(value: 'CMT', child: Text('CMT', overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(value: 'ERU', child: Text('ERU', overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(value: 'TRAVEL_HOSPITALITY', child: Text('Travel & Hospitality', overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(value: 'PUBLIC_SERVICES', child: Text('Public Services', overflow: TextOverflow.ellipsis)),
                        const DropdownMenuItem(value: 'BUSINESS_SERVICES', child: Text('Business Services', overflow: TextOverflow.ellipsis)),
                      ],
                      selectedItemBuilder: (BuildContext context) {
                        return [
                          const Text('BFSI', overflow: TextOverflow.ellipsis),
                          const Text('Retail & CPG', overflow: TextOverflow.ellipsis),
                          const Text('Life Sciences & Healthcare', overflow: TextOverflow.ellipsis),
                          const Text('Manufacturing', overflow: TextOverflow.ellipsis),
                          const Text('Hi-Tech', overflow: TextOverflow.ellipsis),
                          const Text('CMT', overflow: TextOverflow.ellipsis),
                          const Text('ERU', overflow: TextOverflow.ellipsis),
                          const Text('Travel & Hospitality', overflow: TextOverflow.ellipsis),
                          const Text('Public Services', overflow: TextOverflow.ellipsis),
                          const Text('Business Services', overflow: TextOverflow.ellipsis),
                        ];
                      },
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
                      initialValue: _organizationType,
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

                    // Target Audience - Multi-select dropdown
                    Text(
                      'Target Audience',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => _showTargetAudienceDialog(isDark),
                      borderRadius: BorderRadius.circular(4),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
                          suffixIcon: const Icon(Icons.arrow_drop_down),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedTargetAudience.isEmpty
                              ? [
                                  Text(
                                    'Select target audience',
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                                    ),
                                  )
                                ]
                              : _selectedTargetAudience.map((audience) {
                                  return Chip(
                                    label: Text(audience),
                                    onDeleted: () {
                                      setState(() {
                                        _selectedTargetAudience.remove(audience);
                                      });
                                    },
                                    backgroundColor: Colors.black,
                                    labelStyle: const TextStyle(color: Colors.white),
                                    deleteIconColor: Colors.white,
                                  );
                                }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
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
              onPressed: _submitForm,
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

  void _showTargetAudienceDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        List<String> tempSelected = List.from(_selectedTargetAudience);

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
                  children: _targetAudienceOptions.map((audience) {
                    final isSelected = tempSelected.contains(audience);
                    return CheckboxListTile(
                      title: Text(
                        audience,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      value: isSelected,
                      activeColor: Colors.black,
                      onChanged: (bool? value) {
                        setDialogState(() {
                          if (value == true) {
                            tempSelected.add(audience);
                          } else {
                            tempSelected.remove(audience);
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
                      _selectedTargetAudience = tempSelected;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
