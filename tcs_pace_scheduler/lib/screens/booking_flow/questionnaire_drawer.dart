import 'package:flutter/material.dart';
import 'dart:math';
import '../../utils/toast_notification.dart';

/// Drawer 4 (Conditional): Questionnaire - only for PACE_EXPERIENCE and INNOVATION_EXCHANGE
class QuestionnaireDrawer extends StatefulWidget {
  final Function(Map<String, String> answers) onSubmit;
  final VoidCallback onBack;

  const QuestionnaireDrawer({
    Key? key,
    required this.onSubmit,
    required this.onBack,
  }) : super(key: key);

  @override
  State<QuestionnaireDrawer> createState() => _QuestionnaireDrawerState();
}

class _QuestionnaireDrawerState extends State<QuestionnaireDrawer> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {
    'q1': TextEditingController(),
    'q2': TextEditingController(),
    'q3': TextEditingController(),
    'q4': TextEditingController(),
    'q5': TextEditingController(),
  };

  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  void _fillMockData() {
    final random = Random();
    final mocks = [
      {
        'q1': 'AI/ML, Cloud Computing, Data Analytics, IoT',
        'q2': 'Digital transformation, customer experience optimization, operational efficiency',
        'q3': 'CTO, Head of Innovation, Digital Transformation Manager, IT Director',
        'q4': 'Legacy system modernization, real-time data processing, scalability challenges',
        'q5': 'Practical implementation roadmap, technology best practices, partnership opportunities',
      },
      {
        'q1': 'Generative AI, Cybersecurity, Blockchain, Edge Computing',
        'q2': 'Security enhancement, fraud detection, process automation',
        'q3': 'CISO, VP of Technology, Security Architect, Innovation Lead',
        'q4': 'Cybersecurity threats, compliance requirements, secure data sharing',
        'q5': 'Security framework recommendations, AI integration strategies, vendor ecosystem',
      },
      {
        'q1': 'Cloud Native Architecture, Microservices, DevOps, Kubernetes',
        'q2': 'Application modernization, faster time-to-market, platform engineering',
        'q3': 'Head of Engineering, Cloud Architect, DevOps Manager, Technical Lead',
        'q4': 'Monolithic architecture limitations, deployment complexity, team collaboration',
        'q5': 'Migration strategies, tooling recommendations, success metrics',
      },
      {
        'q1': 'Industry 4.0, Predictive Maintenance, Digital Twin, Smart Manufacturing',
        'q2': 'Production optimization, quality improvement, supply chain visibility',
        'q3': 'COO, Manufacturing Director, Operations Manager, Industrial Engineer',
        'q4': 'Equipment downtime, quality control, inventory management',
        'q5': 'Industry 4.0 implementation plan, ROI analysis, technology partners',
      },
      {
        'q1': 'Customer 360, Personalization, Omnichannel, Marketing Automation',
        'q2': 'Customer retention, personalized experiences, revenue growth',
        'q3': 'CMO, Head of Customer Experience, Marketing Director, Business Intelligence Lead',
        'q4': 'Customer churn, fragmented data, inconsistent experience across channels',
        'q5': 'Customer journey optimization, data integration approaches, quick wins',
      },
    ];

    final selectedMock = mocks[random.nextInt(mocks.length)];

    setState(() {
      _controllers['q1']!.text = selectedMock['q1']!;
      _controllers['q2']!.text = selectedMock['q2']!;
      _controllers['q3']!.text = selectedMock['q3']!;
      _controllers['q4']!.text = selectedMock['q4']!;
      _controllers['q5']!.text = selectedMock['q5']!;
    });

    ToastNotification.show(
      context,
      message: '✅ Questionnaire filled',
      type: ToastType.success,
      duration: const Duration(seconds: 1),
    );
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      ToastNotification.show(
        context,
        message: 'Please answer all questions',
        type: ToastType.error,
      );
      return;
    }

    final answers = _controllers.map(
      (key, controller) => MapEntry(key, controller.text.trim()),
    );

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
                ),
              ),
            ),
          ),

          // Submit button
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
          controller: _controllers[key],
          decoration: InputDecoration(
            hintText: 'Your answer...',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: isDark ? const Color(0xFF18181B) : Colors.white,
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'This question is required';
            }
            return null;
          },
        ),
      ],
    );
  }
}
