import { useEffect, useState } from 'react';
import { useLocation } from 'react-router-dom';
import { motion, AnimatePresence } from 'framer-motion';
import { useTheme } from '../hooks/use-theme';
import { Spinner } from './ui/spinner';

/**
 * LoadingOverlay - Shows smooth loading transition when navigating between routes
 */
export function LoadingOverlay() {
  const { theme } = useTheme();
  const location = useLocation();
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    // Show loading on route change
    setIsLoading(true);

    // Hide loading after a short delay to allow page to mount
    const timer = setTimeout(() => {
      setIsLoading(false);
    }, 300);

    return () => clearTimeout(timer);
  }, [location.pathname]);

  return (
    <AnimatePresence>
      {isLoading && (
        <motion.div
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
          transition={{ duration: 0.15 }}
          className={`fixed inset-0 z-50 flex items-center justify-center ${
            theme === 'dark' ? 'bg-black/50' : 'bg-white/50'
          } backdrop-blur-sm`}
        >
          <motion.div
            initial={{ scale: 0.9, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            exit={{ scale: 0.9, opacity: 0 }}
            transition={{ duration: 0.2 }}
            className={`flex flex-col items-center gap-3 p-6 rounded-lg ${
              theme === 'dark' ? 'bg-zinc-900 border border-zinc-800' : 'bg-white border border-gray-200'
            } shadow-lg`}
          >
            <Spinner className={`h-8 w-8 ${theme === 'dark' ? 'text-white' : 'text-black'}`} />
            <p className={`text-sm font-medium ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
              Loading...
            </p>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
