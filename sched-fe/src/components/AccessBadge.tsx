import { QRCodeSVG } from 'qrcode.react';
import { format } from 'date-fns';
import { Button } from './ui/button';
import { Card } from './ui/card';
import { Download, Share2, Printer } from 'lucide-react';
import html2canvas from 'html2canvas';
import { useRef, useEffect } from 'react';

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
  hideCopyLink?: boolean;
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
  hideCopyLink = false,
}: AccessBadgeProps) {
  const cardRef = useRef<HTMLDivElement>(null);

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

  // Mouse tracking for holographic effect - Desktop only
  useEffect(() => {
    const card = cardRef.current;
    if (!card) return;

    // Check if device is mobile/tablet
    const isMobile = window.matchMedia('(max-width: 767px)').matches;
    if (isMobile) return;

    const handleMouseMove = (e: MouseEvent) => {
      const rect = card.getBoundingClientRect();
      const x = ((e.clientX - rect.left) / rect.width) * 100;
      const y = ((e.clientY - rect.top) / rect.height) * 100;

      // Calculate distance from center (0 at center, 1 at edges)
      const centerX = 50;
      const centerY = 50;
      const distanceX = Math.abs(x - centerX) / 50;
      const distanceY = Math.abs(y - centerY) / 50;
      const distanceFromCenter = Math.min(Math.sqrt(distanceX * distanceX + distanceY * distanceY), 1);

      card.style.setProperty('--pointer-x', `${x}%`);
      card.style.setProperty('--pointer-y', `${y}%`);
      card.style.setProperty('--pointer-from-center', distanceFromCenter.toString());
    };

    const handleMouseLeave = () => {
      card.style.setProperty('--pointer-from-center', '0');
    };

    card.addEventListener('mousemove', handleMouseMove);
    card.addEventListener('mouseleave', handleMouseLeave);

    return () => {
      card.removeEventListener('mousemove', handleMouseMove);
      card.removeEventListener('mouseleave', handleMouseLeave);
    };
  }, []);

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

  const handlePrint = async () => {
    const badgeElement = document.getElementById(`badge-${bookingId}-${attendeeName.replace(/\s/g, '-')}`);
    if (!badgeElement) {
      console.error('Badge element not found');
      return;
    }

    try {
      // Hide corner accents before capture (html2canvas doesn't support clip-path)
      const cornerAccents = badgeElement.querySelectorAll('.absolute.top-0');
      cornerAccents.forEach(el => {
        const element = el as HTMLElement;
        if (element.style.clipPath) {
          element.style.display = 'none';
        }
      });

      // Capture badge as image with high quality
      const canvas = await html2canvas(badgeElement, {
        scale: 3,
        backgroundColor: null,
        logging: false,
        useCORS: true,
      });

      // Restore corner accents after capture
      cornerAccents.forEach(el => {
        const element = el as HTMLElement;
        if (element.style.clipPath) {
          element.style.display = '';
        }
      });

      const badgeImageData = canvas.toDataURL('image/png');

      // Create print window with foldable layout
      const printWindow = window.open('', '_blank');
      if (!printWindow) return;

      // Calculate badge dimensions to match back side
      const badgeHeight = canvas.height;
      const badgeWidth = canvas.width;
      const aspectRatio = badgeWidth / badgeHeight;

      const printContent = `
        <!DOCTYPE html>
        <html>
          <head>
            <meta charset="UTF-8">
            <title>TCS PacePort Access Ticket - ${attendeeName}</title>
            <style>
              @page {
                size: A4 portrait;
                margin: 10mm;
              }

              * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
              }

              body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: white;
                color: #000;
                -webkit-print-color-adjust: exact;
                print-color-adjust: exact;
                display: flex;
                justify-content: center;
                align-items: center;
                min-height: 100vh;
              }

              .print-wrapper {
                width: 100%;
                max-width: 450px;
                margin: 0 auto;
              }

              .print-container {
                position: relative;
                background: white;
              }

              /* Cut lines - outside container */
              .cut-line {
                position: absolute;
                background: #999;
              }

              .cut-line-top {
                top: -10px;
                left: 0;
                right: 0;
                height: 1px;
              }

              .cut-line-bottom {
                bottom: -10px;
                left: 0;
                right: 0;
                height: 1px;
              }

              .cut-line-left {
                left: -10px;
                top: 0;
                bottom: 0;
                width: 1px;
              }

              .cut-line-right {
                right: -10px;
                top: 0;
                bottom: 0;
                width: 1px;
              }

              .cut-marker {
                position: absolute;
                width: 8px;
                height: 8px;
                border: 1px solid #999;
              }

              .cut-marker-tl { top: -10px; left: -10px; border-right: none; border-bottom: none; }
              .cut-marker-tr { top: -10px; right: -10px; border-left: none; border-bottom: none; }
              .cut-marker-bl { bottom: -10px; left: -10px; border-right: none; border-top: none; }
              .cut-marker-br { bottom: -10px; right: -10px; border-left: none; border-top: none; }

              /* Back Half - Information (Top) - Upside down */
              .back-half {
                width: 100%;
                min-height: ${badgeHeight / 3}px;
                padding: 30px 25px;
                display: flex;
                flex-direction: column;
                transform: rotate(180deg);
                border: 3px solid #000;
                border-bottom: none;
                background: white;
              }

              .back-content {
                flex: 1;
                display: flex;
                flex-direction: column;
              }

              .back-header {
                text-align: center;
                padding-bottom: 12px;
                border-bottom: 2px solid #000;
                margin-bottom: 15px;
              }

              .back-header h1 {
                font-size: 20px;
                font-weight: 800;
                letter-spacing: -0.3px;
                margin-bottom: 3px;
              }

              .back-header .subtitle {
                font-size: 9px;
                color: #666;
                text-transform: uppercase;
                letter-spacing: 1.2px;
                font-weight: 600;
              }

              .info-grid {
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 12px 18px;
                margin-bottom: 12px;
              }

              .info-block.full-width {
                grid-column: 1 / -1;
              }

              .info-label {
                font-size: 7px;
                font-weight: 700;
                color: #999;
                text-transform: uppercase;
                letter-spacing: 0.8px;
                margin-bottom: 3px;
              }

              .info-value {
                font-size: 11px;
                font-weight: 600;
                color: #000;
                line-height: 1.2;
              }

              .info-value.large {
                font-size: 14px;
                font-weight: 700;
              }

              .section-divider {
                height: 1px;
                background: #e5e5e5;
                margin: 12px 0;
              }

              .instructions-box {
                background: #f5f5f5;
                border-left: 2px solid #000;
                padding: 10px 12px;
                margin: 12px 0;
              }

              .instructions-box h3 {
                font-size: 8px;
                font-weight: 700;
                text-transform: uppercase;
                letter-spacing: 0.6px;
                margin-bottom: 6px;
              }

              .instructions-box p {
                font-size: 8px;
                line-height: 1.4;
                color: #333;
              }

              .back-footer {
                margin-top: auto;
                padding-top: 10px;
                border-top: 1px solid #e5e5e5;
                display: flex;
                justify-content: space-between;
                align-items: center;
              }

              .ticket-id {
                font-size: 8px;
                font-family: 'Courier New', monospace;
                font-weight: 600;
                color: #666;
              }

              .footer-logo {
                font-size: 7px;
                color: #999;
                text-transform: uppercase;
                letter-spacing: 0.6px;
              }

              /* Fold line */
              .fold-line {
                width: 100%;
                height: 0;
                border-top: 2px dashed #ccc;
                position: relative;
              }

              .fold-instruction {
                position: absolute;
                top: 50%;
                left: 50%;
                transform: translate(-50%, -50%);
                background: white;
                padding: 0 10px;
                font-size: 8px;
                color: #999;
                text-transform: uppercase;
                letter-spacing: 1px;
                white-space: nowrap;
              }

              /* Front Half - Badge (Bottom) */
              .front-half {
                width: 100%;
                display: flex;
                align-items: center;
                justify-content: center;
                position: relative;
              }

              .badge-image {
                width: 100%;
                height: auto;
                display: block;
              }

              @media print {
                body {
                  -webkit-print-color-adjust: exact;
                  print-color-adjust: exact;
                }

                .fold-instruction {
                  display: none;
                }

                @page {
                  margin: 10mm;
                }
              }
            </style>
          </head>
          <body>
            <div class="print-wrapper">
              <div class="print-container">

                <!-- Cut lines -->
                <div class="cut-line cut-line-top"></div>
                <div class="cut-line cut-line-bottom"></div>
                <div class="cut-line cut-line-left"></div>
                <div class="cut-line cut-line-right"></div>

                <!-- Cut markers -->
                <div class="cut-marker cut-marker-tl"></div>
                <div class="cut-marker cut-marker-tr"></div>
                <div class="cut-marker cut-marker-bl"></div>
                <div class="cut-marker cut-marker-br"></div>

                <!-- BACK HALF (Top - Upside down for folding) -->
                <div class="back-half">
                  <div class="back-content">

                    <div class="back-header">
                      <h1>TCS PACEPORT</h1>
                      <div class="subtitle">Visitor Information & Access Details</div>
                    </div>

                    <div class="info-grid">
                      <div class="info-block">
                        <div class="info-label">📍 Address</div>
                        <div class="info-value">R. Quatá, 67 - Vila Olímpia<br>São Paulo - SP, 04546-040</div>
                      </div>

                      <div class="info-block">
                        <div class="info-label">🕐 Business Hours</div>
                        <div class="info-value">Mon-Fri: 9:00 AM - 6:00 PM<br>Sat-Sun: Closed</div>
                      </div>
                    </div>

                    <div class="section-divider"></div>

                    <div class="info-grid">
                      <div class="info-block">
                        <div class="info-label">📞 Reception</div>
                        <div class="info-value">+55 11 3003-0000</div>
                      </div>

                      <div class="info-block">
                        <div class="info-label">✉️ Contact</div>
                        <div class="info-value">paceport@tcs.com</div>
                      </div>
                    </div>

                    <div class="section-divider"></div>

                    <div class="instructions-box">
                      <h3>📋 Check-in Instructions</h3>
                      <p>
                        1. Present this badge at main reception desk<br>
                        2. Valid ID required for security verification<br>
                        3. Visitor badge must remain visible<br>
                        4. Follow all security protocols during visit
                      </p>
                    </div>

                    <div class="instructions-box" style="background: #000; color: #fff; border-left: 3px solid #fff;">
                      <h3 style="color: #fff;">⚠️ Important Notes</h3>
                      <p style="color: #e5e5e5;">
                        • No photography without authorization<br>
                        • Wi-Fi: Guest credentials at reception<br>
                        • Emergency exit: Follow green signs
                      </p>
                    </div>

                    <div class="back-footer">
                      <div class="ticket-id">ID: ${bookingId.slice(-8).toUpperCase()}</div>
                      <div class="footer-logo">AUTHORIZED ACCESS</div>
                    </div>

                  </div>
                </div>

                <!-- FOLD LINE -->
                <div class="fold-line">
                  <div class="fold-instruction">✂ FOLD HERE ✂</div>
                </div>

                <!-- FRONT HALF (Bottom - Badge) -->
                <div class="front-half">
                  <img src="${badgeImageData}" alt="Access Badge" class="badge-image">
                </div>

              </div>
            </div>

            <script>
              window.onload = function() {
                setTimeout(() => {
                  window.print();
                  window.onafterprint = function() {
                    window.close();
                  };
                }, 300);
              };
            </script>
          </body>
        </html>
      `;

      printWindow.document.write(printContent);
      printWindow.document.close();
    } catch (error) {
      console.error('Error generating print:', error);
    }
  };

  return (
    <div className="space-y-4 w-full max-w-md mx-auto px-2 md:px-0">
      <Card
        ref={cardRef}
        id={`badge-${bookingId}-${attendeeName.replace(/\s/g, '-')}`}
        className={`holo-card relative overflow-hidden border-2 md:border-[3px] touch-manipulation ${
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
                  PacePort São Paulo
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
        <div className="flex flex-col md:flex-row gap-2 md:gap-3 print:hidden">
          {!hideCopyLink && (
            <Button
              onClick={handleDownload}
              className={`flex-1 text-sm md:text-base ${
                theme === 'dark'
                  ? 'bg-white text-black hover:bg-gray-200 border-white'
                  : 'bg-black text-white hover:bg-gray-800 border-black'
              }`}
            >
              <Download className="w-4 h-4 mr-2" />
              Copy Link
            </Button>
          )}
          <div className="flex gap-2 md:gap-3">
            <Button
              onClick={handleShare}
              variant="outline"
              className={`flex-1 text-sm md:text-base ${
                theme === 'dark'
                  ? 'border-white text-white hover:bg-white hover:text-black'
                  : 'border-black text-black hover:bg-black hover:text-white'
              }`}
            >
              <Share2 className="w-4 h-4 mr-2" />
              Share
            </Button>
            <Button
              onClick={handlePrint}
              variant="outline"
              className={`flex-1 text-sm md:text-base ${
                theme === 'dark'
                  ? 'border-white text-white hover:bg-white hover:text-black'
                  : 'border-black text-black hover:bg-black hover:text-white'
              }`}
            >
              <Printer className="w-4 h-4 mr-2" />
              Print
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
