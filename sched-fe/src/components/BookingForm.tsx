import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { BookingCreateSchema } from '../types';
import { api } from '@/lib/api';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';
import { Textarea } from './ui/textarea';
import { toast } from 'sonner';
import { Sparkles, Plus, X } from 'lucide-react';

interface BookingFormProps {
  onSuccess: (booking: any) => void;
  onCancel: () => void;
  token?: string;
  initialDate?: string;
  initialSlot?: 'morning' | 'afternoon' | 'full-day';
  theme?: 'light' | 'dark';
}

const SECTORS = ['Technology', 'Financial Services', 'Healthcare', 'Retail', 'Manufacturing', 'Energy', 'Telecommunications', 'Government', 'Education', 'Other'];
const VERTICALS = ['Banking', 'Insurance', 'Capital Markets', 'Healthcare Provider', 'Life Sciences', 'Retail', 'Manufacturing', 'Energy & Utilities', 'Public Sector', 'Horizontal (Cross-industry)'];
const INTEREST_AREAS = ['Artificial Intelligence', 'Cloud Migration', 'Digital Transformation', 'Data Analytics', 'Cybersecurity', 'DevOps', 'IoT', 'Blockchain', 'Automation', 'Legacy Modernization', 'Other'];

export default function BookingForm({ onSuccess, onCancel, token, initialDate, initialSlot, theme = 'light' }: BookingFormProps) {
  const [loading, setLoading] = useState(false);
  const [attendees, setAttendees] = useState<Array<{ name: string; position?: string; email?: string }>>([{ name: '', position: '', email: '' }]);

  // Determine values from slot
  const getSlotValues = () => {
    if (initialSlot === 'morning') {
      return { startTime: '09:00' as '09:00' | '14:00', duration: 'THREE_HOURS' as const };
    } else if (initialSlot === 'afternoon') {
      return { startTime: '14:00' as '09:00' | '14:00', duration: 'THREE_HOURS' as const };
    } else if (initialSlot === 'full-day') {
      return { startTime: '09:00' as '09:00' | '14:00', duration: 'SIX_HOURS' as const };
    }
    return { startTime: '09:00' as '09:00' | '14:00', duration: 'THREE_HOURS' as const };
  };

  const slotValues = getSlotValues();

  const form = useForm({
    resolver: zodResolver(BookingCreateSchema),
    defaultValues: {
      date: initialDate || '',
      startTime: slotValues.startTime,
      duration: slotValues.duration,
      companyName: '',
      companySector: '',
      companyVertical: '',
      companySize: '',
      contactName: '',
      contactEmail: '',
      contactPhone: '',
      contactPosition: '',
      interestArea: '',
      expectedAttendees: 1,
      attendees: [{ name: '', position: '', email: '' }],
      businessGoal: '',
      additionalNotes: '',
    },
  });

  const generateFakeData = () => {
    const companiesData = [
      // Financial Services
      { name: 'Itaú Unibanco', sector: 'Financial Services', vertical: 'Banking' },
      { name: 'Bradesco', sector: 'Financial Services', vertical: 'Banking' },
      { name: 'Banco do Brasil', sector: 'Financial Services', vertical: 'Banking' },
      { name: 'Santander Brasil', sector: 'Financial Services', vertical: 'Banking' },
      { name: 'BTG Pactual', sector: 'Financial Services', vertical: 'Capital Markets' },
      { name: 'SulAmérica', sector: 'Financial Services', vertical: 'Insurance' },
      // Energy
      { name: 'Petrobras', sector: 'Energy', vertical: 'Energy & Utilities' },
      { name: 'Eletrobras', sector: 'Energy', vertical: 'Energy & Utilities' },
      { name: 'CPFL Energia', sector: 'Energy', vertical: 'Energy & Utilities' },
      { name: 'Equatorial Energia', sector: 'Energy', vertical: 'Energy & Utilities' },
      // Manufacturing
      { name: 'Vale', sector: 'Manufacturing', vertical: 'Manufacturing' },
      { name: 'Gerdau', sector: 'Manufacturing', vertical: 'Manufacturing' },
      { name: 'CSN', sector: 'Manufacturing', vertical: 'Manufacturing' },
      { name: 'Ambev', sector: 'Manufacturing', vertical: 'Manufacturing' },
      { name: 'JBS', sector: 'Manufacturing', vertical: 'Manufacturing' },
      { name: 'BRF', sector: 'Manufacturing', vertical: 'Manufacturing' },
      { name: 'Marfrig', sector: 'Manufacturing', vertical: 'Manufacturing' },
      { name: 'Suzano', sector: 'Manufacturing', vertical: 'Manufacturing' },
      { name: 'Klabin', sector: 'Manufacturing', vertical: 'Manufacturing' },
      { name: 'Embraer', sector: 'Manufacturing', vertical: 'Manufacturing' },
      // Retail
      { name: 'Natura &Co', sector: 'Retail', vertical: 'Retail' },
      { name: 'Magazine Luiza', sector: 'Retail', vertical: 'Retail' },
      { name: 'Via Varejo', sector: 'Retail', vertical: 'Retail' },
      { name: 'Lojas Americanas', sector: 'Retail', vertical: 'Retail' },
      { name: 'Carrefour Brasil', sector: 'Retail', vertical: 'Retail' },
      // Telecommunications
      { name: 'Telefônica Brasil (Vivo)', sector: 'Telecommunications', vertical: 'Horizontal (Cross-industry)' },
      { name: 'TIM Brasil', sector: 'Telecommunications', vertical: 'Horizontal (Cross-industry)' },
      { name: 'Claro Brasil', sector: 'Telecommunications', vertical: 'Horizontal (Cross-industry)' },
      { name: 'Oi', sector: 'Telecommunications', vertical: 'Horizontal (Cross-industry)' },
      // Healthcare
      { name: 'Hapvida', sector: 'Healthcare', vertical: 'Healthcare Provider' },
      { name: 'Rede D\'Or São Luiz', sector: 'Healthcare', vertical: 'Healthcare Provider' },
      // Other
      { name: 'GOL Linhas Aéreas', sector: 'Other', vertical: 'Horizontal (Cross-industry)' },
      { name: 'LATAM Airlines Brasil', sector: 'Other', vertical: 'Horizontal (Cross-industry)' },
      { name: 'Azul Linhas Aéreas', sector: 'Other', vertical: 'Horizontal (Cross-industry)' },
      { name: 'Localiza', sector: 'Other', vertical: 'Horizontal (Cross-industry)' },
    ];

    const firstNames = ['James', 'Mary', 'John', 'Patricia', 'Robert', 'Jennifer', 'Michael', 'Linda', 'William', 'Elizabeth', 'David', 'Barbara', 'Richard', 'Susan', 'Joseph'];
    const lastNames = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Wilson', 'Anderson'];
    const positions = [
      'CEO', 'CTO', 'CFO', 'CIO', 'CDO', 'CISO',
      'VP of Technology', 'VP of Innovation', 'VP of Digital Transformation',
      'IT Director', 'Innovation Director', 'Technology Director',
      'Head of Digital', 'Head of Data & Analytics', 'Head of Architecture',
      'Executive IT Manager', 'Senior Technology Manager'
    ];
    const goals = [
      'Accelerate digital transformation with AI and Cloud solutions',
      'Modernize legacy infrastructure and migrate to cloud',
      'Implement data strategy and advanced analytics',
      'Strengthen cybersecurity posture and compliance',
      'Optimize operations with automation and RPA',
      'Develop machine learning and AI capabilities',
      'Migrate critical applications to cloud-native architecture',
      'Implement DevSecOps and continuous delivery',
      'Create unified data platform and governance',
      'Transform customer experience with digital'
    ];
    const additionalNotesList = [
      'Visit approved by executive committee. Interest in generative AI use cases.',
      'Q1 priority project. Cloud architecture demonstration required.',
      'Technical team will participate. Focus on security and regulatory compliance.',
      'Strategic meeting with C-Level. Present digital transformation cases.',
      'Project in RFP phase. Interest in mainframe modernization.',
      'Budget approved for cloud initiative. Detailed ROI required.',
      'Technical visit for architects and developers. Deep dive into DevOps.',
      'Contract renewal under analysis. Present new AI/ML solutions.',
      'Interest in long-term strategic partnership.',
      'NDA required before meeting. Confidential project discussion.'
    ];

    const companyData = companiesData[Math.floor(Math.random() * companiesData.length)];
    const firstName = firstNames[Math.floor(Math.random() * firstNames.length)];
    const lastName = lastNames[Math.floor(Math.random() * lastNames.length)];
    const contactName = `${firstName} ${lastName}`;
    const email = `${firstName.toLowerCase()}.${lastName.toLowerCase()}@${companyData.name.toLowerCase().replace(/\s/g, '').replace(/[^a-z]/g, '')}.com`;

    form.setValue('companyName', companyData.name);
    form.setValue('companySector', companyData.sector);
    form.setValue('companyVertical', companyData.vertical);
    form.setValue('contactName', contactName);
    form.setValue('contactEmail', email);
    form.setValue('contactPhone', `+55 11 ${Math.floor(Math.random() * 90000 + 10000)}-${Math.floor(Math.random() * 9000 + 1000)}`);
    form.setValue('contactPosition', positions[Math.floor(Math.random() * positions.length)]);
    form.setValue('interestArea', INTEREST_AREAS[Math.floor(Math.random() * INTEREST_AREAS.length)]);

    // Generate attendees (2-5 people)
    const numAttendees = Math.floor(Math.random() * 4 + 2);
    const generatedAttendees = Array.from({ length: numAttendees }, () => {
      const fName = firstNames[Math.floor(Math.random() * firstNames.length)];
      const lName = lastNames[Math.floor(Math.random() * lastNames.length)];
      const attendeeName = `${fName} ${lName}`;
      const attendeeEmail = `${fName.toLowerCase()}.${lName.toLowerCase()}@${companyData.name.toLowerCase().replace(/\s/g, '').replace(/[^a-z]/g, '')}.com`;
      const attendeePosition = positions[Math.floor(Math.random() * positions.length)];
      return { name: attendeeName, position: attendeePosition, email: attendeeEmail };
    });

    form.setValue('expectedAttendees', numAttendees);
    form.setValue('attendees', generatedAttendees);
    setAttendees(generatedAttendees);

    form.setValue('businessGoal', goals[Math.floor(Math.random() * goals.length)]);
    form.setValue('additionalNotes', additionalNotesList[Math.floor(Math.random() * additionalNotesList.length)]);

    toast.success('Test data generated!');
  };

  const addAttendee = () => {
    const newAttendees = [...attendees, { name: '', position: '', email: '' }];
    setAttendees(newAttendees);
    form.setValue('attendees', newAttendees);
  };

  const removeAttendee = (index: number) => {
    if (attendees.length > 1) {
      const newAttendees = attendees.filter((_, i) => i !== index);
      setAttendees(newAttendees);
      form.setValue('attendees', newAttendees);
      form.setValue('expectedAttendees', newAttendees.length);
    }
  };

  const updateAttendee = (index: number, field: 'name' | 'position' | 'email', value: string) => {
    const newAttendees = [...attendees];
    newAttendees[index] = { ...newAttendees[index], [field]: value };
    setAttendees(newAttendees);
    form.setValue('attendees', newAttendees);
    form.setValue('expectedAttendees', newAttendees.length);
  };

  const onSubmit = async (data: any) => {
    setLoading(true);

    try {
      // Use first attendee as contact information
      const firstAttendee = attendees[0];
      if (!firstAttendee || !firstAttendee.name) {
        toast.error('Please add at least one attendee with name and email');
        setLoading(false);
        return;
      }

      if (!firstAttendee.email) {
        toast.error('Email is required for the main contact (first attendee)');
        setLoading(false);
        return;
      }

      const endpoint = token ? '/api/bookings/guest' : '/api/bookings';
      const payload = token
        ? {
            ...data,
            token,
            attendees,
            contactName: firstAttendee.name,
            contactEmail: firstAttendee.email,
            contactPosition: firstAttendee.position || '',
            contactPhone: ''
          }
        : {
            ...data,
            attendees,
            contactName: firstAttendee.name,
            contactEmail: firstAttendee.email,
            contactPosition: firstAttendee.position || '',
            contactPhone: ''
          };

      const response = await api.post(endpoint, payload);

      // Reset loading state BEFORE calling onSuccess to prevent UI hanging
      setLoading(false);

      // Call success callback (may close drawer/navigate away)
      onSuccess(response.data);
    } catch (err: any) {
      setLoading(false);
      const errorMessage = err.response?.data?.error || err.response?.data?.message || 'Failed to create booking';
      toast.error(typeof errorMessage === 'string' ? errorMessage : 'Failed to create booking');
    }
  };

  return (
    <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
      {/* Generate Fake Data Button */}
      <div className="flex justify-end">
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={generateFakeData}
          className={`${theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}`}
        >
          <Sparkles className="h-4 w-4 mr-2" />
          Generate Test Data
        </Button>
      </div>

      {/* Date and Time - Disabled when pre-filled from calendar */}
      <div className="space-y-4">
        <div>
          <Label htmlFor="date" className={theme === 'dark' ? 'text-gray-300' : ''}>Date *</Label>
          <Input
            id="date"
            type="date"
            {...form.register('date')}
            className={`mt-1 ${theme === 'dark' ? '!bg-black !border-zinc-800 !text-white' : ''} ${!!initialDate ? 'opacity-60 cursor-not-allowed' : ''}`}
            disabled={!!initialDate}
          />
          {form.formState.errors.date && (
            <p className="text-sm text-red-400 mt-1">{String(form.formState.errors.date.message)}</p>
          )}
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <Label htmlFor="duration" className={theme === 'dark' ? 'text-gray-300' : ''}>Duration *</Label>
            <Select
              value={form.watch('duration')}
              onValueChange={(value) => form.setValue('duration', value as any)}
              disabled={!!initialSlot}
            >
              <SelectTrigger className={`mt-1 ${theme === 'dark' ? 'bg-zinc-950 border-zinc-800 text-white' : ''}`}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
                <SelectItem value="THREE_HOURS">3 Hours</SelectItem>
                <SelectItem value="SIX_HOURS">6 Hours (Full Day)</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div>
            <Label htmlFor="startTime" className={theme === 'dark' ? 'text-gray-300' : ''}>Start Time *</Label>
            <Select
              value={form.watch('startTime')}
              onValueChange={(value) => form.setValue('startTime', value as any)}
              disabled={!!initialSlot}
            >
              <SelectTrigger className={`mt-1 ${theme === 'dark' ? 'bg-zinc-950 border-zinc-800 text-white' : ''}`}>
                <SelectValue />
              </SelectTrigger>
              <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
                <SelectItem value="09:00">09:00 (Morning)</SelectItem>
                <SelectItem value="14:00">14:00 (Afternoon)</SelectItem>
              </SelectContent>
            </Select>
          </div>
        </div>
      </div>

      {/* Company Information */}
      <div className="space-y-4">
        <h3 className={`font-semibold text-lg ${theme === 'dark' ? 'text-white' : ''}`}>Company Information</h3>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <Label htmlFor="companyName" className={theme === 'dark' ? 'text-gray-300' : ''}>Company Name *</Label>
            <Input
              id="companyName"
              {...form.register('companyName')}
              className={`mt-1 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}
            />
            {form.formState.errors.companyName && (
              <p className="text-sm text-red-400 mt-1">{String(form.formState.errors.companyName.message)}</p>
            )}
          </div>

          <div>
            <Label htmlFor="companySector" className={theme === 'dark' ? 'text-gray-300' : ''}>Sector *</Label>
            <Select
              value={form.watch('companySector')}
              onValueChange={(value) => form.setValue('companySector', value)}
            >
              <SelectTrigger className={`mt-1 ${theme === 'dark' ? 'bg-zinc-950 border-zinc-800 text-white' : ''}`}>
                <SelectValue placeholder="Select sector" />
              </SelectTrigger>
              <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
                {SECTORS.map((sector) => (
                  <SelectItem key={sector} value={sector}>
                    {sector}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {form.formState.errors.companySector && (
              <p className="text-sm text-red-400 mt-1">{String(form.formState.errors.companySector.message)}</p>
            )}
          </div>
        </div>

        <div>
          <Label htmlFor="companyVertical" className={theme === 'dark' ? 'text-gray-300' : ''}>Vertical *</Label>
          <Select
            value={form.watch('companyVertical')}
            onValueChange={(value) => form.setValue('companyVertical', value)}
          >
            <SelectTrigger className={`mt-1 ${theme === 'dark' ? 'bg-zinc-950 border-zinc-800 text-white' : ''}`}>
              <SelectValue placeholder="Select vertical" />
            </SelectTrigger>
            <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
              {VERTICALS.map((vertical) => (
                <SelectItem key={vertical} value={vertical}>
                  {vertical}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          {form.formState.errors.companyVertical && (
            <p className="text-sm text-red-400 mt-1">{String(form.formState.errors.companyVertical.message)}</p>
          )}
        </div>
      </div>

      {/* Business Information */}
      <div className="space-y-4">
        <h3 className={`font-semibold text-lg ${theme === 'dark' ? 'text-white' : ''}`}>Business Information</h3>

        <div className="grid grid-cols-2 gap-4">
          <div>
            <Label htmlFor="interestArea" className={theme === 'dark' ? 'text-gray-300' : ''}>Interest Area *</Label>
            <Select
              value={form.watch('interestArea')}
              onValueChange={(value) => form.setValue('interestArea', value)}
            >
              <SelectTrigger className={`mt-1 ${theme === 'dark' ? 'bg-zinc-950 border-zinc-800 text-white' : ''}`}>
                <SelectValue placeholder="Select interest area" />
              </SelectTrigger>
              <SelectContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white' : ''}>
                {INTEREST_AREAS.map((area) => (
                  <SelectItem key={area} value={area}>
                    {area}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            {form.formState.errors.interestArea && (
              <p className="text-sm text-red-400 mt-1">{String(form.formState.errors.interestArea.message)}</p>
            )}
          </div>

        </div>

        {/* Attendees Section */}
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <Label className={theme === 'dark' ? 'text-gray-300' : ''}>
              Attendees * ({attendees.length} {attendees.length === 1 ? 'person' : 'people'})
            </Label>
            <Button
              type="button"
              onClick={addAttendee}
              variant="outline"
              size="sm"
              className={`${theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}`}
            >
              <Plus className="h-4 w-4 mr-2" />
              Add Person
            </Button>
          </div>

          <div className="space-y-3">
            {attendees.map((attendee, index) => (
              <div key={index} className={`p-4 rounded-lg border ${theme === 'dark' ? 'border-zinc-800 bg-zinc-950' : 'border-gray-200 bg-gray-50'}`}>
                <div className="flex items-start gap-3">
                  <div className="flex-1 space-y-3">
                    <div>
                      <Label htmlFor={`attendee-name-${index}`} className={`text-sm ${theme === 'dark' ? 'text-gray-300' : ''}`}>
                        Full Name *
                      </Label>
                      <Input
                        id={`attendee-name-${index}`}
                        value={attendee.name || ''}
                        onChange={(e) => updateAttendee(index, 'name', e.target.value)}
                        placeholder="John Doe"
                        className="mt-1"
                      />
                    </div>
                    <div>
                      <Label htmlFor={`attendee-position-${index}`} className={`text-sm ${theme === 'dark' ? 'text-gray-300' : ''}`}>
                        Position/Title *
                      </Label>
                      <Input
                        id={`attendee-position-${index}`}
                        value={attendee.position || ''}
                        onChange={(e) => updateAttendee(index, 'position', e.target.value)}
                        placeholder="CTO, VP of Technology, etc."
                        className="mt-1"
                      />
                    </div>
                    <div>
                      <Label htmlFor={`attendee-email-${index}`} className={`text-sm ${theme === 'dark' ? 'text-gray-300' : ''}`}>
                        Email {index === 0 ? '*' : '(Optional)'}
                      </Label>
                      <Input
                        id={`attendee-email-${index}`}
                        type="email"
                        value={attendee.email || ''}
                        onChange={(e) => updateAttendee(index, 'email', e.target.value)}
                        placeholder="john.doe@company.com"
                        className="mt-1"
                        required={index === 0}
                      />
                      {index === 0 && (
                        <p className="text-xs text-gray-500 mt-1">Main contact for this booking</p>
                      )}
                    </div>
                  </div>
                  {attendees.length > 1 && (
                    <Button
                      type="button"
                      onClick={() => removeAttendee(index)}
                      variant="ghost"
                      size="icon"
                      className={`mt-6 flex-shrink-0 ${theme === 'dark' ? 'text-gray-400 hover:text-white hover:bg-zinc-800' : ''}`}
                    >
                      <X className="h-4 w-4" />
                    </Button>
                  )}
                </div>
              </div>
            ))}
          </div>
          {form.formState.errors.attendees && (
            <p className="text-sm text-red-400">{String(form.formState.errors.attendees.message)}</p>
          )}
        </div>

        <div>
          <Label htmlFor="businessGoal" className={theme === 'dark' ? 'text-gray-300' : ''}>Business Goal (Optional)</Label>
          <Textarea
            id="businessGoal"
            {...form.register('businessGoal')}
            className={`mt-1 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}
            rows={3}
          />
        </div>

        <div>
          <Label htmlFor="additionalNotes" className={theme === 'dark' ? 'text-gray-300' : ''}>Additional Notes (Optional)</Label>
          <Textarea
            id="additionalNotes"
            {...form.register('additionalNotes')}
            className={`mt-1 ${theme === 'dark' ? 'bg-black border-zinc-800 text-white' : ''}`}
            rows={3}
          />
        </div>
      </div>

      {/* Actions */}
      <div className="flex justify-end gap-4 pt-2">
        <Button
          type="button"
          variant="outline"
          onClick={onCancel}
          disabled={loading}
          className={theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}
        >
          Cancel
        </Button>
        <Button
          type="submit"
          className={theme === 'dark' ? 'bg-white text-black hover:bg-gray-200' : 'bg-black text-white hover:bg-gray-800'}
          disabled={loading}
        >
          {loading ? 'Creating...' : 'Create Booking'}
        </Button>
      </div>
    </form>
  );
}
