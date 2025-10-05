import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '../lib/api';
import { useTheme } from '../hooks/use-theme';
import { Card } from '../components/ui/card';
import { Skeleton } from '../components/ui/skeleton';
import AccessBadge from '../components/AccessBadge';
import { toast } from 'sonner';

interface Booking {
  id: string;
  date: string;
  startTime: string;
  duration: 'THREE_HOURS' | 'SIX_HOURS';
  companyName: string;
  contactName: string;
  attendees?: Array<{ id: string; name: string; position?: string; email?: string }>;
}

export default function PublicBadge() {
  const { bookingId } = useParams<{ bookingId: string }>();
  const { theme } = useTheme();
  const [booking, setBooking] = useState<Booking | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadBooking();
  }, [bookingId]);

  const loadBooking = async () => {
    if (!bookingId) return;

    try {
      const response = await api.get(`/api/bookings/${bookingId}`);
      setBooking(response.data);
    } catch (err: any) {
      setError(err.response?.data?.error || 'Booking not found');
      toast.error('Failed to load booking');
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

  if (error || !booking) {
    return (
      <div className={`min-h-screen flex items-center justify-center ${theme === 'dark' ? 'bg-black' : 'bg-gray-50'}`}>
        <Card className={`w-full max-w-md p-8 text-center ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
          <p className={`text-xl font-semibold mb-2 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
            Badge Not Found
          </p>
          <p className={theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}>
            {error || 'This booking does not exist or has been cancelled.'}
          </p>
        </Card>
      </div>
    );
  }

  const attendees = booking.attendees || [];

  return (
    <div className={`min-h-screen py-8 px-4 ${theme === 'dark' ? 'bg-black' : 'bg-gray-50'}`}>
      <div className="max-w-4xl mx-auto">
        <div className="mb-8 text-center">
          <h1 className={`text-3xl font-bold mb-2 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
            TCS PacePort Access Badges
          </h1>
          <p className={theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}>
            {booking.companyName} - {attendees.length} visitor{attendees.length !== 1 ? 's' : ''}
          </p>
        </div>

        {attendees.length === 1 ? (
          <div className="flex justify-center">
            <AccessBadge
              attendeeName={attendees[0].name}
              attendeePosition={attendees[0].position}
              attendeeId={attendees[0].id}
              companyName={booking.companyName}
              date={booking.date}
              startTime={booking.startTime}
              duration={booking.duration}
              bookingId={booking.id}
              theme={theme}
              showActions={true}
            />
          </div>
        ) : attendees.length > 1 ? (
          <Carousel className="w-full max-w-md mx-auto">
            <CarouselContent>
              {attendees.map((attendee) => (
                <CarouselItem key={attendee.id}>
                  <AccessBadge
                    attendeeName={attendee.name}
                    attendeePosition={attendee.position}
                    attendeeId={attendee.id}
                    companyName={booking.companyName}
                    date={booking.date}
                    startTime={booking.startTime}
                    duration={booking.duration}
                    bookingId={booking.id}
                    theme={theme}
                    showActions={true}
                  />
                </CarouselItem>
              ))}
            </CarouselContent>
            <CarouselPrevious className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white hover:bg-zinc-800' : ''} />
            <CarouselNext className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white hover:bg-zinc-800' : ''} />
          </Carousel>
        ) : (
          <div className="text-center text-gray-500">
            No attendees found for this booking.
          </div>
        )}
      </div>
    </div>
  );
}
