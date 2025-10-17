import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '@/lib/api';
import { useTheme } from '../hooks/use-theme';
import { Skeleton } from '../components/ui/skeleton';
import { Carousel, CarouselContent, CarouselItem, CarouselPrevious, CarouselNext } from '../components/ui/carousel';
import AccessBadge from '../components/AccessBadge';
import { toast } from 'sonner';
import { motion } from 'framer-motion';
import { ChevronLeft, ChevronRight, Moon, Sun } from 'lucide-react';
import { Button } from '../components/ui/button';

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
  const { theme, toggleTheme } = useTheme();
  const [booking, setBooking] = useState<Booking | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [currentIndex, setCurrentIndex] = useState(0);

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
      <div className={`min-h-screen flex items-center justify-center ${
        theme === 'dark' ? 'bg-black' : 'bg-gray-50'
      }`}>
        <div className="w-full max-w-md mx-auto px-4">
          <Skeleton className={`h-[600px] w-full rounded-2xl ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
        </div>
      </div>
    );
  }

  if (error || !booking) {
    return (
      <div className={`min-h-screen flex items-center justify-center ${
        theme === 'dark' ? 'bg-black' : 'bg-gray-50'
      }`}>
        <motion.div
          initial={{ opacity: 0, scale: 0.95 }}
          animate={{ opacity: 1, scale: 1 }}
          className="text-center px-4"
        >
          <p className={`text-xl font-semibold mb-2 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
            Badge Not Found
          </p>
          <p className={theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}>
            {error || 'This booking does not exist or has been cancelled.'}
          </p>
        </motion.div>
      </div>
    );
  }

  const attendees = booking.attendees || [];

  return (
    <div className={`min-h-screen flex items-center justify-center p-4 relative ${
      theme === 'dark' ? 'bg-black' : 'bg-gray-50'
    }`}>
      {/* Theme Toggle Button - Fixed position */}
      <motion.div
        initial={{ opacity: 0, scale: 0.8 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.5 }}
        className="fixed top-4 right-4 z-50"
      >
        <Button
          onClick={toggleTheme}
          size="icon"
          variant="outline"
          className={`rounded-full w-12 h-12 shadow-lg ${
            theme === 'dark'
              ? 'bg-zinc-900 border-zinc-700 hover:bg-zinc-800'
              : 'bg-white border-gray-300 hover:bg-gray-100'
          }`}
        >
          {theme === 'dark' ? (
            <Sun className="w-5 h-5 text-yellow-500" />
          ) : (
            <Moon className="w-5 h-5 text-gray-700" />
          )}
        </Button>
      </motion.div>

      {attendees.length === 1 ? (
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
          className="w-full max-w-md"
        >
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
            hideCopyLink={true}
          />
        </motion.div>
      ) : attendees.length > 1 ? (
        <div className="w-full max-w-md">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
          >
            {/* Counter */}
            <div className="text-center mb-4">
              <p className={`text-sm font-medium ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                Badge {currentIndex + 1} of {attendees.length}
              </p>
            </div>

            {/* Carousel */}
            <Carousel
              className="w-full px-12"
              opts={{ loop: true }}
            >
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
                      hideCopyLink={true}
                    />
                  </CarouselItem>
                ))}
              </CarouselContent>

              <CarouselPrevious
                className={`left-0 ${
                  theme === 'dark'
                    ? 'bg-zinc-900 border-zinc-800 text-white hover:bg-zinc-800'
                    : 'hover:border-black'
                }`}
                onPointerDown={(e) => e.stopPropagation()}
                onPointerUp={(e) => e.stopPropagation()}
              >
                <ChevronLeft className="w-5 h-5" />
              </CarouselPrevious>

              <CarouselNext
                className={`right-0 ${
                  theme === 'dark'
                    ? 'bg-zinc-900 border-zinc-800 text-white hover:bg-zinc-800'
                    : 'hover:border-black'
                }`}
                onPointerDown={(e) => e.stopPropagation()}
                onPointerUp={(e) => e.stopPropagation()}
              >
                <ChevronRight className="w-5 h-5" />
              </CarouselNext>
            </Carousel>

            {/* Navigation dots */}
            <div className="flex justify-center gap-2 mt-6">
              {attendees.map((_, index) => (
                <button
                  key={index}
                  onClick={() => setCurrentIndex(index)}
                  className={`h-1.5 rounded-full transition-all ${
                    index === currentIndex
                      ? theme === 'dark'
                        ? 'w-6 bg-white'
                        : 'w-6 bg-black'
                      : theme === 'dark'
                        ? 'w-1.5 bg-zinc-700'
                        : 'w-1.5 bg-gray-300'
                  }`}
                />
              ))}
            </div>
          </motion.div>
        </div>
      ) : (
        <div className="text-center">
          <p className={theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}>
            No attendees found for this booking.
          </p>
        </div>
      )}
    </div>
  );
}
