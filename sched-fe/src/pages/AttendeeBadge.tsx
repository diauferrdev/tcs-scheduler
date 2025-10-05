import { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { api } from '../lib/api';
import { useTheme } from '../hooks/use-theme';
import { Skeleton } from '../components/ui/skeleton';
import AccessBadge from '../components/AccessBadge';
import SEO from '../components/SEO';
import { toast } from 'sonner';
import { motion } from 'framer-motion';
import Tilt from 'react-parallax-tilt';
import { Moon, Sun } from 'lucide-react';
import { Button } from '../components/ui/button';
import { format } from 'date-fns';

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
  const { theme, toggleTheme } = useTheme();
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

  // Generate SEO data
  const seoTitle = attendee
    ? `${attendee.name} - TCS PacePort Access Badge`
    : 'TCS PacePort Access Badge';

  const seoDescription = attendee
    ? `Access badge for ${attendee.name} from ${attendee.booking.companyName} - Visit scheduled for ${format(new Date(attendee.booking.date), 'MMMM d, yyyy')}`
    : 'Digital access badge for TCS PacePort São Paulo visit';

  const seoImage = attendee
    ? `${window.location.origin}/api/og/attendee/${attendee.id}`
    : `${window.location.origin}/og-image.png`;

  if (loading) {
    return (
      <>
        <SEO
          title="Loading Access Badge..."
          description="TCS PacePort digital access badge"
        />
        <div className={`min-h-screen flex items-center justify-center ${
          theme === 'dark' ? 'bg-black' : 'bg-gray-50'
        }`}>
          <div className="w-full max-w-md mx-auto px-4">
            <Skeleton className={`h-[600px] w-full rounded-2xl ${theme === 'dark' ? 'bg-zinc-800' : ''}`} />
          </div>
        </div>
      </>
    );
  }

  if (error || !attendee) {
    return (
      <>
        <SEO
          title="Badge Not Found"
          description="This access badge does not exist"
          noindex={true}
        />
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
              {error || 'This access badge does not exist.'}
            </p>
          </motion.div>
        </div>
      </>
    );
  }

  return (
    <>
      <SEO
        title={seoTitle}
        description={seoDescription}
        image={seoImage}
        type="article"
        keywords={`TCS PacePort, Access Badge, ${attendee.name}, ${attendee.booking.companyName}, Visit Schedule`}
      />
    <div className={`min-h-screen relative ${
      theme === 'dark' ? 'bg-black' : 'bg-gray-50'
    } overflow-hidden`}>
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
          className={`rounded-full w-10 h-10 md:w-12 md:h-12 shadow-lg ${
            theme === 'dark'
              ? 'bg-zinc-900 border-zinc-700 hover:bg-zinc-800'
              : 'bg-white border-gray-300 hover:bg-gray-100'
          }`}
        >
          {theme === 'dark' ? (
            <Sun className="w-4 h-4 md:w-5 md:h-5 text-yellow-500" />
          ) : (
            <Moon className="w-4 h-4 md:w-5 md:h-5 text-gray-700" />
          )}
        </Button>
      </motion.div>

      {/* Animated Wave Lines Background - Hidden on mobile for better performance */}
      <div className="absolute inset-0 pointer-events-none hidden md:block">
        <svg
          className="absolute inset-0 w-full h-full"
          xmlns="http://www.w3.org/2000/svg"
        >
          <defs>
            <linearGradient id="line-gradient-1" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stopColor={theme === 'dark' ? '#3b82f6' : '#60a5fa'} />
              <stop offset="100%" stopColor={theme === 'dark' ? '#06b6d4' : '#22d3ee'} />
            </linearGradient>
            <linearGradient id="line-gradient-2" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stopColor={theme === 'dark' ? '#8b5cf6' : '#a78bfa'} />
              <stop offset="100%" stopColor={theme === 'dark' ? '#ec4899' : '#f9a8d4'} />
            </linearGradient>
            <linearGradient id="line-gradient-3" x1="0%" y1="0%" x2="100%" y2="0%">
              <stop offset="0%" stopColor={theme === 'dark' ? '#06b6d4' : '#22d3ee'} />
              <stop offset="100%" stopColor={theme === 'dark' ? '#8b5cf6' : '#a78bfa'} />
            </linearGradient>
            <filter id="glow">
              <feGaussianBlur stdDeviation="2" result="coloredBlur"/>
              <feMerge>
                <feMergeNode in="coloredBlur"/>
                <feMergeNode in="SourceGraphic"/>
              </feMerge>
            </filter>
          </defs>

          {/* Line 1 - Moving right to left, top area */}
          <motion.path
            d="M-1000,150 Q-600,130 -200,150 T600,150 T1400,150 T2200,150 T3000,150 T3800,150"
            stroke="url(#line-gradient-1)"
            strokeWidth="1.5"
            fill="none"
            opacity="0.35"
            strokeLinecap="round"
            filter="url(#glow)"
            animate={{
              d: [
                "M-1000,150 Q-600,130 -200,150 T600,150 T1400,150 T2200,150 T3000,150 T3800,150",
                "M-1000,170 Q-600,190 -200,170 T600,170 T1400,170 T2200,170 T3000,170 T3800,170",
                "M-1000,150 Q-600,130 -200,150 T600,150 T1400,150 T2200,150 T3000,150 T3800,150",
              ],
              x: [0, -800, 0],
            }}
            transition={{
              duration: 20,
              repeat: Infinity,
              ease: "linear",
            }}
          />

          {/* Line 2 - Moving left to right, crossing line 1 */}
          <motion.path
            d="M3800,280 Q3400,260 3000,280 T2200,280 T1400,280 T600,280 T-200,280 T-1000,280"
            stroke="url(#line-gradient-2)"
            strokeWidth="1.5"
            fill="none"
            opacity="0.3"
            strokeLinecap="round"
            filter="url(#glow)"
            animate={{
              d: [
                "M3800,280 Q3400,260 3000,280 T2200,280 T1400,280 T600,280 T-200,280 T-1000,280",
                "M3800,300 Q3400,320 3000,300 T2200,300 T1400,300 T600,300 T-200,300 T-1000,300",
                "M3800,280 Q3400,260 3000,280 T2200,280 T1400,280 T600,280 T-200,280 T-1000,280",
              ],
              x: [0, 800, 0],
            }}
            transition={{
              duration: 24,
              repeat: Infinity,
              ease: "linear",
            }}
          />

          {/* Line 3 - Moving right to left, middle area */}
          <motion.path
            d="M-1000,420 Q-600,400 -200,420 T600,420 T1400,420 T2200,420 T3000,420 T3800,420"
            stroke="url(#line-gradient-3)"
            strokeWidth="1.5"
            fill="none"
            opacity="0.28"
            strokeLinecap="round"
            filter="url(#glow)"
            animate={{
              d: [
                "M-1000,420 Q-600,400 -200,420 T600,420 T1400,420 T2200,420 T3000,420 T3800,420",
                "M-1000,440 Q-600,460 -200,440 T600,440 T1400,440 T2200,440 T3000,440 T3800,440",
                "M-1000,420 Q-600,400 -200,420 T600,420 T1400,420 T2200,420 T3000,420 T3800,420",
              ],
              x: [0, -800, 0],
            }}
            transition={{
              duration: 28,
              repeat: Infinity,
              ease: "linear",
            }}
          />

          {/* Line 4 - Moving left to right, lower area */}
          <motion.path
            d="M3800,560 Q3400,540 3000,560 T2200,560 T1400,560 T600,560 T-200,560 T-1000,560"
            stroke="url(#line-gradient-1)"
            strokeWidth="1.5"
            fill="none"
            opacity="0.25"
            strokeLinecap="round"
            filter="url(#glow)"
            animate={{
              d: [
                "M3800,560 Q3400,540 3000,560 T2200,560 T1400,560 T600,560 T-200,560 T-1000,560",
                "M3800,580 Q3400,600 3000,580 T2200,580 T1400,580 T600,580 T-200,580 T-1000,580",
                "M3800,560 Q3400,540 3000,560 T2200,560 T1400,560 T600,560 T-200,560 T-1000,560",
              ],
              x: [0, 800, 0],
            }}
            transition={{
              duration: 26,
              repeat: Infinity,
              ease: "linear",
            }}
          />

          {/* Line 5 - Moving right to left, bottom area */}
          <motion.path
            d="M-1000,690 Q-600,670 -200,690 T600,690 T1400,690 T2200,690 T3000,690 T3800,690"
            stroke="url(#line-gradient-2)"
            strokeWidth="1.5"
            fill="none"
            opacity="0.22"
            strokeLinecap="round"
            filter="url(#glow)"
            animate={{
              d: [
                "M-1000,690 Q-600,670 -200,690 T600,690 T1400,690 T2200,690 T3000,690 T3800,690",
                "M-1000,710 Q-600,730 -200,710 T600,710 T1400,710 T2200,710 T3000,710 T3800,710",
                "M-1000,690 Q-600,670 -200,690 T600,690 T1400,690 T2200,690 T3000,690 T3800,690",
              ],
              x: [0, -800, 0],
            }}
            transition={{
              duration: 32,
              repeat: Infinity,
              ease: "linear",
            }}
          />
        </svg>
      </div>

      {/* Mobile: Centered badge layout */}
      <div className="md:hidden min-h-[100dvh] flex flex-col items-center justify-center px-4 py-16 relative z-10">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
          className="w-full max-w-md"
        >
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
            hideCopyLink={true}
          />
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.3 }}
          className="mt-8 text-center px-4"
        >
          <h2 className={`text-2xl font-bold mb-3 ${
            theme === 'dark' ? 'text-white' : 'text-black'
          }`}>
            Welcome to{' '}
            <span className={theme === 'dark'
              ? 'bg-gradient-to-r from-blue-400 via-purple-400 to-cyan-400 bg-clip-text text-transparent'
              : 'bg-gradient-to-r from-blue-600 via-purple-600 to-cyan-600 bg-clip-text text-transparent'
            }>
              TCS PacePort
            </span>
          </h2>
          <p className={`text-sm ${
            theme === 'dark' ? 'text-gray-400' : 'text-gray-600'
          }`}>
            Your access ticket is ready
          </p>
        </motion.div>
      </div>

      {/* Desktop: Side-by-side layout */}
      <div className="hidden md:flex container mx-auto px-4 py-6 md:py-8 lg:px-8 relative z-10 min-h-screen items-center">
        <div className="flex flex-col lg:flex-row items-center justify-center lg:justify-between gap-6 md:gap-8 lg:gap-16 w-full">
          {/* Left: Badge with Tilt Effect */}
          <motion.div
            initial={{ opacity: 0, x: -50 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 1, ease: [0.22, 1, 0.36, 1] }}
            className="w-full max-w-md lg:max-w-lg"
          >
            <Tilt
              tiltMaxAngleX={8}
              tiltMaxAngleY={8}
              perspective={1500}
              scale={1.02}
              transitionSpeed={2500}
              gyroscope={true}
            >
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
                hideCopyLink={true}
              />
            </Tilt>
          </motion.div>

          {/* Right: Slogan */}
          <motion.div
            initial={{ opacity: 0, x: 50 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ duration: 1, delay: 0.3, ease: [0.22, 1, 0.36, 1] }}
            className="max-w-xl text-center lg:text-left px-2"
          >
            <motion.h1
              className={`text-3xl sm:text-4xl md:text-5xl lg:text-6xl font-bold mb-4 md:mb-6 leading-tight ${
                theme === 'dark' ? 'text-white' : 'text-black'
              }`}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, delay: 0.5 }}
            >
              Welcome to the
              <span className={`block mt-2 ${
                theme === 'dark'
                  ? 'bg-gradient-to-r from-blue-400 via-purple-400 to-cyan-400 bg-clip-text text-transparent'
                  : 'bg-gradient-to-r from-blue-600 via-purple-600 to-cyan-600 bg-clip-text text-transparent'
              }`}>
                Future of Innovation
              </span>
            </motion.h1>

            <motion.p
              className={`text-base md:text-lg lg:text-xl mb-6 md:mb-8 ${
                theme === 'dark' ? 'text-gray-400' : 'text-gray-600'
              }`}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, delay: 0.7 }}
            >
              Immerse yourself in cutting-edge technology and transformative experiences at TCS PacePort.
            </motion.p>

            <motion.div
              className="space-y-4"
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.8, delay: 0.9 }}
            >
              <div className="flex items-center gap-3 md:gap-4 justify-center lg:justify-start">
                <div className={`w-8 md:w-12 h-px ${
                  theme === 'dark' ? 'bg-gradient-to-r from-transparent to-white' : 'bg-gradient-to-r from-transparent to-black'
                }`} />
                <p className={`text-xs md:text-sm font-medium tracking-wider uppercase ${
                  theme === 'dark' ? 'text-gray-500' : 'text-gray-500'
                }`}>
                  Your Journey Begins Here
                </p>
              </div>
            </motion.div>
          </motion.div>
        </div>
      </div>
    </div>
    </>
  );
}
