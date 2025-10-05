export const COMPANY_SECTORS = [
  'Technology',
  'Financial Services',
  'Healthcare',
  'Retail',
  'Manufacturing',
  'Energy',
  'Telecommunications',
  'Government',
  'Education',
  'Other',
] as const;

export const COMPANY_VERTICALS = [
  'Banking',
  'Insurance',
  'Capital Markets',
  'Healthcare Provider',
  'Life Sciences',
  'Retail',
  'Manufacturing',
  'Energy & Utilities',
  'Public Sector',
  'Horizontal (Cross-industry)',
] as const;

export const INTEREST_AREAS = [
  'Artificial Intelligence',
  'Cloud Migration',
  'Digital Transformation',
  'Data Analytics',
  'Cybersecurity',
  'DevOps',
  'IoT',
  'Blockchain',
  'Automation',
  'Legacy Modernization',
  'Other',
] as const;

export const COMPANY_SIZES = [
  'Small (1-50 employees)',
  'Medium (51-500 employees)',
  'Large (501-5000 employees)',
  'Enterprise (5000+ employees)',
] as const;

export const TIME_SLOTS = {
  MORNING: '09:00',
  AFTERNOON: '14:00',
} as const;

export const VISIT_DURATION_LABELS = {
  THREE_HOURS: '3 hours',
  SIX_HOURS: '6 hours (Full day)',
} as const;
