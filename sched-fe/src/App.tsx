import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import { AuthProvider, useAuth } from '@/lib/auth';
import { ThemeProvider } from '@/hooks/use-theme';
import { Toaster } from '@/components/ui/sonner';
import { useSWNotifications } from '@/hooks/use-sw-notifications';
import { PWAInstallBanner } from '@/components/PWAInstallBanner';
import { LoadingOverlay } from '@/components/LoadingOverlay';
import AppLayout from '@/components/AppLayout';
import Login from '@/pages/Login';
import Dashboard from '@/pages/Dashboard';
import Calendar from '@/pages/Calendar';
import Invitations from '@/pages/Invitations';
import Users from '@/pages/Users';
import ActivityLogs from '@/pages/ActivityLogs';
import GuestBooking from '@/pages/GuestBooking';
import PublicBadge from '@/pages/PublicBadge';
import AttendeeBadge from '@/pages/AttendeeBadge';
import { AnimatePresence } from 'framer-motion';

// Register service worker
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker
      .register('/sw.js')
      .then((registration) => {
        console.log('✅ Service Worker registered:', registration.scope);

        // Check for updates every hour
        setInterval(() => {
          registration.update();
          console.log('🔄 Checking for Service Worker updates...');
        }, 1000 * 60 * 60);
      })
      .catch((error) => {
        console.error('❌ Service Worker registration failed:', error);
      });
  });
}

function ProtectedRoute({ children, requireAdmin }: { children: React.ReactNode; requireAdmin?: boolean }) {
  const { user, loading } = useAuth();
  useSWNotifications(); // Enable SW-based notifications for installed PWA

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50 dark:bg-black">
        <div className="flex flex-col items-center gap-3">
          <div className="h-8 w-8 border-4 border-gray-200 border-t-black dark:border-zinc-800 dark:border-t-white rounded-full animate-spin" />
          <p className="text-sm text-gray-600 dark:text-gray-400">Loading...</p>
        </div>
      </div>
    );
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (requireAdmin && user.role !== 'ADMIN') {
    return <Navigate to="/dashboard" replace />;
  }

  return <AppLayout>{children}</AppLayout>;
}

function ConditionalPWABanner() {
  const location = useLocation();
  const publicRoutes = ['/book', '/badge', '/attendee'];

  // Don't show PWA banner on public routes
  const isPublicRoute = publicRoutes.some(route => location.pathname.startsWith(route));

  if (isPublicRoute) {
    return null;
  }

  return <PWAInstallBanner />;
}

function AnimatedRoutes() {
  const location = useLocation();

  return (
    <>
      <LoadingOverlay />
      <AnimatePresence mode="wait">
        <Routes location={location} key={location.pathname}>
          <Route path="/login" element={<Login />} />
          <Route path="/book/:token" element={<GuestBooking />} />
          <Route path="/book" element={<Navigate to="/login" replace />} />
          <Route path="/badge/:bookingId" element={<PublicBadge />} />
          <Route path="/attendee/:attendeeId" element={<AttendeeBadge />} />
          <Route
            path="/dashboard"
            element={
              <ProtectedRoute>
                <Dashboard />
              </ProtectedRoute>
            }
          />
          <Route
            path="/calendar"
            element={
              <ProtectedRoute>
                <Calendar />
              </ProtectedRoute>
            }
          />
          <Route
            path="/invitations"
            element={
              <ProtectedRoute>
                <Invitations />
              </ProtectedRoute>
            }
          />
          <Route
            path="/users"
            element={
              <ProtectedRoute requireAdmin>
                <Users />
              </ProtectedRoute>
            }
          />
          <Route
            path="/activity-logs"
            element={
              <ProtectedRoute requireAdmin>
                <ActivityLogs />
              </ProtectedRoute>
            }
          />
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
          <Route path="*" element={<Navigate to="/login" replace />} />
        </Routes>
      </AnimatePresence>
    </>
  );
}

const App = () => {
  return (
    <BrowserRouter>
      <ThemeProvider>
        <AuthProvider>
          <AnimatedRoutes />
          <Toaster />
          <ConditionalPWABanner />
        </AuthProvider>
      </ThemeProvider>
    </BrowserRouter>
  );
};

export default App;
