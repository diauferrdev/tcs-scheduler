import { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import { api } from '@/lib/api';
import { cn } from '@/lib/utils';
import { Button } from '../components/ui/button';
import { Card } from '../components/ui/card';
import { Drawer, DrawerContent, DrawerHeader, DrawerTitle } from '../components/ui/drawer';
import { Carousel, CarouselContent, CarouselItem, CarouselNext, CarouselPrevious } from '../components/ui/carousel';
import { AlertDialog, AlertDialogAction, AlertDialogCancel, AlertDialogContent, AlertDialogDescription, AlertDialogFooter, AlertDialogHeader, AlertDialogTitle } from '../components/ui/alert-dialog';
import { format, startOfMonth, endOfMonth, eachDayOfInterval, addMonths, subMonths, isSameMonth, startOfWeek, isSameDay, startOfDay } from 'date-fns';
import { ChevronLeft, ChevronRight, Plus } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { useIsMobile } from '../hooks/use-mobile';
import { useTheme } from '../hooks/use-theme';
import { toast } from 'sonner';
import BookingForm from '../components/BookingForm';
import AccessBadge from '../components/AccessBadge';

interface Booking {
  id: string;
  date: string;
  startTime: string;
  duration: 'THREE_HOURS' | 'SIX_HOURS';
  status: 'PENDING' | 'CONFIRMED' | 'CANCELLED';

  // Company Information
  companyName: string;
  companySector: string;
  companyVertical: string;
  companySize?: string;

  // Contact Information
  contactName: string;
  contactEmail: string;
  contactPhone?: string;
  contactPosition?: string;

  // Business Information
  interestArea: string;
  expectedAttendees: number;
  businessGoal?: string;
  additionalNotes?: string;
  attendees?: Array<{ id: string; name: string; position?: string; email?: string }>;
}

interface DayBookings {
  morning: Booking | null;
  afternoon: Booking | null;
  fullDay: Booking | null;
}

export default function CalendarPage() {
  const isMobile = useIsMobile();
  const { theme } = useTheme();
  const [searchParams, setSearchParams] = useSearchParams();
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [selectedSlot, setSelectedSlot] = useState<'morning' | 'afternoon' | 'full-day' | null>(null);
  const [showBookingForm, setShowBookingForm] = useState(false);
  const [showSlotPicker, setShowSlotPicker] = useState(false);
  const [showDayBookings, setShowDayBookings] = useState(false);
  const [selectedBooking, setSelectedBooking] = useState<Booking | null>(null);
  const [showBookingDetails, setShowBookingDetails] = useState(false);
  const [showCancelDialog, setShowCancelDialog] = useState(false);
  const [, setLoading] = useState(true);
  const [, setDirection] = useState(0);

  const loadBookings = async () => {
    try {
      const response = await api.get('/api/bookings');
      setBookings(response.data.bookings);
    } catch (error) {
      console.error('Failed to load bookings:', error);
      toast.error('Failed to load bookings');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadBookings();
  }, []);

  // Handle notification click - open booking details from URL param
  useEffect(() => {
    const bookingId = searchParams.get('booking');

    if (bookingId && bookings.length > 0) {
      const booking = bookings.find(b => b.id === bookingId);

      if (booking) {
        console.log('📬 Opening booking from notification:', booking.companyName);
        setSelectedBooking(booking);
        setShowBookingDetails(true);

        // Navigate to booking date month
        const bookingDate = new Date(booking.date);
        setCurrentMonth(bookingDate);

        // Clear the booking parameter from URL
        searchParams.delete('booking');
        setSearchParams(searchParams);
      } else {
        console.warn('⚠️ Booking not found:', bookingId);
        toast.error('Booking not found');
        searchParams.delete('booking');
        setSearchParams(searchParams);
      }
    }
  }, [bookings, searchParams, setSearchParams]);

  const getBookingsForDay = (date: Date): DayBookings => {
    const dateStr = format(date, 'yyyy-MM-dd');
    const dayBookings = bookings.filter(b => {
      // Handle both ISO string format and yyyy-MM-dd format
      const bookingDate = b.date.includes('T') ? b.date.split('T')[0] : b.date;
      return bookingDate === dateStr && b.status !== 'CANCELLED';
    });

    const fullDayBooking = dayBookings.find(b => b.duration === 'SIX_HOURS');
    if (fullDayBooking) {
      return {
        morning: null,
        afternoon: null,
        fullDay: fullDayBooking,
      };
    }

    const morningBooking = dayBookings.find(b => b.startTime === '09:00');
    const afternoonBooking = dayBookings.find(b => b.startTime === '14:00');

    return {
      morning: morningBooking || null,
      afternoon: afternoonBooking || null,
      fullDay: null,
    };
  };

  const handleDayClick = (date: Date, isCurrentMonth: boolean, hasBookings: boolean) => {
    // Check if it's a past date
    const today = startOfDay(new Date());
    if (startOfDay(date) < today) return;

    // If clicking on a different month, navigate to that month first
    if (!isCurrentMonth) {
      setCurrentMonth(date);
      // Wait for month change animation, then open appropriate drawer
      setTimeout(() => {
        setSelectedDate(date);
        if (hasBookings) {
          setShowDayBookings(true);
        } else {
          setShowSlotPicker(true);
        }
      }, 300);
    } else {
      setSelectedDate(date);
      if (hasBookings) {
        setShowDayBookings(true);
      } else {
        setShowSlotPicker(true);
      }
    }
  };

  const handleBookingClick = (e: React.MouseEvent, booking: Booking) => {
    e.stopPropagation();
    setSelectedBooking(booking);
    setShowBookingDetails(true);
  };

  const handleSlotSelect = (slot: 'morning' | 'afternoon' | 'full-day') => {
    setSelectedSlot(slot);
    setShowSlotPicker(false);
    setShowDayBookings(false);
    setShowBookingForm(true);
  };

  const handleCancelBooking = async () => {
    if (!selectedBooking) return;

    try {
      await api.delete(`/api/bookings/${selectedBooking.id}`);
      toast.success('Booking cancelled successfully');
      setShowCancelDialog(false);
      setShowBookingDetails(false);
      loadBookings();
    } catch (error: any) {
      toast.error(error.response?.data?.error || 'Failed to cancel booking');
    }
  };

  const getDayGradient = (day: Date, isCurrentMonth: boolean, isPast: boolean, theme: 'light' | 'dark') => {
    // Gray out ALL past dates (regardless of current month)
    if (isPast) {
      return theme === 'dark' ? 'bg-zinc-950' : 'bg-gray-200/50';
    }

    const dayBookings = getBookingsForDay(day);
    const hasFullDay = !!dayBookings.fullDay;
    const hasMorning = !!dayBookings.morning;
    const hasAfternoon = !!dayBookings.afternoon;

    // Fully booked - Red gradient
    if (hasFullDay || (hasMorning && hasAfternoon)) {
      return theme === 'dark'
        ? 'bg-gradient-to-br from-red-950/40 via-red-900/30 to-red-800/20'
        : 'bg-gradient-to-br from-red-100 via-red-200 to-red-300';
    }

    // Partially booked - Yellow gradient
    if (hasMorning || hasAfternoon) {
      return theme === 'dark'
        ? 'bg-gradient-to-br from-yellow-900/60 via-yellow-800/50 to-yellow-700/40'
        : 'bg-gradient-to-br from-yellow-100 via-yellow-200 to-yellow-300';
    }

    // Available - Green gradient
    return theme === 'dark'
      ? 'bg-gradient-to-br from-green-950/40 via-green-900/30 to-green-800/20'
      : 'bg-gradient-to-br from-green-100 via-green-200 to-green-300';
  };

  const getAvailableSlots = (date: Date): Array<'morning' | 'afternoon' | 'full-day'> => {
    const dayBookings = getBookingsForDay(date);
    const slots: Array<'morning' | 'afternoon' | 'full-day'> = [];

    if (!dayBookings.fullDay && !dayBookings.morning) {
      slots.push('morning');
    }
    if (!dayBookings.fullDay && !dayBookings.afternoon) {
      slots.push('afternoon');
    }
    if (!dayBookings.morning && !dayBookings.afternoon && !dayBookings.fullDay) {
      slots.push('full-day');
    }

    return slots;
  };

  const monthStart = startOfMonth(currentMonth);
  const monthEnd = endOfMonth(currentMonth);

  // Limit to max 3 days from next month
  let calendarEnd = new Date(monthEnd);
  calendarEnd.setDate(monthEnd.getDate() + 3);

  // Start from beginning of week containing month start
  let calendarStart = startOfWeek(monthStart);

  // Build initial calendar array
  let calendarDays = eachDayOfInterval({ start: calendarStart, end: calendarEnd });

  // If we have less than 35 days, add days from previous month at the start
  if (calendarDays.length < 35) {
    const daysToAdd = 35 - calendarDays.length;
    const firstDay = calendarDays[0];
    const previousDays = [];

    for (let i = daysToAdd; i > 0; i--) {
      const newDate = new Date(firstDay);
      newDate.setDate(firstDay.getDate() - i);
      previousDays.push(newDate);
    }

    calendarDays = [...previousDays, ...calendarDays];
  } else if (calendarDays.length > 35) {
    // Trim to exactly 35 days
    calendarDays = calendarDays.slice(0, 35);
  }

  const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  return (
    <motion.div
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -10 }}
      transition={{ duration: 0.2, ease: 'easeInOut' }}
      className={`w-full max-w-full px-4 sm:px-6 lg:px-8 py-4 sm:py-6 flex flex-col overflow-hidden ${
        isMobile ? 'h-full' : 'h-[calc(100vh-80px)]'
      }`}
    >
      <div className="w-full max-w-full flex-1 flex flex-col overflow-hidden">
        {/* Month Navigation */}
        <div className="flex flex-col sm:flex-row items-center justify-between mb-3 sm:mb-4 gap-2 sm:gap-4 flex-shrink-0">
          <div className="flex items-center gap-2 sm:gap-4">
            <Button
              variant="outline"
              size={isMobile ? "sm" : "icon"}
              onClick={() => {
                setDirection(-1);
                setCurrentMonth(subMonths(currentMonth, 1));
              }}
              className={`transition-all duration-200 hover:scale-110 hover:shadow-md ${
                theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''
              }`}
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
            <h2 className={`text-xl sm:text-3xl font-bold min-w-[180px] sm:min-w-[200px] text-center transition-all duration-300 ${
              theme === 'dark' ? 'text-white' : 'text-black'
            }`}>
              {format(currentMonth, 'MMMM yyyy')}
            </h2>
            <Button
              variant="outline"
              size={isMobile ? "sm" : "icon"}
              onClick={() => {
                setDirection(1);
                setCurrentMonth(addMonths(currentMonth, 1));
              }}
              className={`transition-all duration-200 hover:scale-110 hover:shadow-md ${
                theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''
              }`}
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>

          {/* Desktop Legend */}
          {!isMobile && (
            <div className="flex items-center gap-3 sm:gap-4">
              <div className="flex items-center gap-1.5 text-xs sm:text-sm">
                <div className={`w-4 h-4 sm:w-5 sm:h-5 rounded ${
                  theme === 'dark'
                    ? 'bg-gradient-to-br from-green-950/40 via-green-900/30 to-green-800/20 border border-green-900'
                    : 'bg-gradient-to-br from-green-100 via-green-200 to-green-300 border border-green-400'
                }`}></div>
                <span className={theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}>Available</span>
              </div>
              <div className="flex items-center gap-1.5 text-xs sm:text-sm">
                <div className={`w-4 h-4 sm:w-5 sm:h-5 rounded ${
                  theme === 'dark'
                    ? 'bg-gradient-to-br from-yellow-900/60 via-yellow-800/50 to-yellow-700/40 border border-yellow-800'
                    : 'bg-gradient-to-br from-yellow-100 via-yellow-200 to-yellow-300 border border-yellow-400'
                }`}></div>
                <span className={theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}>Partial</span>
              </div>
              <div className="flex items-center gap-1.5 text-xs sm:text-sm">
                <div className={`w-4 h-4 sm:w-5 sm:h-5 rounded ${
                  theme === 'dark'
                    ? 'bg-gradient-to-br from-red-950/40 via-red-900/30 to-red-800/20 border border-red-900'
                    : 'bg-gradient-to-br from-red-100 via-red-200 to-red-300 border border-red-400'
                }`}></div>
                <span className={theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}>Full</span>
              </div>
              <div className="flex items-center gap-1.5 text-xs sm:text-sm">
                <div className={`w-4 h-4 sm:w-5 sm:h-5 rounded ${
                  theme === 'dark' ? 'bg-zinc-950 border border-zinc-800' : 'bg-gray-300 border border-gray-400'
                }`}></div>
                <span className={theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}>Past</span>
              </div>
            </div>
          )}
        </div>

        {/* Calendar Grid */}
        <Card className={`p-2 sm:p-3 overflow-hidden flex-1 flex flex-col min-h-0 ${
          theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''
        }`}>
          {/* Week days header */}
          <div className="grid grid-cols-7 gap-1 sm:gap-2 mb-1 flex-shrink-0">
            {weekDays.map(day => (
              <div key={day} className="text-center font-semibold text-xs text-gray-500 py-1">
                {day}
              </div>
            ))}
          </div>

          {/* Calendar days */}
          <div className="overflow-hidden flex-1 flex flex-col min-h-0">
            <AnimatePresence mode="wait" initial={false}>
              <motion.div
                key={`${format(currentMonth, 'yyyy-MM')}-${theme}`}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                transition={{ duration: 0.15 }}
                className="grid grid-cols-7 gap-1 sm:gap-2 flex-1"
                style={{
                  display: 'grid',
                  gridTemplateRows: 'repeat(5, 1fr)',
                  maxHeight: '100%'
                }}
              >
              {calendarDays.map((day, idx) => {
                const isCurrentMonth = isSameMonth(day, currentMonth);
                const isToday = isSameDay(day, new Date());
                const today = startOfDay(new Date());
                const isPast = startOfDay(day) < today;
                const isClickable = !isPast;
                const dayBookings = getBookingsForDay(day);
                const hasAnyBooking = dayBookings.morning || dayBookings.afternoon || dayBookings.fullDay;
                const availableSlots = getAvailableSlots(day);

                return (
                  <motion.button
                    key={idx}
                    initial={{ opacity: 0, y: 20, scale: 0.95 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    transition={{
                      delay: idx * 0.015,
                      duration: 0.3,
                      ease: [0.25, 0.46, 0.45, 0.94]
                    }}
                    onClick={() => {
                      if (!isClickable) return;
                      handleDayClick(day, isCurrentMonth, !!hasAnyBooking);
                    }}
                    disabled={!isClickable && isPast}
                    className={`
                      group h-full border rounded p-1.5 text-left relative
                      transition-all duration-200 ease-out
                      ${getDayGradient(day, isCurrentMonth, isPast, theme)}
                      ${isPast ? 'cursor-not-allowed opacity-40' : ''}
                      ${!isCurrentMonth ? 'opacity-60' : ''}
                      ${isToday
                        ? theme === 'dark' ? 'border-2 border-white shadow-md' : 'border-2 border-black shadow-md'
                        : theme === 'dark' ? 'border-zinc-800' : 'border-gray-300'
                      }
                      ${isClickable
                        ? theme === 'dark'
                          ? 'hover:border-white hover:shadow-lg hover:-translate-y-0.5 cursor-pointer'
                          : 'hover:border-black hover:shadow-lg hover:-translate-y-0.5 cursor-pointer'
                        : ''
                      }
                    `}
                  >
                  {/* Day number - positioned at top left */}
                  <div className="absolute -top-1 left-1.5">
                    <span className={`text-[10px] font-bold inline-flex items-center justify-center transition-all duration-200 ${
                      isToday
                        ? theme === 'dark'
                          ? 'bg-white text-black w-4 h-4 rounded-full'
                          : 'bg-black text-white w-4 h-4 rounded-full'
                        : !isCurrentMonth || isPast
                          ? 'text-gray-500'
                          : theme === 'dark'
                            ? 'text-gray-300'
                            : 'text-gray-700'
                    }`}>
                      {format(day, 'd')}
                    </span>
                  </div>

                  {/* Bookings - only show for non-past days */}
                  {!isPast && (
                    <div className="pt-3 space-y-0.5">
                      {/* Full Day Booking */}
                      {dayBookings.fullDay && (
                        <div
                          onClick={(e) => handleBookingClick(e, dayBookings.fullDay!)}
                          className={`px-1.5 py-1 rounded ${isMobile ? 'text-[8px]' : 'text-[9px]'} leading-tight cursor-pointer transition-all duration-150 hover:scale-105 ${
                            theme === 'dark'
                              ? 'bg-zinc-800 text-gray-300 hover:bg-zinc-700 border border-zinc-700'
                              : 'bg-white text-black hover:bg-gray-50 border border-gray-300'
                          }`}
                        >
                          <div className="font-semibold truncate">{dayBookings.fullDay.companyName}</div>
                          <div className={`${isMobile ? 'text-[7px]' : 'text-[8px]'} ${theme === 'dark' ? 'opacity-60' : 'opacity-70'}`}>Full Day</div>
                        </div>
                      )}

                      {/* Morning Booking */}
                      {!dayBookings.fullDay && dayBookings.morning && (
                        <div
                          onClick={(e) => handleBookingClick(e, dayBookings.morning!)}
                          className={`px-1.5 py-1 rounded ${isMobile ? 'text-[8px]' : 'text-[9px]'} leading-tight cursor-pointer transition-all duration-150 hover:scale-105 ${
                            theme === 'dark'
                              ? 'bg-zinc-800 text-gray-300 hover:bg-zinc-700 border border-zinc-700'
                              : 'bg-white text-black hover:bg-gray-50 border border-gray-300'
                          }`}
                        >
                          <div className="font-semibold truncate">{dayBookings.morning.companyName}</div>
                          <div className={`${isMobile ? 'text-[7px]' : 'text-[8px]'} ${theme === 'dark' ? 'opacity-60' : 'opacity-70'}`}>09:00</div>
                        </div>
                      )}

                      {/* Afternoon Booking */}
                      {!dayBookings.fullDay && dayBookings.afternoon && (
                        <div
                          onClick={(e) => handleBookingClick(e, dayBookings.afternoon!)}
                          className={`px-1.5 py-1 rounded ${isMobile ? 'text-[8px]' : 'text-[9px]'} leading-tight cursor-pointer transition-all duration-150 hover:scale-105 ${
                            theme === 'dark'
                              ? 'bg-zinc-800 text-gray-300 hover:bg-zinc-700 border border-zinc-700'
                              : 'bg-white text-black hover:bg-gray-50 border border-gray-300'
                          }`}
                        >
                          <div className="font-semibold truncate">{dayBookings.afternoon.companyName}</div>
                          <div className={`${isMobile ? 'text-[7px]' : 'text-[8px]'} ${theme === 'dark' ? 'opacity-60' : 'opacity-70'}`}>14:00</div>
                        </div>
                      )}
                    </div>
                  )}

                  {/* Show + icon when there are available slots */}
                  {!isPast && availableSlots.length > 0 && (
                    <div className="absolute bottom-1 right-1">
                      <Plus className={`${isMobile ? 'w-3 h-3' : 'w-4 h-4'} transition-all duration-300 ease-out ${
                        theme === 'dark'
                          ? 'text-zinc-700 group-hover:text-white group-hover:scale-125'
                          : 'text-gray-400 group-hover:text-black group-hover:scale-125'
                      }`} />
                    </div>
                  )}

                  {/* Show "Full" indicator when no slots available */}
                  {!isPast && availableSlots.length === 0 && !hasAnyBooking && (
                    <div className="absolute inset-0 flex items-center justify-center">
                      <span className={`text-[10px] font-semibold ${
                        theme === 'dark' ? 'text-zinc-700' : 'text-gray-400'
                      }`}>FULL</span>
                    </div>
                  )}

                  {/* Past overlay */}
                  {isPast && (
                    <div className="absolute inset-0 flex items-center justify-center">
                      <span className="text-[9px] text-gray-500 italic">Past</span>
                    </div>
                  )}
                </motion.button>
              );
            })}
            </motion.div>
          </AnimatePresence>
          </div>
        </Card>

        {/* Mobile Legend - Only visible on mobile */}
        {isMobile && (
          <div className="mt-2 flex flex-wrap items-center justify-center gap-2 flex-shrink-0">
            <div className="flex items-center gap-1.5 text-xs">
              <div className={`w-4 h-4 rounded ${
                theme === 'dark'
                  ? 'bg-gradient-to-br from-green-950/40 via-green-900/30 to-green-800/20 border border-green-900'
                  : 'bg-gradient-to-br from-green-100 via-green-200 to-green-300 border border-green-400'
              }`}></div>
              <span className={theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}>Available</span>
            </div>
            <div className="flex items-center gap-1.5 text-xs">
              <div className={`w-4 h-4 rounded ${
                theme === 'dark'
                  ? 'bg-gradient-to-br from-yellow-900/60 via-yellow-800/50 to-yellow-700/40 border border-yellow-800'
                  : 'bg-gradient-to-br from-yellow-100 via-yellow-200 to-yellow-300 border border-yellow-400'
              }`}></div>
              <span className={theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}>Partial</span>
            </div>
            <div className="flex items-center gap-1.5 text-xs">
              <div className={`w-4 h-4 rounded ${
                theme === 'dark'
                  ? 'bg-gradient-to-br from-red-950/40 via-red-900/30 to-red-800/20 border border-red-900'
                  : 'bg-gradient-to-br from-red-100 via-red-200 to-red-300 border border-red-400'
              }`}></div>
              <span className={theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}>Full</span>
            </div>
            <div className="flex items-center gap-1.5 text-xs">
              <div className={`w-4 h-4 rounded ${
                theme === 'dark' ? 'bg-zinc-950 border border-zinc-800' : 'bg-gray-300 border border-gray-400'
              }`}></div>
              <span className={theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}>Past</span>
            </div>
          </div>
        )}

        {/* Day Bookings Drawer - Shows existing bookings and option to add new */}
        <Drawer open={showDayBookings} onOpenChange={setShowDayBookings} direction={isMobile ? 'bottom' : 'right'}>
        <DrawerContent className={`${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''} ${isMobile ? 'min-h-[60vh]' : ''}`}>
          <DrawerHeader>
            <DrawerTitle className={`text-xl ${theme === 'dark' ? 'text-white' : ''}`}>
              {selectedDate && format(selectedDate, 'MMMM d, yyyy')}
            </DrawerTitle>
            <p className={`text-sm mt-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
              Bookings and available slots
            </p>
          </DrawerHeader>
          <div className="space-y-3 p-4 overflow-auto">
            {selectedDate && (() => {
              const dayBookings = getBookingsForDay(selectedDate);
              const availableSlots = getAvailableSlots(selectedDate);

              return (
                <>
                  {/* Existing Bookings */}
                  {(dayBookings.fullDay || dayBookings.morning || dayBookings.afternoon) && (
                    <div className="space-y-2 mb-4">
                      <h3 className={`text-sm font-semibold ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                        Existing Bookings
                      </h3>

                      {dayBookings.fullDay && (
                        <motion.button
                          initial={{ opacity: 0, y: 20 }}
                          animate={{ opacity: 1, y: 0 }}
                          onClick={() => {
                            setSelectedBooking(dayBookings.fullDay!);
                            setShowDayBookings(false);
                            setShowBookingDetails(true);
                          }}
                          className={`w-full p-4 text-left border-2 rounded-lg hover:shadow-md hover:scale-105 transition-all duration-200 ease-out ${
                            theme === 'dark'
                              ? 'border-zinc-800 bg-zinc-950 text-white hover:border-white hover:bg-zinc-900'
                              : 'border-gray-200 hover:border-black hover:bg-gray-50'
                          }`}
                        >
                          <div className={`font-semibold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                            {dayBookings.fullDay.companyName}
                          </div>
                          <div className={`text-sm mt-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                            Full Day (09:00 - 17:00)
                          </div>
                        </motion.button>
                      )}

                      {!dayBookings.fullDay && dayBookings.morning && (
                        <motion.button
                          initial={{ opacity: 0, y: 20 }}
                          animate={{ opacity: 1, y: 0 }}
                          onClick={() => {
                            setSelectedBooking(dayBookings.morning!);
                            setShowDayBookings(false);
                            setShowBookingDetails(true);
                          }}
                          className={`w-full p-4 text-left border-2 rounded-lg hover:shadow-md hover:scale-105 transition-all duration-200 ease-out ${
                            theme === 'dark'
                              ? 'border-zinc-800 bg-zinc-950 text-white hover:border-white hover:bg-zinc-900'
                              : 'border-gray-200 hover:border-black hover:bg-gray-50'
                          }`}
                        >
                          <div className={`font-semibold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                            {dayBookings.morning.companyName}
                          </div>
                          <div className={`text-sm mt-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                            Morning (09:00 - 12:00)
                          </div>
                        </motion.button>
                      )}

                      {!dayBookings.fullDay && dayBookings.afternoon && (
                        <motion.button
                          initial={{ opacity: 0, y: 20 }}
                          animate={{ opacity: 1, y: 0 }}
                          transition={{ delay: dayBookings.morning ? 0.1 : 0 }}
                          onClick={() => {
                            setSelectedBooking(dayBookings.afternoon!);
                            setShowDayBookings(false);
                            setShowBookingDetails(true);
                          }}
                          className={`w-full p-4 text-left border-2 rounded-lg hover:shadow-md hover:scale-105 transition-all duration-200 ease-out ${
                            theme === 'dark'
                              ? 'border-zinc-800 bg-zinc-950 text-white hover:border-white hover:bg-zinc-900'
                              : 'border-gray-200 hover:border-black hover:bg-gray-50'
                          }`}
                        >
                          <div className={`font-semibold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                            {dayBookings.afternoon.companyName}
                          </div>
                          <div className={`text-sm mt-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                            Afternoon (14:00 - 17:00)
                          </div>
                        </motion.button>
                      )}
                    </div>
                  )}

                  {/* Available Slots */}
                  {availableSlots.length > 0 && (
                    <div className="space-y-2">
                      <h3 className={`text-sm font-semibold ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                        Available Slots
                      </h3>
                      {availableSlots.map((slot, idx) => (
                        <motion.button
                          key={slot}
                          initial={{ opacity: 0, y: 20 }}
                          animate={{ opacity: 1, y: 0 }}
                          transition={{ delay: idx * 0.1, duration: 0.3, ease: 'easeOut' }}
                          onClick={() => handleSlotSelect(slot)}
                          className={`w-full p-4 text-left border-2 rounded-lg hover:shadow-md hover:scale-105 transition-all duration-200 ease-out ${
                            theme === 'dark'
                              ? 'border-zinc-800 bg-zinc-950 text-white hover:border-white hover:bg-zinc-900'
                              : 'border-gray-200 hover:border-black hover:bg-gray-50'
                          }`}
                        >
                          <div className={`font-semibold flex items-center gap-2 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                            <Plus className="w-4 h-4" />
                            {slot === 'morning' && 'Add Morning Session'}
                            {slot === 'afternoon' && 'Add Afternoon Session'}
                            {slot === 'full-day' && 'Add Full Day'}
                          </div>
                          <div className={`text-sm mt-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                            {slot === 'morning' && '09:00 - 12:00 (3 hours)'}
                            {slot === 'afternoon' && '14:00 - 17:00 (3 hours)'}
                            {slot === 'full-day' && '09:00 - 17:00 (6 hours)'}
                          </div>
                        </motion.button>
                      ))}
                    </div>
                  )}

                  {availableSlots.length === 0 && !dayBookings.fullDay && !dayBookings.morning && !dayBookings.afternoon && (
                    <div className={`text-center py-8 ${theme === 'dark' ? 'text-gray-500' : 'text-gray-400'}`}>
                      No available slots for this day
                    </div>
                  )}
                </>
              );
            })()}
          </div>
        </DrawerContent>
      </Drawer>

      {/* Slot Picker Drawer */}
      <Drawer open={showSlotPicker} onOpenChange={setShowSlotPicker} direction={isMobile ? 'bottom' : 'right'}>
        <DrawerContent className={`${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''} ${isMobile ? 'min-h-[60vh]' : ''}`}>
          <DrawerHeader>
            <DrawerTitle className={`text-xl ${theme === 'dark' ? 'text-white' : ''}`}>
              Select Time Slot - {selectedDate && format(selectedDate, 'MMMM d, yyyy')}
            </DrawerTitle>
          </DrawerHeader>
          <div className="space-y-3 p-4 overflow-auto">
            {selectedDate && getAvailableSlots(selectedDate).map((slot, idx) => (
              <motion.button
                key={slot}
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: idx * 0.1, duration: 0.3, ease: 'easeOut' }}
                onClick={() => handleSlotSelect(slot)}
                className={`w-full p-4 text-left border-2 rounded-lg hover:shadow-md hover:scale-105 transition-all duration-200 ease-out ${
                  theme === 'dark'
                    ? 'border-zinc-800 bg-zinc-950 text-white hover:border-white hover:bg-zinc-900'
                    : 'border-gray-200 hover:border-black hover:bg-gray-50'
                }`}
              >
                <div className={`font-semibold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                  {slot === 'morning' && 'Morning Session'}
                  {slot === 'afternoon' && 'Afternoon Session'}
                  {slot === 'full-day' && 'Full Day'}
                </div>
                <div className={`text-sm mt-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                  {slot === 'morning' && '09:00 - 12:00 (3 hours)'}
                  {slot === 'afternoon' && '14:00 - 17:00 (3 hours)'}
                  {slot === 'full-day' && '09:00 - 17:00 (6 hours)'}
                </div>
              </motion.button>
            ))}
          </div>
        </DrawerContent>
      </Drawer>

      {/* Booking Details Drawer */}
      <Drawer open={showBookingDetails} onOpenChange={setShowBookingDetails} direction={isMobile ? 'bottom' : 'right'}>
        <DrawerContent className={`${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''} ${isMobile ? 'min-h-[85vh]' : ''}`}>
          <DrawerHeader>
            <DrawerTitle className={`text-xl ${theme === 'dark' ? 'text-white' : ''}`}>Booking Details</DrawerTitle>
          </DrawerHeader>
          {selectedBooking && (
            <div className="space-y-4 p-4 overflow-auto">
              {/* Date & Time */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Date</div>
                  <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{format(new Date(selectedBooking.date), 'MMMM d, yyyy')}</div>
                </div>
                <div>
                  <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Time</div>
                  <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>
                    {selectedBooking.duration === 'SIX_HOURS'
                      ? 'Full Day (09:00-17:00)'
                      : selectedBooking.startTime === '09:00'
                        ? 'Morning (09:00-12:00)'
                        : 'Afternoon (14:00-17:00)'}
                  </div>
                </div>
              </div>

              {/* Status */}
              <div>
                <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Status</div>
                <div className={`inline-block px-2 py-1 rounded text-xs font-semibold ${
                  selectedBooking.status === 'CONFIRMED'
                    ? theme === 'dark' ? 'bg-zinc-800 text-green-400 border border-zinc-700' : 'bg-green-100 text-green-800'
                    : selectedBooking.status === 'PENDING'
                      ? theme === 'dark' ? 'bg-zinc-800 text-yellow-400 border border-zinc-700' : 'bg-yellow-100 text-yellow-800'
                      : theme === 'dark' ? 'bg-zinc-800 text-gray-400 border border-zinc-700' : 'bg-gray-100 text-gray-800'
                }`}>
                  {selectedBooking.status}
                </div>
              </div>

              {/* Divider */}
              <div className={`border-t ${theme === 'dark' ? 'border-zinc-800' : 'border-gray-200'}`}></div>

              {/* Company Information */}
              <div>
                <h3 className={`text-lg font-bold mb-3 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>Company Information</h3>
                <div className="space-y-3">
                  <div>
                    <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Company Name</div>
                    <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{selectedBooking.companyName}</div>
                  </div>
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Sector</div>
                      <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{selectedBooking.companySector}</div>
                    </div>
                    <div>
                      <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Vertical</div>
                      <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{selectedBooking.companyVertical}</div>
                    </div>
                  </div>
                  {selectedBooking.companySize && (
                    <div>
                      <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Company Size</div>
                      <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{selectedBooking.companySize}</div>
                    </div>
                  )}
                </div>
              </div>

              {/* Divider */}
              <div className={`border-t ${theme === 'dark' ? 'border-zinc-800' : 'border-gray-200'}`}></div>

              {/* Contact Information */}
              <div>
                <h3 className={`text-lg font-bold mb-3 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>Contact Information</h3>
                <div className="space-y-3">
                  <div>
                    <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Name</div>
                    <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{selectedBooking.contactName}</div>
                  </div>
                  <div>
                    <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Email</div>
                    <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{selectedBooking.contactEmail}</div>
                  </div>
                  {selectedBooking.contactPhone && (
                    <div>
                      <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Phone</div>
                      <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{selectedBooking.contactPhone}</div>
                    </div>
                  )}
                  {selectedBooking.contactPosition && (
                    <div>
                      <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Position</div>
                      <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{selectedBooking.contactPosition}</div>
                    </div>
                  )}
                </div>
              </div>

              {/* Divider */}
              <div className={`border-t ${theme === 'dark' ? 'border-zinc-800' : 'border-gray-200'}`}></div>

              {/* Business Information */}
              <div>
                <h3 className={`text-lg font-bold mb-3 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>Visit Details</h3>
                <div className="space-y-3">
                  <div>
                    <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Interest Area</div>
                    <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{selectedBooking.interestArea}</div>
                  </div>
                  <div>
                    <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Expected Attendees</div>
                    <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{selectedBooking.expectedAttendees} {selectedBooking.expectedAttendees === 1 ? 'person' : 'people'}</div>
                  </div>
                  {selectedBooking.businessGoal && (
                    <div>
                      <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Business Goal</div>
                      <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{selectedBooking.businessGoal}</div>
                    </div>
                  )}
                  {selectedBooking.additionalNotes && (
                    <div>
                      <div className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-500'}`}>Additional Notes</div>
                      <div className={`text-base ${theme === 'dark' ? 'text-gray-300' : ''}`}>{selectedBooking.additionalNotes}</div>
                    </div>
                  )}
                </div>
              </div>

              {/* Divider */}
              <div className={`border-t ${theme === 'dark' ? 'border-zinc-800' : 'border-gray-200'}`}></div>

              {/* Access Badges */}
              <div>
                <h3 className={`text-lg font-bold mb-3 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                  Access Badges
                </h3>
                <p className={`text-sm mb-4 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                  Digital access badges for all visitors ({selectedBooking.attendees?.length || 0} {(selectedBooking.attendees?.length || 0) === 1 ? 'person' : 'people'})
                </p>
                {(() => {
                  const attendees = selectedBooking.attendees || [];

                  if (attendees.length === 1) {
                    return (
                      <div className="w-full overflow-x-hidden">
                        <AccessBadge
                          attendeeName={attendees[0].name}
                          attendeePosition={attendees[0].position}
                          attendeeId={attendees[0].id}
                          companyName={selectedBooking.companyName}
                          date={selectedBooking.date}
                          startTime={selectedBooking.startTime}
                          duration={selectedBooking.duration}
                          bookingId={selectedBooking.id}
                          theme={theme}
                          showActions={true}
                        />
                      </div>
                    );
                  }

                  return (
                    <Carousel className="w-full px-4 md:px-12">
                      <CarouselContent>
                        {(selectedBooking.attendees || []).map((attendee) => (
                          <CarouselItem key={attendee.id}>
                            <AccessBadge
                              attendeeName={attendee.name}
                              attendeePosition={attendee.position}
                              attendeeId={attendee.id}
                              companyName={selectedBooking.companyName}
                              date={selectedBooking.date}
                              startTime={selectedBooking.startTime}
                              duration={selectedBooking.duration}
                              bookingId={selectedBooking.id}
                              theme={theme}
                              showActions={true}
                            />
                          </CarouselItem>
                        ))}
                      </CarouselContent>
                      <CarouselPrevious
                        className={cn(
                          'left-0',
                          theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white hover:bg-zinc-800' : ''
                        )}
                        onPointerDown={(e) => e.stopPropagation()}
                        onPointerUp={(e) => e.stopPropagation()}
                      />
                      <CarouselNext
                        className={cn(
                          'right-0',
                          theme === 'dark' ? 'bg-zinc-900 border-zinc-800 text-white hover:bg-zinc-800' : ''
                        )}
                        onPointerDown={(e) => e.stopPropagation()}
                        onPointerUp={(e) => e.stopPropagation()}
                      />
                    </Carousel>
                  );
                })()}
              </div>

              {/* Cancel Button - Only show if not already cancelled */}
              {selectedBooking.status !== 'CANCELLED' && (
                <div className={`pt-4 border-t ${theme === 'dark' ? 'border-zinc-800' : 'border-gray-200'}`}>
                  <Button
                    onClick={() => setShowCancelDialog(true)}
                    variant="outline"
                    className={`w-full ${
                      theme === 'dark'
                        ? 'border-red-800 bg-red-950 text-red-400 hover:bg-red-900 hover:text-red-300'
                        : 'border-red-600 text-red-600 hover:bg-red-50'
                    }`}
                  >
                    Cancel Booking
                  </Button>
                </div>
              )}
            </div>
          )}
        </DrawerContent>
      </Drawer>

      {/* Booking Form Drawer */}
      <Drawer open={showBookingForm} onOpenChange={setShowBookingForm} direction={isMobile ? 'bottom' : 'right'}>
        <DrawerContent className={`${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''} ${isMobile ? 'min-h-[80vh]' : ''}`}>
          <DrawerHeader>
            <DrawerTitle className={`text-xl ${theme === 'dark' ? 'text-white' : ''}`}>
              New Booking - {selectedDate && format(selectedDate, 'MMMM d, yyyy')}
            </DrawerTitle>
            <p className={`text-sm mt-1 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
              {selectedSlot === 'morning' && 'Morning Session (09:00-12:00)'}
              {selectedSlot === 'afternoon' && 'Afternoon Session (14:00-17:00)'}
              {selectedSlot === 'full-day' && 'Full Day (09:00-17:00)'}
            </p>
          </DrawerHeader>
          <div className="p-4 overflow-auto">
            <BookingForm
              initialDate={selectedDate ? format(selectedDate, 'yyyy-MM-dd') : undefined}
              initialSlot={selectedSlot || undefined}
              theme={theme}
              onSuccess={async (booking) => {
                setShowBookingForm(false);
                toast.success('Booking created successfully!');

                // Wait for bookings to reload before opening details
                await loadBookings();

                // Open booking details drawer with the newly created booking
                setSelectedBooking(booking);
                setShowBookingDetails(true);
              }}
              onCancel={() => setShowBookingForm(false)}
            />
          </div>
        </DrawerContent>
      </Drawer>

      {/* Cancel Booking Confirmation Dialog */}
      <AlertDialog open={showCancelDialog} onOpenChange={setShowCancelDialog}>
        <AlertDialogContent className={theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}>
          <AlertDialogHeader>
            <AlertDialogTitle className={theme === 'dark' ? 'text-white' : ''}>
              Cancel Booking
            </AlertDialogTitle>
            <AlertDialogDescription className={theme === 'dark' ? 'text-gray-400' : ''}>
              Are you sure you want to cancel this booking? This action cannot be undone.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel className={theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}>
              No, keep it
            </AlertDialogCancel>
            <AlertDialogAction
              onClick={handleCancelBooking}
              className={
                theme === 'dark'
                  ? 'bg-red-950 text-red-400 hover:bg-red-900 border border-red-800'
                  : 'bg-red-600 text-white hover:bg-red-700'
              }
            >
              Yes, cancel booking
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </div>
    </motion.div>
  );
}
