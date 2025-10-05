import { QRCodeSVG } from 'qrcode.react';
import { format } from 'date-fns';
import { Button } from './ui/button';
import { Card } from './ui/card';
import { Download, Share2 } from 'lucide-react';

interface AccessBadgeProps {
  attendeeName: string;
  attendeePosition?: string;
  attendeeId?: string;
  companyName: string;
  date: string;
  startTime: string;
  duration: 'THREE_HOURS' | 'SIX_HOURS';
  bookingId: string;
  theme?: 'light' | 'dark';
  showActions?: boolean;
}

export default function AccessBadge({
  attendeeName,
  attendeePosition,
  attendeeId,
  companyName,
  date,
  startTime,
  duration,
  bookingId,
  theme = 'light',
  showActions = true,
}: AccessBadgeProps) {
  const badgeData = JSON.stringify({
    id: attendeeId || bookingId,
    name: attendeeName,
    position: attendeePosition,
    company: companyName,
    date,
    time: startTime,
  });

  const endTime = duration === 'THREE_HOURS'
    ? (startTime === '09:00' ? '12:00' : '17:00')
    : '17:00';

  const badgeUrl = attendeeId
    ? `${window.location.origin}/attendee/${attendeeId}`
    : `${window.location.origin}/badge/${bookingId}`;

  const handleDownload = () => {
    navigator.clipboard.writeText(badgeUrl);
  };

  const handleShare = async () => {

    if (navigator.share) {
      try {
        await navigator.share({
          title: 'TCS PacePort Access Ticket',
          text: `Access ticket for ${attendeeName} - ${companyName}`,
          url: badgeUrl,
        });
      } catch (err) {
        navigator.clipboard.writeText(badgeUrl);
      }
    } else {
      navigator.clipboard.writeText(badgeUrl);
    }
  };

  return (
    <div className="space-y-4 w-full max-w-md mx-auto">
      <Card
        id={`badge-${bookingId}-${attendeeName.replace(/\s/g, '-')}`}
        className={`relative overflow-hidden border-[3px] ${
          theme === 'dark'
            ? 'bg-gradient-to-br from-zinc-950 via-black to-zinc-950 border-white shadow-2xl shadow-white/10'
            : 'bg-gradient-to-br from-white via-gray-50 to-white border-black shadow-2xl shadow-black/10'
        }`}
      >
        {/* Geometric corner accents */}
        <div className={`absolute top-0 left-0 w-16 h-16 ${
          theme === 'dark' ? 'bg-white/5' : 'bg-black/5'
        }`} style={{ clipPath: 'polygon(0 0, 100% 0, 0 100%)' }} />
        <div className={`absolute top-0 right-0 w-16 h-16 ${
          theme === 'dark' ? 'bg-white/5' : 'bg-black/5'
        }`} style={{ clipPath: 'polygon(100% 0, 100% 100%, 0 0)' }} />

        <div className="p-6 space-y-5">
          {/* Header with Logo and Title */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-3">
              <img
                src="/tcs-logo-white.svg"
                alt="TCS Logo"
                className={`h-8 ${theme === 'dark' ? '' : 'invert'}`}
              />
              <div className={`h-8 w-[2px] ${theme === 'dark' ? 'bg-gray-700' : 'bg-gray-300'}`} />
              <div>
                <div className={`text-[10px] font-bold tracking-[0.15em] uppercase ${
                  theme === 'dark' ? 'text-gray-500' : 'text-gray-400'
                }`}>
                  Access Ticket
                </div>
                <div className={`text-xs font-semibold ${
                  theme === 'dark' ? 'text-gray-300' : 'text-gray-700'
                }`}>
                  PacePort SP
                </div>
              </div>
            </div>

            {/* QR Code - Compact */}
            <div className={`p-2 rounded-lg ${
              theme === 'dark' ? 'bg-white' : 'bg-gray-900'
            }`}>
              <QRCodeSVG
                value={badgeData}
                size={72}
                level="H"
                includeMargin={false}
                fgColor={theme === 'dark' ? '#000000' : '#FFFFFF'}
                bgColor={theme === 'dark' ? '#FFFFFF' : '#000000'}
              />
            </div>
          </div>

          {/* Main Content - Visitor Info */}
          <div className={`pt-4 border-t-2 ${
            theme === 'dark' ? 'border-white/20' : 'border-black/20'
          }`}>
            <div className="space-y-3">
              {/* Visitor Name */}
              <div>
                <div className={`text-[10px] font-bold tracking-[0.2em] uppercase mb-1 ${
                  theme === 'dark' ? 'text-gray-600' : 'text-gray-400'
                }`}>
                  Visitor
                </div>
                <div className={`text-xl font-black tracking-tight ${
                  theme === 'dark' ? 'text-white' : 'text-black'
                }`}>
                  {attendeeName}
                </div>
              </div>

              {/* Position & Company - Side by side */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <div className={`text-[10px] font-bold tracking-[0.2em] uppercase mb-1 ${
                    theme === 'dark' ? 'text-gray-600' : 'text-gray-400'
                  }`}>
                    Position
                  </div>
                  <div className={`text-sm font-semibold leading-tight ${
                    theme === 'dark' ? 'text-gray-300' : 'text-gray-700'
                  }`}>
                    {attendeePosition || 'Visitor'}
                  </div>
                </div>
                <div>
                  <div className={`text-[10px] font-bold tracking-[0.2em] uppercase mb-1 ${
                    theme === 'dark' ? 'text-gray-600' : 'text-gray-400'
                  }`}>
                    Company
                  </div>
                  <div className={`text-sm font-semibold leading-tight ${
                    theme === 'dark' ? 'text-gray-300' : 'text-gray-700'
                  }`}>
                    {companyName}
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Visit Details - Compact Grid */}
          <div className={`pt-3 border-t ${
            theme === 'dark' ? 'border-white/10' : 'border-black/10'
          }`}>
            <div className="grid grid-cols-3 gap-3 text-center">
              <div>
                <div className={`text-[9px] font-bold tracking-widest uppercase mb-1 ${
                  theme === 'dark' ? 'text-gray-600' : 'text-gray-400'
                }`}>
                  Date
                </div>
                <div className={`text-xs font-bold ${
                  theme === 'dark' ? 'text-white' : 'text-black'
                }`}>
                  {format(new Date(date), 'MMM d')}
                </div>
                <div className={`text-[10px] ${
                  theme === 'dark' ? 'text-gray-500' : 'text-gray-500'
                }`}>
                  {format(new Date(date), 'yyyy')}
                </div>
              </div>
              <div>
                <div className={`text-[9px] font-bold tracking-widest uppercase mb-1 ${
                  theme === 'dark' ? 'text-gray-600' : 'text-gray-400'
                }`}>
                  Time
                </div>
                <div className={`text-xs font-bold ${
                  theme === 'dark' ? 'text-white' : 'text-black'
                }`}>
                  {startTime}
                </div>
                <div className={`text-[10px] ${
                  theme === 'dark' ? 'text-gray-500' : 'text-gray-500'
                }`}>
                  to {endTime}
                </div>
              </div>
              <div>
                <div className={`text-[9px] font-bold tracking-widest uppercase mb-1 ${
                  theme === 'dark' ? 'text-gray-600' : 'text-gray-400'
                }`}>
                  Duration
                </div>
                <div className={`text-xs font-bold ${
                  theme === 'dark' ? 'text-white' : 'text-black'
                }`}>
                  {duration === 'THREE_HOURS' ? '3h' : '6h'}
                </div>
                <div className={`text-[10px] ${
                  theme === 'dark' ? 'text-gray-500' : 'text-gray-500'
                }`}>
                  {duration === 'SIX_HOURS' ? 'Full Day' : 'Session'}
                </div>
              </div>
            </div>
          </div>

          {/* Footer with ID */}
          <div className={`pt-3 flex items-center justify-between border-t ${
            theme === 'dark' ? 'border-white/10' : 'border-black/10'
          }`}>
            <div className={`text-[8px] font-mono tracking-widest ${
              theme === 'dark' ? 'text-gray-700' : 'text-gray-400'
            }`}>
              #{bookingId.slice(-8).toUpperCase()}
            </div>
            <div className={`text-[8px] font-bold tracking-wider ${
              theme === 'dark' ? 'text-gray-700' : 'text-gray-400'
            }`}>
              AUTHORIZED ACCESS
            </div>
          </div>
        </div>

        {/* Bottom accent stripe */}
        <div className={`h-1 w-full ${theme === 'dark' ? 'bg-white' : 'bg-black'}`} />
      </Card>

      {/* Actions */}
      {showActions && (
        <div className="flex gap-3">
          <Button
            onClick={handleDownload}
            variant="outline"
            className={`flex-1 ${theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}`}
          >
            <Download className="w-4 h-4 mr-2" />
            Copy Link
          </Button>
          <Button
            onClick={handleShare}
            variant="outline"
            className={`flex-1 ${theme === 'dark' ? 'border-zinc-800 bg-zinc-900 text-white hover:bg-zinc-800' : ''}`}
          >
            <Share2 className="w-4 h-4 mr-2" />
            Share
          </Button>
        </div>
      )}
    </div>
  );
}
