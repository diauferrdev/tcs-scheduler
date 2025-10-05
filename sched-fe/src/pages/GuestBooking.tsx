import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '../lib/api';
import { Card } from '../components/ui/card';
import { Button } from '../components/ui/button';
import { Drawer, DrawerContent, DrawerHeader, DrawerTitle } from '../components/ui/drawer';
import { useTheme } from '../hooks/use-theme';
import { useIsMobile } from '../hooks/use-mobile';
import { Moon, Sun, Check, ChevronLeft, ChevronRight } from 'lucide-react';
import { toast } from 'sonner';
import { format, startOfMonth, endOfMonth, eachDayOfInterval, addMonths, subMonths, isSameMonth, startOfWeek, isSameDay, startOfDay } from 'date-fns';
import { motion, AnimatePresence } from 'framer-motion';
import BookingForm from '../components/BookingForm';
import AccessBadge from '../components/AccessBadge';

interface Booking {
  id: string;
  date: string;
  startTime: string;
  duration: 'THREE_HOURS' | 'SIX_HOURS';
  status: 'PENDING' | 'CONFIRMED' | 'CANCELLED';
  companyName?: string;
  contactName?: string;
  attendees?: Array<{ name: string; position?: string; email?: string }>;
}

interface DayBookings {
  morning: Booking | null;
  afternoon: Booking | null;
  fullDay: Booking | null;
}

const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

