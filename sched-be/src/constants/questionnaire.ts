/**
 * PACEPORT EVENT QUESTIONNAIRE
 *
 * This questionnaire is required for:
 * - Pace Experience (Full Day Visit)
 * - Innovation Exchange
 *
 * These questions help us prepare the best experience for your visit.
 */

export interface QuestionnaireQuestion {
  id: string;
  question: string;
  type: 'single_choice' | 'multiple_choice' | 'text' | 'yes_no';
  options?: string[];
  required: boolean;
  placeholder?: string;
  helpText?: string;
}

export const QUESTIONNAIRE: QuestionnaireQuestion[] = [
  {
    id: 'budget_availability',
    question: 'Does your vertical account have allocated budget (R$ 10.000 - R$ 15.000) for this PacePort event?',
    type: 'yes_no',
    required: true,
    helpText: 'This helps us understand if the visit is already financially approved by your vertical.'
  },
  {
    id: 'key_expectations',
    question: 'What are your main expectations for this PacePort visit?',
    type: 'multiple_choice',
    options: [
      'Explore TCS innovative solutions and demos',
      'Understand TCS capabilities in my industry vertical',
      'Networking with TCS leadership and specialists',
      'Learn about digital transformation case studies',
      'Discuss specific project opportunities',
      'Experience emerging technologies (AI, Cloud, IoT, etc.)',
    ],
    required: true,
    helpText: 'Select all that apply. This helps us customize the agenda.'
  },
  {
    id: 'technical_focus',
    question: 'Which TCS solution areas or technologies are you most interested in exploring?',
    type: 'multiple_choice',
    options: [
      'Artificial Intelligence & Machine Learning',
      'Cloud Transformation & Migration',
      'Data Analytics & Business Intelligence',
      'Cybersecurity & Risk Management',
      'IoT & Connected Products',
      'Blockchain & Distributed Ledger',
      'Customer Experience & Digital Marketing',
      'Enterprise Applications (SAP, Oracle, etc.)',
      'Automation & Intelligent Operations',
      'Agile & DevOps Transformation',
    ],
    required: true,
    helpText: 'Select up to 3 priorities. We will prepare relevant demos and presentations.'
  },
  {
    id: 'digital_maturity',
    question: 'How would you describe your organization\'s digital maturity level?',
    type: 'single_choice',
    options: [
      'Initial - Beginning digital transformation journey',
      'Developing - Some digital initiatives in progress',
      'Defined - Clear digital strategy and multiple projects',
      'Managed - Advanced digital capabilities and governance',
      'Optimizing - Leading-edge digital innovator in our industry',
    ],
    required: true,
    helpText: 'This helps us tailor the content complexity and examples to your context.'
  },
  {
    id: 'specific_challenges',
    question: 'Are there specific business challenges or pain points you would like to discuss during the visit?',
    type: 'text',
    required: false,
    placeholder: 'Example: Legacy system modernization, customer churn reduction, operational efficiency improvement, etc.',
    helpText: 'Optional but recommended. Helps us prepare targeted solutions and case studies.'
  },
];

/**
 * Validate questionnaire answers
 */
export function validateQuestionnaireAnswers(answers: Record<string, any>): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  for (const question of QUESTIONNAIRE) {
    if (question.required && !answers[question.id]) {
      errors.push(`Question "${question.question}" is required`);
      continue;
    }

    const answer = answers[question.id];

    // Validate answer type
    if (answer) {
      switch (question.type) {
        case 'yes_no':
          if (typeof answer !== 'boolean') {
            errors.push(`Answer for "${question.question}" must be yes/no (boolean)`);
          }
          break;
        case 'single_choice':
          if (typeof answer !== 'string' || (question.options && !question.options.includes(answer))) {
            errors.push(`Invalid answer for "${question.question}"`);
          }
          break;
        case 'multiple_choice':
          if (!Array.isArray(answer) || answer.some(a => !question.options?.includes(a))) {
            errors.push(`Invalid answers for "${question.question}"`);
          }
          break;
        case 'text':
          if (typeof answer !== 'string') {
            errors.push(`Answer for "${question.question}" must be text`);
          }
          break;
      }
    }
  }

  return {
    valid: errors.length === 0,
    errors
  };
}

/**
 * Get questionnaire for API response
 */
export function getQuestionnaire() {
  return QUESTIONNAIRE.map(q => ({
    id: q.id,
    question: q.question,
    type: q.type,
    options: q.options,
    required: q.required,
    placeholder: q.placeholder,
    helpText: q.helpText,
  }));
}
