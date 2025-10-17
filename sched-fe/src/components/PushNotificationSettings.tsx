import { useState } from 'react';
import { usePushNotifications } from '../hooks/use-push-notifications';
import { Card } from './ui/card';
import { Button } from './ui/button';
import { Switch } from './ui/switch';
import { Bell, BellOff, Send } from 'lucide-react';
import { toast } from 'sonner';
import { motion, AnimatePresence } from 'framer-motion';

interface PushNotificationSettingsProps {
  theme: 'light' | 'dark';
}

export default function PushNotificationSettings({ theme }: PushNotificationSettingsProps) {
  const {
    isSupported,
    permission,
    isSubscribed,
    isLoading,
    subscribe,
    unsubscribe,
    sendTestNotification,
  } = usePushNotifications();

  const [isSending, setIsSending] = useState(false);

  if (!isSupported) {
    return (
      <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
        <div className="flex items-center gap-3 mb-4">
          <BellOff className={`w-5 h-5 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`} />
          <h3 className={`text-lg font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
            Push Notifications
          </h3>
        </div>
        <p className={`text-sm ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
          Push notifications are not supported in this browser.
        </p>
      </Card>
    );
  }

  const handleToggle = async () => {
    if (isSubscribed) {
      await unsubscribe();
    } else {
      await subscribe();
    }
  };

  const handleSendTest = async () => {
    setIsSending(true);
    try {
      await sendTestNotification();
    } catch (error) {
      // Error is already handled in the hook
    } finally {
      setIsSending(false);
    }
  };

  const getPermissionStatus = () => {
    if (permission === 'denied') {
      return {
        color: theme === 'dark' ? 'text-red-400' : 'text-red-600',
        bg: theme === 'dark' ? 'bg-red-950/30' : 'bg-red-100',
        text: 'Blocked',
      };
    }
    if (isSubscribed) {
      return {
        color: theme === 'dark' ? 'text-green-400' : 'text-green-600',
        bg: theme === 'dark' ? 'bg-green-950/30' : 'bg-green-100',
        text: 'Active',
      };
    }
    return {
      color: theme === 'dark' ? 'text-gray-400' : 'text-gray-600',
      bg: theme === 'dark' ? 'bg-zinc-800' : 'bg-gray-100',
      text: 'Inactive',
    };
  };

  const status = getPermissionStatus();

  return (
    <Card className={`p-6 ${theme === 'dark' ? 'bg-zinc-900 border-zinc-800' : ''}`}>
      <div className="flex items-start justify-between mb-4">
        <div className="flex items-center gap-3">
          <Bell className={`w-5 h-5 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`} />
          <div>
            <h3 className={`text-lg font-bold ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
              Push Notifications
            </h3>
            <div className="flex items-center gap-2 mt-1">
              <span
                className={`inline-block px-2 py-0.5 rounded text-xs font-semibold ${status.color} ${status.bg}`}
              >
                {status.text}
              </span>
            </div>
          </div>
        </div>

        {permission !== 'denied' && (
          <Switch
            checked={isSubscribed}
            onCheckedChange={handleToggle}
            disabled={isLoading}
            className={theme === 'dark' ? 'data-[state=checked]:bg-white' : ''}
          />
        )}
      </div>

      <AnimatePresence mode="wait">
        {permission === 'denied' ? (
          <motion.div
            key="denied"
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 10 }}
            className={`p-4 rounded-lg ${theme === 'dark' ? 'bg-red-950/20 border border-red-900/30' : 'bg-red-50 border border-red-200'}`}
          >
            <p className={`text-sm ${theme === 'dark' ? 'text-red-400' : 'text-red-600'} mb-2`}>
              <strong>Notifications Blocked</strong>
            </p>
            <p className={`text-xs ${theme === 'dark' ? 'text-red-400/70' : 'text-red-600/80'}`}>
              You've blocked notifications for this site. To enable them:
            </p>
            <ol className={`text-xs mt-2 ml-4 list-decimal space-y-1 ${theme === 'dark' ? 'text-red-400/70' : 'text-red-600/80'}`}>
              <li>Click the lock icon in your browser's address bar</li>
              <li>Find "Notifications" and change to "Allow"</li>
              <li>Refresh this page and toggle notifications on</li>
            </ol>
          </motion.div>
        ) : isSubscribed ? (
          <motion.div
            key="subscribed"
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 10 }}
            className="space-y-3"
          >
            <p className={`text-sm ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
              You'll receive notifications for:
            </p>
            <ul className={`text-sm space-y-2 ml-4 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
              <li className="flex items-start gap-2">
                <span className="mt-1">•</span>
                <span>New bookings created by your team</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="mt-1">•</span>
                <span>Updates to existing bookings</span>
              </li>
              <li className="flex items-start gap-2">
                <span className="mt-1">•</span>
                <span>Cancelled bookings</span>
              </li>
            </ul>

            <div className={`pt-3 border-t ${theme === 'dark' ? 'border-zinc-800' : 'border-gray-200'}`}>
              <Button
                onClick={handleSendTest}
                disabled={isSending}
                variant="outline"
                size="sm"
                className={`w-full ${
                  theme === 'dark'
                    ? 'border-zinc-800 bg-zinc-950 text-white hover:bg-zinc-800'
                    : ''
                }`}
              >
                <Send className="w-4 h-4 mr-2" />
                {isSending ? 'Sending...' : 'Send Test Notification'}
              </Button>
            </div>
          </motion.div>
        ) : (
          <motion.div
            key="not-subscribed"
            initial={{ opacity: 0, y: -10 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: 10 }}
          >
            <p className={`text-sm ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
              Enable push notifications to stay updated about bookings, even when the app is closed or in the background.
            </p>
            <p className={`text-xs mt-2 ${theme === 'dark' ? 'text-gray-500' : 'text-gray-500'}`}>
              Works on desktop and mobile devices.
            </p>
          </motion.div>
        )}
      </AnimatePresence>
    </Card>
  );
}