export default function GuestBooking() {
  const { token } = useParams<{ token: string }>();
  const { theme, toggleTheme } = useTheme();
  const isMobile = useIsMobile();
  const [validating, setValidating] = useState(true);
  const [isValid, setIsValid] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [currentMonth, setCurrentMonth] = useState(new Date());
  const [selectedDate, setSelectedDate] = useState<Date | null>(null);
  const [selectedSlot, setSelectedSlot] = useState<'morning' | 'afternoon' | 'full-day' | null>(null);
  const [showSlotPicker, setShowSlotPicker] = useState(false);
  const [showBookingForm, setShowBookingForm] = useState(false);
  const [direction, setDirection] = useState(0);
  const [showWelcome, setShowWelcome] = useState(true);
  const [createdBooking, setCreatedBooking] = useState<Booking | null>(null);

  useEffect(() => {
    validateToken();
  }, [token]);

  useEffect(() => {
    if (isValid) {
      loadBookings();
    }
  }, [isValid]);

  const loadBookings = async () => {
    try {
      // Use public availability endpoint instead of /api/bookings
      // This endpoint should return only availability info without booking details
      const response = await api.get('/api/bookings/availability');
      // Transform availability data to match our Booking interface structure
      // The backend should return an array with minimal info: date, startTime, duration
      setBookings(response.data);
    } catch (error) {
      console.error('Failed to load availability:', error);
      // If endpoint doesn't exist yet, continue without bookings data
      setBookings([]);
    }
  };

  const getBookingsForDay = (date: Date): DayBookings => {
    const dateStr = format(date, 'yyyy-MM-dd');
    const dayBookings = bookings.filter(b => {
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

  const getAvailableSlots = (date: Date): ('morning' | 'afternoon' | 'full-day')[] => {
    const dayBookings = getBookingsForDay(date);

    if (dayBookings.fullDay) {
      return [];
    }

    const slots: ('morning' | 'afternoon' | 'full-day')[] = [];

    if (!dayBookings.morning && !dayBookings.afternoon) {
      slots.push('full-day');
    }

    if (!dayBookings.morning) {
      slots.push('morning');
    }

    if (!dayBookings.afternoon) {
      slots.push('afternoon');
    }

    return slots;
  };

  const handleDayClick = (date: Date, isCurrentMonth: boolean, hasAvailableSlots: boolean) => {
    const today = startOfDay(new Date());
    if (startOfDay(date) < today) return;

    if (!isCurrentMonth) {
      const monthDiff = date.getMonth() - currentMonth.getMonth();
      setDirection(monthDiff > 0 ? 1 : -1);
      setCurrentMonth(date);
      return;
    }

    if (!hasAvailableSlots) return;

    setSelectedDate(date);
    setShowSlotPicker(true);
  };

  const handleSlotSelect = (slot: 'morning' | 'afternoon' | 'full-day') => {
    setSelectedSlot(slot);
    setShowSlotPicker(false);
    setShowBookingForm(true);
  };

  const handleBookingSuccess = (booking: Booking) => {
    setCreatedBooking(booking);
    setShowBookingForm(false);
    setSuccess(true);
  };

  const getDaysToDisplay = () => {
    const start = startOfMonth(currentMonth);
    const end = endOfMonth(currentMonth);
    const startWeek = startOfWeek(start);

    const daysInMonth = eachDayOfInterval({ start, end });
    const firstDayOfWeek = startWeek.getDay();

    // Days from previous month
    const paddingDays = firstDayOfWeek;
    const paddingDaysArray = Array.from({ length: paddingDays }, (_, i) => {
      const date = new Date(start);
      date.setDate(date.getDate() - (paddingDays - i));
      return date;
    });

    const allDays = [...paddingDaysArray, ...daysInMonth];

    // Add days from next month (max 3 days)
    const daysToAdd = 35 - allDays.length;
    const maxNextMonthDays = Math.min(daysToAdd, 3);

    for (let i = 0; i < maxNextMonthDays; i++) {
      const lastDay = allDays[allDays.length - 1];
      const nextDay = new Date(lastDay);
      nextDay.setDate(nextDay.getDate() + 1);
      allDays.push(nextDay);
    }

    // If still need more days, add from previous month at the beginning
    if (allDays.length < 35) {
      const daysNeeded = 35 - allDays.length;
      const firstDay = allDays[0];
      const previousDays = Array.from({ length: daysNeeded }, (_, i) => {
        const date = new Date(firstDay);
        date.setDate(date.getDate() - (daysNeeded - i));
        return date;
      });
      allDays.unshift(...previousDays);
    }

    return allDays;
  };

  const validateToken = async () => {
    if (!token) {
      setError('Invalid invitation link');
      setValidating(false);
      return;
    }

    try {
      const response = await api.get(`/api/invitations/${token}/validate`);
      const data = response.data;

      if (!data.valid) {
        if (data.expired) {
          setError('This invitation link has expired');
        } else if (data.used) {
          setError('This invitation link has already been used');
        } else {
          setError('This invitation link is not valid');
        }
      } else {
        setIsValid(true);
      }
    } catch (err: any) {
      toast.error('Failed to validate invitation link');
      setError('Failed to validate invitation link');
    } finally {
      setValidating(false);
    }
  };

  if (validating) {
    return (
      <div className={`min-h-screen flex items-center justify-center ${theme === 'dark' ? 'bg-black' : 'bg-gray-50'}`}>
        <Card className={`w-full max-w-md p-8 text-center ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
          <p className={theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}>Validating invitation...</p>
        </Card>
      </div>
    );
  }

  if (success && createdBooking) {
    const allAttendees = [
      { name: createdBooking.contactName || 'Guest' },
      ...(createdBooking.attendees || []),
    ];

    return (
      <div className={`min-h-screen transition-colors duration-200 ${theme === 'dark' ? 'bg-black' : 'bg-gray-50'}`}>
        <div className="bg-black border-b border-gray-800">
          <div className="max-w-[1800px] mx-auto px-4 sm:px-6 lg:px-8">
            <div className="flex justify-between items-center py-4 sm:py-3">
              <div className="flex items-center gap-3 sm:gap-4 flex-1 min-w-0">
                <img
                  src="https://www.tcs.com/content/dam/global-tcs/en/images/home/tcs-logo-1.svg"
                  alt="TCS Logo"
                  className="h-12 sm:h-10 flex-shrink-0"
                />
                <div className="border-l border-gray-600 pl-3 sm:pl-4 min-w-0">
                  <h1 className="text-base sm:text-xl font-bold text-white truncate">PacePort Scheduler</h1>
                </div>
              </div>
              <div className="flex items-center gap-2 sm:gap-3 flex-shrink-0">
                <Button
                  onClick={toggleTheme}
                  variant="ghost"
                  size="icon"
                  className="text-gray-400 hover:text-white hover:bg-gray-800"
                >
                  {theme === 'dark' ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
                </Button>
              </div>
            </div>
          </div>
        </div>

        <div className="max-w-4xl mx-auto px-4 py-8">
          <motion.div
            initial={{ scale: 0.9, opacity: 0, y: 20 }}
            animate={{ scale: 1, opacity: 1, y: 0 }}
            transition={{ type: 'spring', duration: 0.5 }}
          >
            <div className="text-center mb-8">
              <div className={`inline-flex items-center justify-center w-20 h-20 rounded-full mb-4 ${
                theme === 'dark' ? 'bg-green-950 border-2 border-green-800' : 'bg-green-100'
              }`}>
                <Check className={`w-10 h-10 ${theme === 'dark' ? 'text-green-400' : 'text-green-600'}`} />
              </div>
              <h2 className={`text-2xl sm:text-3xl font-bold mb-4 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                Booking Confirmed!
              </h2>
              <p className={`text-base mb-2 ${theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}`}>
                Your visit to TCS PacePort São Paulo has been scheduled successfully.
              </p>
              <p className={`text-sm mb-8 ${theme === 'dark' ? 'text-gray-500' : 'text-gray-500'}`}>
                You will receive a confirmation email with all the details shortly.
              </p>
            </div>

            <div className="mb-8">
              <h3 className={`text-xl font-bold mb-4 text-center ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                Your Access Badge{allAttendees.length > 1 ? 's' : ''}
              </h3>
              <p className={`text-sm text-center mb-6 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                {allAttendees.length === 1
                  ? 'Save or share your digital access badge for entry'
                  : `${allAttendees.length} badges for all attendees - save or share for entry`
                }
              </p>

              <div className="space-y-6">
                {allAttendees.map((attendee, index) => (
                  <AccessBadge
                    key={index}
                    attendeeName={attendee.name}
                    attendeePosition={attendee.position}
                    companyName={createdBooking.companyName || 'Guest Company'}
                    date={createdBooking.date}
                    startTime={createdBooking.startTime}
                    duration={createdBooking.duration}
                    bookingId={createdBooking.id}
                    theme={theme}
                    showActions={true}
                  />
                ))}
              </div>
            </div>
          </motion.div>
        </div>
      </div>
    );
  }

  if (!isValid || error) {
    return (
      <div className={`min-h-screen flex items-center justify-center ${theme === 'dark' ? 'bg-black' : 'bg-gray-50'}`}>
        <Card className={`w-full max-w-md p-8 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
          <div className={`p-4 rounded-lg border ${
            theme === 'dark' ? 'bg-red-950 border-red-800' : 'bg-red-50 border-red-600'
          }`}>
            <p className={`text-sm ${theme === 'dark' ? 'text-red-400' : 'text-red-600'}`}>{error}</p>
          </div>
          <div className="mt-4 text-center">
            <p className={`text-sm ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
              Please contact your TCS representative for a new invitation link.
            </p>
          </div>
        </Card>
      </div>
    );
  }

  const daysToDisplay = getDaysToDisplay();

  return (
    <div className={`min-h-screen transition-colors duration-200 ${theme === 'dark' ? 'bg-black' : 'bg-gray-50'}`}>
      {/* Header - Always Black (same as admin/manager) */}
      <div className="bg-black border-b border-gray-800">
        <div className="max-w-[1800px] mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center py-4 sm:py-3">
            {/* Logo and Title */}
            <div className="flex items-center gap-3 sm:gap-4 flex-1 min-w-0">
              <img
                src="https://www.tcs.com/content/dam/global-tcs/en/images/home/tcs-logo-1.svg"
                alt="TCS Logo"
                className="h-12 sm:h-10 flex-shrink-0"
              />
              <div className="border-l border-gray-600 pl-3 sm:pl-4 min-w-0">
                <h1 className="text-base sm:text-xl font-bold text-white truncate">PacePort Scheduler</h1>
              </div>
            </div>

            {/* Theme Toggle */}
            <div className="flex items-center gap-2 sm:gap-3 flex-shrink-0">
              <Button
                onClick={toggleTheme}
                variant="ghost"
                size="icon"
                className="text-gray-400 hover:text-white hover:bg-gray-800"
              >
                {theme === 'dark' ? <Sun className="h-5 w-5" /> : <Moon className="h-5 w-5" />}
              </Button>
            </div>
          </div>
        </div>
      </div>

      {/* Welcome Modal */}
      <AnimatePresence>
        {showWelcome && isValid && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
            onClick={() => setShowWelcome(false)}
          >
            <motion.div
              initial={{ scale: 0.9, opacity: 0, y: 20 }}
              animate={{ scale: 1, opacity: 1, y: 0 }}
              exit={{ scale: 0.9, opacity: 0, y: 20 }}
              transition={{ type: 'spring', duration: 0.5 }}
              onClick={(e) => e.stopPropagation()}
              className={`max-w-lg w-full p-8 rounded-lg ${
                theme === 'dark' ? 'bg-zinc-900 border border-zinc-800' : 'bg-white border border-gray-200'
              }`}
            >
              <div className="text-center">
                <div className="mb-6">
                  <img
                    src="https://www.tcs.com/content/dam/global-tcs/en/images/home/tcs-logo-1.svg"
                    alt="TCS Logo"
                    className="h-12 mx-auto mb-4"
                  />
                </div>
                <h2 className={`text-2xl sm:text-3xl font-bold mb-4 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                  Welcome to TCS PacePort
                </h2>
                <p className={`text-base mb-6 ${theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}`}>
                  You have been invited to visit TCS PacePort São Paulo. Please select an available date from the calendar to schedule your visit.
                </p>
                <Button
                  onClick={() => setShowWelcome(false)}
                  className={`w-full ${
                    theme === 'dark' ? 'bg-white text-black hover:bg-gray-200' : 'bg-black text-white hover:bg-gray-800'
                  }`}
                >
                  Continue to Calendar
                </Button>
              </div>
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Main Content */}
      <div className="max-w-[1800px] mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Month Navigation */}
        <div className="flex flex-col sm:flex-row items-center justify-between mb-6 sm:mb-8 gap-4">
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

          {!isMobile && (
            <div className="flex items-center gap-4 sm:gap-6">
              <div className="flex items-center gap-2 text-xs sm:text-sm">
                <div className={`w-3 h-3 sm:w-4 sm:h-4 rounded ${
                  theme === 'dark' ? 'bg-zinc-900 border border-zinc-700' : 'bg-white border border-gray-300'
                }`}></div>
                <span className={theme === 'dark' ? 'text-gray-500' : 'text-gray-600'}>Available</span>
              </div>
              <div className="flex items-center gap-2 text-xs sm:text-sm">
                <div className={`w-3 h-3 sm:w-4 sm:h-4 rounded ${
                  theme === 'dark' ? 'bg-white' : 'bg-black'
                }`}></div>
                <span className={theme === 'dark' ? 'text-gray-500' : 'text-gray-600'}>Booked</span>
              </div>
              <div className="flex items-center gap-2 text-xs sm:text-sm">
                <div className={`w-3 h-3 sm:w-4 sm:h-4 rounded ${
                  theme === 'dark' ? 'bg-zinc-800 border border-zinc-700' : 'bg-gray-100 border border-gray-200'
                }`}></div>
                <span className={theme === 'dark' ? 'text-gray-500' : 'text-gray-600'}>Past</span>
              </div>
            </div>
          )}
        </div>

        {/* Calendar Grid */}
        <Card className={`p-2 sm:p-4 overflow-hidden ${
          theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''
        }`}>
          {/* Week days header */}
          <div className="grid grid-cols-7 gap-2 mb-1">
            {weekDays.map(day => (
              <div key={day} className="text-center font-semibold text-xs text-gray-500 py-1">
                {day}
              </div>
            ))}
          </div>

          {/* Calendar days */}
          <div className="overflow-hidden">
            <AnimatePresence mode="wait" initial={false} custom={direction}>
              <motion.div
                key={currentMonth.toISOString()}
                custom={direction}
                initial={{ opacity: 0, x: direction > 0 ? 100 : -100 }}
                animate={{ opacity: 1, x: 0 }}
                exit={{ opacity: 0, x: direction > 0 ? -100 : 100 }}
                transition={{ duration: 0.3, ease: 'easeInOut' }}
                className="grid grid-cols-7 gap-2"
              >
                {daysToDisplay.map((date, idx) => {
                  const isCurrentMonth = isSameMonth(date, currentMonth);
                  const isToday = isSameDay(date, new Date());
                  const isPast = startOfDay(date) < startOfDay(new Date());
                  const dayBookings = getBookingsForDay(date);
                  const availableSlots = getAvailableSlots(date);
                  const hasAvailableSlots = availableSlots.length > 0;
                  const isFullyBooked = dayBookings.fullDay || (dayBookings.morning && dayBookings.afternoon);

                  return (
                    <motion.button
                      key={idx}
                      initial={{ opacity: 0, scale: 0.9 }}
                      animate={{ opacity: 1, scale: 1 }}
                      transition={{ delay: idx * 0.01, duration: 0.2 }}
                      onClick={() => handleDayClick(date, isCurrentMonth, hasAvailableSlots)}
                      disabled={isPast}
                      className={`
                        group min-h-[70px] sm:min-h-[90px] border rounded p-1.5 text-left relative
                        transition-all duration-200 ease-out
                        ${isPast
                          ? theme === 'dark' ? 'bg-zinc-950 cursor-not-allowed opacity-40' : 'bg-gray-200/50 cursor-not-allowed'
                          : theme === 'dark' ? 'bg-zinc-900' : 'bg-white'
                        }
                        ${!isCurrentMonth ? 'opacity-40 cursor-pointer' : ''}
                        ${isToday && isCurrentMonth
                          ? theme === 'dark' ? 'border-2 border-white shadow-md' : 'border-2 border-black shadow-md'
                          : theme === 'dark' ? 'border-zinc-800' : 'border-gray-300'
                        }
                        ${!isPast
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
                          isToday && isCurrentMonth
                            ? theme === 'dark'
                              ? 'bg-white text-black w-4 h-4 rounded-full'
                              : 'bg-black text-white w-4 h-4 rounded-full'
                            : !isCurrentMonth || isPast
                              ? 'text-gray-500'
                              : theme === 'dark'
                                ? 'text-gray-300'
                                : 'text-gray-700'
                        }`}>
                          {format(date, 'd')}
                        </span>
                      </div>

                      {/* Availability indicators - only show for current month non-past days */}
                      {isCurrentMonth && !isPast && (
                        <div className="mt-3 flex items-center gap-1">
                          {isFullyBooked ? (
                            /* Full day - single box with FULL badge */
                            <div className="flex-1 relative">
                              <div className="h-6 rounded bg-gradient-to-br from-red-500 to-red-600"></div>
                              <div className="absolute inset-0 flex items-center justify-center">
                                <span className="text-[8px] font-bold text-white">FULL</span>
                              </div>
                            </div>
                          ) : (
                            /* Two mini slots side by side */
                            <>
                              {/* Morning slot */}
                              <div className={`flex-1 h-6 rounded ${
                                dayBookings.morning
                                  ? 'bg-gradient-to-br from-red-500 to-red-600'
                                  : theme === 'dark' ? 'bg-zinc-700' : 'bg-gray-300'
                              }`}></div>
                              {/* Afternoon slot */}
                              <div className={`flex-1 h-6 rounded ${
                                dayBookings.afternoon
                                  ? 'bg-gradient-to-br from-red-500 to-red-600'
                                  : theme === 'dark' ? 'bg-zinc-700' : 'bg-gray-300'
                              }`}></div>
                            </>
                          )}
                        </div>
                      )}
                    </motion.button>
                  );
                })}
              </motion.div>
            </AnimatePresence>
          </div>
        </Card>

        <div className={`mt-8 text-center text-sm ${theme === 'dark' ? 'text-gray-500' : 'text-gray-500'}`}>
          <p>
            TCS PacePort is an innovation and experience center showcasing TCS's technology capabilities and solutions.
          </p>
        </div>
      </div>

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
                    ? 'border-zinc-800 bg-black text-white hover:border-white hover:bg-zinc-900'
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
              token={token}
              theme={theme}
              initialDate={selectedDate ? format(selectedDate, 'yyyy-MM-dd') : ''}
              initialSlot={selectedSlot || undefined}
              onSuccess={handleBookingSuccess}
              onCancel={() => setShowBookingForm(false)}
            />
          </div>
        </DrawerContent>
      </Drawer>
    </div>
  );
}
