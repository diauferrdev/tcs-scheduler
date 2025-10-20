import '../models/booking.dart';

/// **BOOKING STATUS LABELS**
const Map<BookingStatus, String> bookingStatusLabels = {
  BookingStatus.DRAFT: 'Rascunho', // DEPRECATED
  BookingStatus.PENDING_APPROVAL: 'Aguardando Aprovação', // DEPRECATED
  BookingStatus.CREATED: 'Criado',
  BookingStatus.UNDER_REVIEW: 'Em Análise',
  BookingStatus.NEED_EDIT: 'Necessita Edição',
  BookingStatus.NEED_RESCHEDULE: 'Necessita Reagendamento',
  BookingStatus.APPROVED: 'Aprovado',
  BookingStatus.NOT_APPROVED: 'Não Aprovado',
  BookingStatus.CANCELLED: 'Cancelado',
};

/// **VISIT TYPE LABELS**
const Map<VisitType, String> visitTypeLabels = {
  VisitType.QUICK_TOUR: 'Quick Tour', // DEPRECATED
  VisitType.PACE_TOUR: 'Pace Tour',
  VisitType.PACE_EXPERIENCE: 'Pace Experience',
  VisitType.INNOVATION_EXCHANGE: 'Innovation Exchange',
};

const Map<VisitType, String> visitTypeDescriptions = {
  VisitType.QUICK_TOUR: '2 horas de visita guiada', // DEPRECATED
  VisitType.PACE_TOUR: '14h-16h (2 horas) - Visita simples, sem questionário',
  VisitType.PACE_EXPERIENCE: '10h-16h (6 horas) - Dia completo, requer questionário',
  VisitType.INNOVATION_EXCHANGE: '10h-17h (7 horas) - Requer questionário e call de alinhamento',
};

/// **ENGAGEMENT TYPE LABELS**
const Map<EngagementType, String> engagementTypeLabels = {
  EngagementType.VISIT: 'Visita',
  EngagementType.INNOVATION_EXCHANGE: 'Innovation Exchange',
};

/// **ORGANIZATION TYPE LABELS**
const Map<OrganizationType, String> organizationTypeLabels = {
  OrganizationType.GOVERNMENTAL_INSTITUTION: 'Instituição Governamental',
  OrganizationType.PARTNER: 'Parceiro',
  OrganizationType.EXISTING_CUSTOMER: 'Cliente Existente',
  OrganizationType.PROSPECT: 'Prospect',
  OrganizationType.OTHER: 'Outro',
};

/// **TCS VERTICAL LABELS**
const Map<TCSVertical, String> tcsVerticalLabels = {
  TCSVertical.BFSI: 'BFSI - Banking, Financial Services & Insurance',
  TCSVertical.RETAIL_CPG: 'Retail & Consumer Packaged Goods',
  TCSVertical.LIFE_SCIENCES_HEALTHCARE: 'Life Sciences & Healthcare',
  TCSVertical.MANUFACTURING: 'Manufacturing',
  TCSVertical.HI_TECH: 'Hi-Tech',
  TCSVertical.CMT: 'CMT - Communications, Media & Technology',
  TCSVertical.ERU: 'ERU - Energy, Resources & Utilities',
  TCSVertical.TRAVEL_HOSPITALITY: 'Travel, Transportation & Hospitality',
  TCSVertical.PUBLIC_SERVICES: 'Public Services',
  TCSVertical.BUSINESS_SERVICES: 'Business Services',
};

/// **TARGET AUDIENCE LABELS**
const Map<TargetAudience, String> targetAudienceLabels = {
  TargetAudience.EXECUTIVES: 'Executivos',
  TargetAudience.MIDDLE_MANAGEMENT: 'Gerência Média',
  TargetAudience.TECHNICAL_TEAM: 'Time Técnico',
  TargetAudience.TRAINEES: 'Trainees',
  TargetAudience.STUDENTS: 'Estudantes',
  TargetAudience.CELEBRITIES: 'Celebridades',
  TargetAudience.PARTNERS: 'Parceiros',
  TargetAudience.OTHER: 'Outro',
};

/// **QUESTIONNAIRE**
///
/// This questionnaire is required for:
/// - Pace Experience (Full Day Visit)
/// - Innovation Exchange
///
/// These questions help prepare the best experience for your visit.

class QuestionnaireQuestion {
  final String id;
  final String question;
  final QuestionType type;
  final List<String>? options;
  final bool required;
  final String? placeholder;
  final String? helpText;

  const QuestionnaireQuestion({
    required this.id,
    required this.question,
    required this.type,
    this.options,
    required this.required,
    this.placeholder,
    this.helpText,
  });
}

