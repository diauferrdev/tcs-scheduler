import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '../lib/api';
import { useTheme } from '../hooks/use-theme';
import { Card } from '../components/ui/card';
import { Skeleton } from '../components/ui/skeleton';
import AccessBadge from '../components/AccessBadge';
import { toast } from 'sonner';

interface Attendee {
  id: string;
  name: string;
  position?: string;
  email?: string;
  booking: {
    id: string;
    date: string;
    startTime: string;
    duration: 'THREE_HOURS' | 'SIX_HOURS';
    companyName: string;
  };
}

export default function AttendeeBadge() {
  const { attendeeId } = useParams<{ attendeeId: string }>();
  const { theme } = useTheme();
  const [attendee, setAttendee] = useState<Attendee | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadAttendee();
  }, [attendeeId]);

  const loadAttendee = async () => {
    if (!attendeeId) return;

    try {
      const response = await api.get(`/api/bookings/attendee/${attendeeId}`);
      setAttendee(response.data);
    } catch (err: any) {
      setError(err.response?.data?.error || 'Attendee not found');
      toast.error('Failed to load badge');
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className={`min-h-screen flex items-center justify-center ${theme === 'dark' ? 'bg-black' : 'bg-gray-50'}`}>
        <Card className={`w-full max-w-2xl p-8 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
          <div className="space-y-4">
            <Skeleton className={`h-32 w-full ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
            <Skeleton className={`h-64 w-full ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
          </div>
        </Card>
      </div>
    );
  }

  if (error || !attendee) {
    return (
      <div className={`min-h-screen flex items-center justify-center ${theme === 'dark' ? 'bg-black' : 'bg-gray-50'}`}>
        <Card className={`w-full max-w-md p-8 text-center ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
          <p className={`text-xl font-semibold mb-2 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
            Badge Not Found
          </p>
          <p className={theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}>
            {error || 'This access badge does not exist.'}
          </p>
        </Card>
      </div>
    );
  }

  return (
    <div className={`min-h-screen py-8 px-4 ${theme === 'dark' ? 'bg-black' : 'bg-gray-50'}`}>
      <div className="max-w-4xl mx-auto">
        <div className="mb-8 text-center">
          <h1 className={`text-3xl font-bold mb-2 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
            TCS PacePort Access Badge
          </h1>
          <p className={theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}>
            {attendee.name} - {attendee.booking.companyName}
          </p>
        </div>

        <div className="flex justify-center">
          <AccessBadge
            attendeeName={attendee.name}
            attendeePosition={attendee.position}
            attendeeId={attendee.id}
            companyName={attendee.booking.companyName}
            date={attendee.booking.date}
            startTime={attendee.booking.startTime}
            duration={attendee.booking.duration}
            bookingId={attendee.booking.id}
            theme={theme}
            showActions={true}
          />
        </div>
      </div>
    </div>
  );
}
