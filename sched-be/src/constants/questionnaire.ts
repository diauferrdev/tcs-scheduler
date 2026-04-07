/**
 * PACEPORT EVENT QUESTIONNAIRES
 *
 * Questionnaires are required for:
 * - Pace Visit Fullday
 * - Innovation Exchange
 * - Hackathon
 *
 * Each event type has its own questionnaire to prepare the best experience.
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

// Shared questionnaire for Pace Visit Fullday and Innovation Exchange
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
      'Explore innovative solutions and demos',
      'Understand our capabilities in my industry vertical',
      'Networking with leadership and specialists',
      'Learn about digital transformation case studies',
      'Discuss specific project opportunities',
      'Experience emerging technologies (AI, Cloud, IoT, etc.)',
    ],
    required: true,
    helpText: 'Select all that apply. This helps us customize the agenda.'
  },
  {
    id: 'technical_focus',
    question: 'Which solution areas or technologies are you most interested in exploring?',
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

// Hackathon-specific questionnaire
export const HACKATHON_QUESTIONNAIRE: QuestionnaireQuestion[] = [
  {
    id: 'hackathon_theme',
    question: 'What is the main theme or challenge for this hackathon?',
    type: 'text',
    required: true,
    placeholder: 'Example: Build an AI-powered customer service solution, Create a sustainability dashboard, etc.',
    helpText: 'Define the central problem or theme that participants will work on.'
  },
  {
    id: 'hackathon_format',
    question: 'What format best describes this hackathon?',
    type: 'single_choice',
    options: [
      'Open Innovation - Participants define their own solutions',
      'Challenge-Based - Specific problems to solve with defined success criteria',
      'Prototype Sprint - Build a working prototype from a given concept',
      'Integration Hack - Connect and integrate existing systems in new ways',
    ],
    required: true,
    helpText: 'This helps us prepare the right infrastructure and mentorship support.'
  },
  {
    id: 'hackathon_technologies',
    question: 'Which technologies or platforms should be available for participants?',
    type: 'multiple_choice',
    options: [
      'Cloud Infrastructure (AWS, Azure, GCP)',
      'AI/ML Frameworks (TensorFlow, PyTorch, OpenAI)',
      'Low-Code/No-Code Platforms',
      'IoT & Edge Computing',
      'Mobile Development (Flutter, React Native)',
      'Data & Analytics Tools',
      'Blockchain & Web3',
      'DevOps & CI/CD Pipelines',
    ],
    required: true,
    helpText: 'Select all that apply. We will ensure the necessary tools and environments are ready.'
  },
  {
    id: 'hackathon_team_size',
    question: 'What is the expected team size and total number of participants?',
    type: 'single_choice',
    options: [
      'Small (3-5 teams, 15-25 participants)',
      'Medium (6-10 teams, 30-50 participants)',
      'Large (11-20 teams, 55-100 participants)',
      'Enterprise (20+ teams, 100+ participants)',
    ],
    required: true,
    helpText: 'This determines venue setup, mentorship allocation, and infrastructure scaling.'
  },
  {
    id: 'hackathon_deliverables',
    question: 'What are the expected deliverables at the end of the hackathon?',
    type: 'multiple_choice',
    options: [
      'Working prototype / demo',
      'Business pitch presentation',
      'Technical architecture documentation',
      'Video demo / walkthrough',
      'Source code repository',
      'Post-event implementation roadmap',
    ],
    required: true,
    helpText: 'Select all that apply. This helps us structure the judging criteria and timeline.'
  },
];

/**
 * Get questionnaire by event type
 */
export function getQuestionnaireForType(eventType?: string): QuestionnaireQuestion[] {
  if (eventType === 'HACKATHON') {
    return HACKATHON_QUESTIONNAIRE;
  }
  return QUESTIONNAIRE;
}

/**
 * Validate questionnaire answers against a specific questionnaire
 */
export function validateQuestionnaireAnswers(
  answers: Record<string, any>,
  questionnaire?: QuestionnaireQuestion[]
): { valid: boolean; errors: string[] } {
  const questions = questionnaire || QUESTIONNAIRE;
  const errors: string[] = [];

  for (const question of questions) {
    if (question.required && !answers[question.id]) {
      errors.push(`Question "${question.question}" is required`);
      continue;
    }

    const answer = answers[question.id];

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
export function getQuestionnaire(eventType?: string) {
  const questions = getQuestionnaireForType(eventType);
  return questions.map(q => ({
    id: q.id,
    question: q.question,
    type: q.type,
    options: q.options,
    required: q.required,
    placeholder: q.placeholder,
    helpText: q.helpText,
  }));
}