enum QuestionType {
  singleChoice,
  multipleChoice,
  text,
  yesNo,
}

const List<QuestionnaireQuestion> paceportQuestionnaire = [
  QuestionnaireQuestion(
    id: 'budget_availability',
    question: 'A sua vertical possui orçamento alocado (R\$ 10.000 - R\$ 15.000) para este evento Pace?',
    type: QuestionType.yesNo,
    required: true,
    helpText: 'Isso nos ajuda a entender se a visita já foi aprovada financeiramente pela sua vertical.',
  ),
  QuestionnaireQuestion(
    id: 'key_expectations',
    question: 'Quais são suas principais expectativas para esta visita ao Pace?',
    type: QuestionType.multipleChoice,
    options: [
      'Explorar soluções e demos inovadoras da TCS',
      'Entender as capacidades da TCS na minha vertical de indústria',
      'Networking com liderança e especialistas da TCS',
      'Aprender sobre estudos de caso de transformação digital',
      'Discutir oportunidades específicas de projetos',
      'Experimentar tecnologias emergentes (IA, Cloud, IoT, etc.)',
    ],
    required: true,
    helpText: 'Selecione todas as opções aplicáveis. Isso nos ajuda a customizar a agenda.',
  ),
  QuestionnaireQuestion(
    id: 'technical_focus',
    question: 'Quais áreas de solução ou tecnologias da TCS você tem mais interesse em explorar?',
    type: QuestionType.multipleChoice,
    options: [
      'Inteligência Artificial & Machine Learning',
      'Transformação e Migração em Cloud',
      'Análise de Dados & Business Intelligence',
      'Cibersegurança & Gestão de Riscos',
      'IoT & Produtos Conectados',
      'Blockchain & Distributed Ledger',
      'Experiência do Cliente & Marketing Digital',
      'Aplicações Empresariais (SAP, Oracle, etc.)',
      'Automação & Operações Inteligentes',
      'Transformação Ágil & DevOps',
    ],
    required: true,
    helpText: 'Selecione até 3 prioridades. Prepararemos demos e apresentações relevantes.',
  ),
  QuestionnaireQuestion(
    id: 'digital_maturity',
    question: 'Como você descreveria o nível de maturidade digital da sua organização?',
    type: QuestionType.singleChoice,
    options: [
      'Inicial - Começando a jornada de transformação digital',
      'Desenvolvendo - Algumas iniciativas digitais em andamento',
      'Definido - Estratégia digital clara e múltiplos projetos',
      'Gerenciado - Capacidades digitais avançadas e governança',
      'Otimizando - Inovador digital líder na nossa indústria',
    ],
    required: true,
    helpText: 'Isso nos ajuda a ajustar a complexidade do conteúdo e exemplos ao seu contexto.',
  ),
  QuestionnaireQuestion(
    id: 'specific_challenges',
    question: 'Há desafios de negócio específicos ou pontos de dor que você gostaria de discutir durante a visita?',
    type: QuestionType.text,
    required: false,
    placeholder: 'Exemplo: Modernização de sistemas legados, redução de churn de clientes, melhoria de eficiência operacional, etc.',
    helpText: 'Opcional mas recomendado. Nos ajuda a preparar soluções direcionadas e estudos de caso.',
  ),
];

/// Helper function to get label for any enum
String getEnumLabel<T>(T enumValue, Map<T, String> labels) {
  return labels[enumValue] ?? enumValue.toString().split('.').last;
}

/// Specific helper functions
String getBookingStatusLabel(BookingStatus status) {
  return getEnumLabel(status, bookingStatusLabels);
}

String getVisitTypeLabel(VisitType type) {
  return getEnumLabel(type, visitTypeLabels);
}

String getEngagementTypeLabel(EngagementType type) {
  return getEnumLabel(type, engagementTypeLabels);
}

String getOrganizationTypeLabel(OrganizationType type) {
  return getEnumLabel(type, organizationTypeLabels);
}

String getTCSVerticalLabel(TCSVertical vertical) {
  return getEnumLabel(vertical, tcsVerticalLabels);
}

String getTargetAudienceLabel(TargetAudience audience) {
  return getEnumLabel(audience, targetAudienceLabels);
}

/// Check if a visit type requires questionnaire
bool requiresQuestionnaire(VisitType visitType) {
  return visitType == VisitType.PACE_EXPERIENCE ||
         visitType == VisitType.INNOVATION_EXCHANGE;
}

/// Check if a visit type requires alignment call
bool requiresAlignmentCall(VisitType visitType) {
  return visitType == VisitType.INNOVATION_EXCHANGE;
}
