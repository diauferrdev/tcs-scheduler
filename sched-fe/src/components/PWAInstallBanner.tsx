import { useState, useEffect } from 'react';
import { X, Download, Smartphone, Share } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { usePWAInstall } from '@/hooks/use-pwa-install';
import { useTheme } from '@/hooks/use-theme';
import { useIsMobile } from '@/hooks/use-mobile';

export function PWAInstallBanner() {
  const { isInstallable, isInstalled, promptInstall } = usePWAInstall();
  const { theme } = useTheme();
  const isMobile = useIsMobile();
  const [dismissed, setDismissed] = useState(false);
  const [isIOS, setIsIOS] = useState(false);
  const [showIOSInstructions, setShowIOSInstructions] = useState(false);

  useEffect(() => {
    // Check if user is on iOS
    const userAgent = window.navigator.userAgent.toLowerCase();
    const iOS = /iphone|ipad|ipod/.test(userAgent);
    setIsIOS(iOS);

    // Debug logs
    console.log('🔧 PWA Banner Debug:');
    console.log('  - isInstalled:', isInstalled);
    console.log('  - isInstallable:', isInstallable);
    console.log('  - isIOS:', iOS);
    console.log('  - isMobile:', isMobile);
    console.log('  - dismissed:', dismissed);
    console.log('  - User Agent:', userAgent);

    // Session-based dismiss only (resets on page reload)
    // This ensures banner always shows on every visit if not installed
  }, [isInstalled, isInstallable, isMobile, dismissed]);

  const handleDismiss = () => {
    // Only dismiss for current session
    setDismissed(true);
  };

  const handleInstall = async () => {
    if (isIOS) {
      setShowIOSInstructions(true);
      return;
    }

    // If installable prompt is available, use it
    if (isInstallable) {
      const installed = await promptInstall();
      if (installed) {
        setDismissed(true);
      }
    } else {
      // If no prompt available (mobile Chrome sometimes), show instructions
      alert('To install: Tap the browser menu (⋮) and select "Install app" or "Add to Home screen"');
    }
  };

  // Only hide if already installed or dismissed in current session
  if (isInstalled || dismissed) {
    return null;
  }

  // iOS instructions modal
  if (showIOSInstructions) {
    return (
      <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4 animate-in fade-in duration-200">
        <div
          className={`rounded-2xl max-w-md w-full p-6 space-y-4 animate-in zoom-in-95 duration-200 ${
            theme === 'dark'
              ? 'bg-zinc-900 border border-zinc-800'
              : 'bg-white border border-gray-200'
          }`}
        >
          <div className="flex items-center justify-between">
            <h3
              className={`text-lg font-semibold ${
                theme === 'dark' ? 'text-white' : 'text-black'
              }`}
            >
              Install on iOS
            </h3>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setShowIOSInstructions(false)}
              className={theme === 'dark' ? 'text-gray-400 hover:text-white' : 'text-gray-600 hover:text-black'}
            >
              <X className="h-4 w-4" />
            </Button>
          </div>

          <div className="space-y-4">
            <p className={`text-sm ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
              Follow these steps to add TCS Scheduler to your home screen:
            </p>

            <div className="space-y-3">
              <div className="flex items-start gap-3">
                <div className={`flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center ${
                  theme === 'dark' ? 'bg-zinc-800 text-white' : 'bg-gray-100 text-black'
                }`}>
                  1
                </div>
                <div className="flex-1">
                  <p className={`text-sm ${theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}`}>
                    Tap the <Share className="inline w-4 h-4 mx-1" /> <strong>Share</strong> button in Safari
                  </p>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <div className={`flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center ${
                  theme === 'dark' ? 'bg-zinc-800 text-white' : 'bg-gray-100 text-black'
                }`}>
                  2
                </div>
                <div className="flex-1">
                  <p className={`text-sm ${theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}`}>
                    Scroll down and tap <strong>"Add to Home Screen"</strong>
                  </p>
                </div>
              </div>

              <div className="flex items-start gap-3">
                <div className={`flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center ${
                  theme === 'dark' ? 'bg-zinc-800 text-white' : 'bg-gray-100 text-black'
                }`}>
                  3
                </div>
                <div className="flex-1">
                  <p className={`text-sm ${theme === 'dark' ? 'text-gray-300' : 'text-gray-700'}`}>
                    Tap <strong>"Add"</strong> in the top right corner
                  </p>
                </div>
              </div>
            </div>
          </div>

          <Button
            onClick={() => setShowIOSInstructions(false)}
            className={`w-full ${
              theme === 'dark'
                ? 'bg-white text-black hover:bg-gray-200'
                : 'bg-black text-white hover:bg-gray-800'
            }`}
          >
            Got it
          </Button>
        </div>
      </div>
    );
  }

  // Always show banner on mobile and desktop if not installed (removed isInstallable dependency)
  // Different layouts for mobile vs desktop
  if (isMobile) {
    // Mobile: Full width banner at bottom (above nav if present)
    return (
      <div
        className={`fixed bottom-20 left-0 right-0 z-40 p-4 animate-in slide-in-from-bottom-5 duration-300`}
      >
        <div
          className={`rounded-2xl p-4 shadow-2xl border ${
            theme === 'dark'
              ? 'bg-zinc-900 border-zinc-800'
              : 'bg-white border-gray-200'
          }`}
        >
          <div className="flex items-start gap-3">
            <div className="flex-shrink-0 mt-0.5">
              {isIOS ? (
                <Smartphone className={`w-5 h-5 ${theme === 'dark' ? 'text-white' : 'text-black'}`} />
              ) : (
                <Download className={`w-5 h-5 ${theme === 'dark' ? 'text-white' : 'text-black'}`} />
              )}
            </div>

            <div className="flex-1 min-w-0">
              <h3 className={`text-sm font-semibold mb-1 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
                Install TCS Scheduler
              </h3>
              <p className={`text-xs mb-3 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
                {isIOS
                  ? 'Add to your home screen for quick access'
                  : 'Install for offline access and push notifications'
                }
              </p>

              <div className="flex gap-2">
                <Button
                  onClick={handleInstall}
                  size="sm"
                  className={`flex-1 ${
                    theme === 'dark'
                      ? 'bg-white text-black hover:bg-gray-200'
                      : 'bg-black text-white hover:bg-gray-800'
                  }`}
                >
                  {isIOS ? 'How to Install' : 'Install'}
                </Button>
                <Button
                  onClick={handleDismiss}
                  size="sm"
                  variant="ghost"
                  className={`${
                    theme === 'dark'
                      ? 'text-gray-400 hover:bg-zinc-800 hover:text-white'
                      : 'text-gray-600 hover:bg-gray-100 hover:text-black'
                  }`}
                >
                  <X className="w-4 h-4" />
                </Button>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  // Desktop: Card in bottom right corner
  return (
    <div className="fixed bottom-6 right-6 z-40 max-w-md animate-in slide-in-from-bottom-5 slide-in-from-right-5 duration-300">
      <div
        className={`rounded-2xl p-5 shadow-2xl border ${
          theme === 'dark'
            ? 'bg-zinc-900 border-zinc-800'
            : 'bg-white border-gray-200'
        }`}
      >
        <div className="flex items-start gap-4">
          <div className={`flex-shrink-0 p-3 rounded-xl ${
            theme === 'dark' ? 'bg-zinc-800' : 'bg-gray-100'
          }`}>
            <Download className={`w-6 h-6 ${theme === 'dark' ? 'text-white' : 'text-black'}`} />
          </div>

          <div className="flex-1 min-w-0">
            <h3 className={`text-base font-semibold mb-1 ${theme === 'dark' ? 'text-white' : 'text-black'}`}>
              Install TCS Scheduler
            </h3>
            <p className={`text-sm mb-4 ${theme === 'dark' ? 'text-gray-400' : 'text-gray-600'}`}>
              Install our app for faster access, offline support, and push notifications.
            </p>

            <div className="flex gap-2">
              <Button
                onClick={handleInstall}
                size="sm"
                className={`flex-1 ${
                  theme === 'dark'
                    ? 'bg-white text-black hover:bg-gray-200'
                    : 'bg-black text-white hover:bg-gray-800'
                }`}
              >
                Install Now
              </Button>
              <Button
                onClick={handleDismiss}
                size="sm"
                variant="ghost"
                className={`${
                  theme === 'dark'
                    ? 'text-gray-400 hover:bg-zinc-800 hover:text-white'
                    : 'text-gray-600 hover:bg-gray-100 hover:text-black'
                }`}
              >
                <X className="w-5 h-5" />
              </Button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
