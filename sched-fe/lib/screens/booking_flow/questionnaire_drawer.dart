import 'package:flutter/material.dart';
import 'dart:math';
import '../../services/api_service.dart';
import '../../utils/toast_notification.dart';

/// Drawer 4 (Conditional): Questionnaire - for PACE_VISIT_FULLDAY, INNOVATION_EXCHANGE, and HACKATHON
class QuestionnaireDrawer extends StatefulWidget {
  final Function(Map<String, String> answers) onSubmit;
  final VoidCallback onBack;
  final String? eventType;

  const QuestionnaireDrawer({
    super.key,
    required this.onSubmit,
    required this.onBack,
    this.eventType,
  });

  @override
  State<QuestionnaireDrawer> createState() => _QuestionnaireDrawerState();
}

class _QuestionnaireDrawerState extends State<QuestionnaireDrawer> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, String> _singleChoiceAnswers = {};
  final Map<String, List<String>> _multiChoiceAnswers = {};
  final Map<String, bool?> _yesNoAnswers = {};

  List<dynamic> _questions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQuestionnaire();
  }

  @override
  void dispose() {
    for (var controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuestionnaire() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getQuestionnaire(eventType: widget.eventType);
      final questions = response['questionnaire'] as List<dynamic>;

      for (final q in questions) {
        final id = q['id'] as String;
        final type = q['type'] as String;
        if (type == 'text') {
          _textControllers[id] = TextEditingController();
        } else if (type == 'single_choice') {
          _singleChoiceAnswers[id] = '';
        } else if (type == 'multiple_choice') {
          _multiChoiceAnswers[id] = [];
        } else if (type == 'yes_no') {
          _yesNoAnswers[id] = null;
        }
      }

      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _fillMockData() {
    final random = Random();

    if (widget.eventType == 'HACKATHON') {
      _fillHackathonMock(random);
    } else {
      _fillDefaultMock(random);
    }

    setState(() {});

    ToastNotification.show(
      context,
      message: 'Questionnaire filled',
      type: ToastType.success,
      duration: const Duration(seconds: 1),
    );
  }

  void _fillDefaultMock(Random random) {
    // Default questionnaire mock (Pace Visit Fullday / Innovation Exchange)
    final mockSets = [
      {
        'budget_availability': true,
        'key_expectations': [
          'Explore innovative solutions and demos',
          'Discuss specific project opportunities',
        ],
        'technical_focus': [
          'Artificial Intelligence & Machine Learning',
          'Cloud Transformation & Migration',
        ],
        'digital_maturity': 'Developing - Some digital initiatives in progress',
        'specific_challenges': 'Legacy system modernization, real-time data processing',
      },
      {
        'budget_availability': true,
        'key_expectations': [
          'Experience emerging technologies (AI, Cloud, IoT, etc.)',
          'Understand our capabilities in my industry vertical',
        ],
        'technical_focus': [
          'Cybersecurity & Risk Management',
          'Data Analytics & Business Intelligence',
          'Automation & Intelligent Operations',
        ],
        'digital_maturity': 'Defined - Clear digital strategy and multiple projects',
        'specific_challenges': 'Cybersecurity threats, compliance requirements, secure data sharing',
      },
      {
        'budget_availability': false,
        'key_expectations': [
          'Learn about digital transformation case studies',
          'Networking with leadership and specialists',
        ],
        'technical_focus': [
          'Customer Experience & Digital Marketing',
          'Agile & DevOps Transformation',
        ],
        'digital_maturity': 'Initial - Beginning digital transformation journey',
        'specific_challenges': '',
      },
    ];

    final mock = mockSets[random.nextInt(mockSets.length)];
    _applyMock(mock);
  }

  void _fillHackathonMock(Random random) {
    final mockSets = [
      {
        'hackathon_theme': 'Build an AI-powered customer service chatbot using LLMs and RAG',
        'hackathon_format': 'Challenge-Based - Specific problems to solve with defined success criteria',
        'hackathon_technologies': [
          'AI/ML Frameworks (TensorFlow, PyTorch, OpenAI)',
          'Cloud Infrastructure (AWS, Azure, GCP)',
          'Data & Analytics Tools',
        ],
        'hackathon_team_size': 'Medium (6-10 teams, 30-50 participants)',
        'hackathon_deliverables': [
          'Working prototype / demo',
          'Business pitch presentation',
          'Source code repository',
        ],
      },
      {
        'hackathon_theme': 'Create a sustainability monitoring dashboard for supply chain ESG metrics',
        'hackathon_format': 'Prototype Sprint - Build a working prototype from a given concept',
        'hackathon_technologies': [
          'Cloud Infrastructure (AWS, Azure, GCP)',
          'IoT & Edge Computing',
          'Low-Code/No-Code Platforms',
        ],
        'hackathon_team_size': 'Small (3-5 teams, 15-25 participants)',
        'hackathon_deliverables': [
          'Working prototype / demo',
          'Video demo / walkthrough',
          'Post-event implementation roadmap',
        ],
      },
      {
        'hackathon_theme': 'Integrate mobile banking with real-time fraud detection using edge AI',
        'hackathon_format': 'Integration Hack - Connect and integrate existing systems in new ways',
        'hackathon_technologies': [
          'Mobile Development (Flutter, React Native)',
          'AI/ML Frameworks (TensorFlow, PyTorch, OpenAI)',
          'DevOps & CI/CD Pipelines',
        ],
        'hackathon_team_size': 'Large (11-20 teams, 55-100 participants)',
        'hackathon_deliverables': [
          'Working prototype / demo',
          'Technical architecture documentation',
          'Source code repository',
          'Business pitch presentation',
        ],
      },
    ];

    final mock = mockSets[random.nextInt(mockSets.length)];
    _applyMock(mock);
  }

  void _applyMock(Map<String, dynamic> mock) {
    for (final q in _questions) {
      final id = q['id'] as String;
      final type = q['type'] as String;
      final value = mock[id];
      if (value == null) continue;

      switch (type) {
        case 'text':
          _textControllers[id]?.text = value as String;
          break;
        case 'single_choice':
          _singleChoiceAnswers[id] = value as String;
          break;
        case 'multiple_choice':
          _multiChoiceAnswers[id] = List<String>.from(value as List);
          break;
        case 'yes_no':
          _yesNoAnswers[id] = value as bool;
          break;
      }
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      // Also check non-text required fields
      ToastNotification.show(
        context,
        message: 'Please answer all required questions',
        type: ToastType.error,
      );
      return;
    }

    // Validate required non-text fields
    for (final q in _questions) {
      final id = q['id'] as String;
      final type = q['type'] as String;
      final required = q['required'] as bool? ?? false;
      if (!required) continue;

      switch (type) {
        case 'yes_no':
          if (_yesNoAnswers[id] == null) {
            ToastNotification.show(
              context,
              message: 'Please answer: ${q['question']}',
              type: ToastType.error,
            );
            return;
          }
          break;
        case 'single_choice':
          if (_singleChoiceAnswers[id]?.isEmpty ?? true) {
            ToastNotification.show(
              context,
              message: 'Please select an option for: ${q['question']}',
              type: ToastType.error,
            );
            return;
          }
          break;
        case 'multiple_choice':
          if (_multiChoiceAnswers[id]?.isEmpty ?? true) {
            ToastNotification.show(
              context,
              message: 'Please select at least one option for: ${q['question']}',
              type: ToastType.error,
            );
            return;
          }
          break;
      }
    }

    // Build answers map - serialize all types as strings for the API
    final answers = <String, String>{};
    for (final q in _questions) {
      final id = q['id'] as String;
      final type = q['type'] as String;

      switch (type) {
        case 'text':
          answers[id] = _textControllers[id]?.text.trim() ?? '';
          break;
        case 'single_choice':
          answers[id] = _singleChoiceAnswers[id] ?? '';
          break;
        case 'multiple_choice':
          answers[id] = (_multiChoiceAnswers[id] ?? []).join(', ');
          break;
        case 'yes_no':
          answers[id] = _yesNoAnswers[id] == true ? 'Yes' : 'No';
          break;
      }
    }

    widget.onSubmit(answers);
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
                    'Questionnaire',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                if (!_loading && _error == null)
                  IconButton(
                    onPressed: _fillMockData,
                    icon: Icon(Icons.flash_on, color: isDark ? Colors.white : Colors.black),
                  ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
                              const SizedBox(height: 16),
                              Text(
                                'Failed to load questionnaire',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _loading = true;
                                    _error = null;
                                  });
                                  _loadQuestionnaire();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0A0A0B) : const Color(0xFFF0F9FF),
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
                                        'Please answer these questions to help us prepare a tailored experience for you.',
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
                              ..._questions.asMap().entries.map((entry) {
                                final index = entry.key;
                                final q = entry.value;
                                return Padding(
                                  padding: EdgeInsets.only(bottom: index < _questions.length - 1 ? 20 : 0),
                                  child: _buildQuestionWidget(q, index + 1, isDark),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
          ),

          // Submit button
          if (!_loading && _error == null)
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
                  'Create Booking',
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

  Widget _buildQuestionWidget(dynamic question, int number, bool isDark) {
    final id = question['id'] as String;
    final text = question['question'] as String;
    final type = question['type'] as String;
    final required = question['required'] as bool? ?? false;
    final options = (question['options'] as List<dynamic>?)?.cast<String>() ?? [];
    final placeholder = question['placeholder'] as String? ?? 'Your answer...';
    final helpText = question['helpText'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number. $text${required ? ' *' : ''}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        if (helpText != null) ...[
          const SizedBox(height: 4),
          Text(
            helpText,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
        const SizedBox(height: 8),
        _buildInputForType(id, type, options, placeholder, required, isDark),
      ],
    );
  }

  Widget _buildInputForType(
    String id,
    String type,
    List<String> options,
    String placeholder,
    bool required,
    bool isDark,
  ) {
    switch (type) {
      case 'text':
        return TextFormField(
          controller: _textControllers[id],
          decoration: InputDecoration(
            hintText: placeholder,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          maxLines: 3,
          validator: required
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'This question is required';
                  }
                  return null;
                }
              : null,
        );

      case 'yes_no':
        return Row(
          children: [
            _buildChoiceChip('Yes', _yesNoAnswers[id] == true, isDark, () {
              setState(() => _yesNoAnswers[id] = true);
            }),
            const SizedBox(width: 8),
            _buildChoiceChip('No', _yesNoAnswers[id] == false, isDark, () {
              setState(() => _yesNoAnswers[id] = false);
            }),
          ],
        );

      case 'single_choice':
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final selected = _singleChoiceAnswers[id] == option;
            return _buildChoiceChip(option, selected, isDark, () {
              setState(() => _singleChoiceAnswers[id] = option);
            });
          }).toList(),
        );

      case 'multiple_choice':
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final selected = _multiChoiceAnswers[id]?.contains(option) ?? false;
            return _buildChoiceChip(option, selected, isDark, () {
              setState(() {
                final list = _multiChoiceAnswers[id] ?? [];
                if (selected) {
                  list.remove(option);
                } else {
                  list.add(option);
                }
                _multiChoiceAnswers[id] = list;
              });
            });
          }).toList(),
        );

      default:
        return TextFormField(
          controller: _textControllers.putIfAbsent(id, () => TextEditingController()),
          decoration: InputDecoration(
            hintText: placeholder,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          maxLines: 3,
        );
    }
  }

  Widget _buildChoiceChip(String label, bool selected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? const Color(0xFF27272A) : const Color(0xFFF4F4F5)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFD4D4D8)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? (isDark ? Colors.black : Colors.white)
                : (isDark ? Colors.grey[300] : Colors.grey[700]),
          ),
        ),
      ),
    );
  }
}
