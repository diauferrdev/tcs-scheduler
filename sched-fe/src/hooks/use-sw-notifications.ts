import { useEffect, useCallback, useState } from 'react';
import { useAuth } from '@/lib/auth';
import { api } from '@/lib/api';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

/**
 * Sistema robusto de notificações usando APENAS Service Worker
 * Funciona SOMENTE quando PWA está instalado (standalone mode)
 * Envia notificações detalhadas sobre novos bookings
 */
export function useSWNotifications() {
  const { user } = useAuth();
  const [isInstalled, setIsInstalled] = useState(false);
  const [isServiceWorkerReady, setIsServiceWorkerReady] = useState(false);
  const [permission, setPermission] = useState<NotificationPermission>('default');

  // Verificar se PWA está instalado
  useEffect(() => {
    const checkInstalled = () => {
      const isStandalone = window.matchMedia('(display-mode: standalone)').matches;
      const isIOSStandalone = (window.navigator as any).standalone === true;
      const installed = isStandalone || isIOSStandalone;

      setIsInstalled(installed);

      if (!installed) {
        console.log('⚠️ PWA não instalado. Notificações desabilitadas.');
      } else {
        console.log('✅ PWA instalado. Notificações disponíveis.');
      }

      return installed;
    };

    checkInstalled();
  }, []);

  // Verificar Service Worker
  useEffect(() => {
    if (!isInstalled) return;

    if (!('serviceWorker' in navigator) || !('Notification' in window)) {
      console.error('❌ Notificações não suportadas');
      return;
    }

    navigator.serviceWorker.ready
      .then((registration) => {
        console.log('✅ Service Worker pronto:', registration.scope);
        setIsServiceWorkerReady(true);
        setPermission(Notification.permission);
      })
      .catch((err) => {
        console.error('❌ Service Worker error:', err);
      });
  }, [isInstalled]);

  /**
   * Solicitar permissão de notificação
   */
  const requestPermission = useCallback(async (): Promise<boolean> => {
    if (!isInstalled || !isServiceWorkerReady) {
      return false;
    }

    if (Notification.permission === 'granted') {
      return true;
    }

    if (Notification.permission === 'denied') {
      return false;
    }

    try {
      const result = await Notification.requestPermission();
      setPermission(result);

      if (result === 'granted') {
        console.log('✅ Permissão de notificação concedida');

        // Notificação de boas-vindas
        await showBookingNotification({
          title: 'Notificações Ativadas!',
          message: 'Você receberá atualizações sobre novos agendamentos',
          tag: 'welcome',
        });

        return true;
      }

      return false;
    } catch (err) {
      console.error('❌ Erro ao solicitar permissão:', err);
      return false;
    }
  }, [isInstalled, isServiceWorkerReady]);

  /**
   * Mostrar notificação de booking com detalhes completos
   */
  const showBookingNotification = useCallback(
    async (options: {
      title: string;
      message: string;
      bookingId?: string;
      tag?: string;
      data?: any;
    }): Promise<boolean> => {
      if (!isInstalled || !isServiceWorkerReady || Notification.permission !== 'granted') {
        return false;
      }

      try {
        const registration = await navigator.serviceWorker.ready;

        await registration.showNotification(options.title, {
          body: options.message,
          icon: '/pwa-192x192.png',
          badge: '/pwa-maskable-192x192.png',
          tag: options.tag || 'booking-notification',
          requireInteraction: true, // Permanece até usuário interagir
          data: {
            url: options.bookingId ? `/calendar?booking=${options.bookingId}` : '/calendar',
            bookingId: options.bookingId,
            ...options.data,
          },
        } as NotificationOptions);

        console.log('✅ Notificação enviada:', options.title);
        return true;
      } catch (err) {
        console.error('❌ Erro ao mostrar notificação:', err);
        return false;
      }
    },
    [isInstalled, isServiceWorkerReady]
  );

  /**
   * Sistema de polling para novos bookings
   * Apenas para admins/managers com PWA instalado
   */
  useEffect(() => {
    if (!user || user.role === 'GUEST') {
      return;
    }

    if (!isInstalled || !isServiceWorkerReady) {
      return;
    }

    console.log('🚀 Sistema de notificações ativo para:', user.name);

    let lastBookingId: string | null = null;
    let pollInterval: NodeJS.Timeout | null = null;

    const checkNewBookings = async () => {
      try {
        const response = await api.get('/api/bookings/latest');
        const booking = response.data;

        if (booking && booking.id !== lastBookingId) {
          if (lastBookingId !== null) {
            // Novo booking detectado - montar notificação detalhada
            console.log('📬 Novo agendamento:', booking.companyName);

            // Formatar data e hora
            const bookingDate = new Date(booking.date);
            const dateFormatted = format(bookingDate, "dd 'de' MMMM", { locale: ptBR });
            const timeFormatted = booking.startTime;
            const duration = booking.duration === 'THREE_HOURS' ? '3 horas' : '6 horas';

            // Título da notificação
            const title = '🔔 Novo Agendamento!';

            // Mensagem detalhada
            const message = `${booking.companyName}
📅 ${dateFormatted} às ${timeFormatted}
⏱️ Duração: ${duration}
👤 ${booking.contactName}`;

            await showBookingNotification({
              title,
              message,
              bookingId: booking.id,
              tag: `booking-${booking.id}`,
              data: {
                companyName: booking.companyName,
                contactName: booking.contactName,
                date: booking.date,
                startTime: booking.startTime,
                duration: booking.duration,
              },
            });
          }

          lastBookingId = booking.id;
        }
      } catch (err) {
        // Silencioso
      }
    };

    // Solicitar permissão e iniciar polling
    requestPermission().then((granted) => {
      if (granted) {
        console.log('✅ Polling iniciado (a cada 10 segundos)');
        pollInterval = setInterval(checkNewBookings, 10000);
        checkNewBookings(); // Check inicial
      }
    });

    return () => {
      if (pollInterval) {
        console.log('🛑 Polling parado');
        clearInterval(pollInterval);
      }
    };
  }, [user, isInstalled, isServiceWorkerReady, showBookingNotification, requestPermission]);

  return {
    isInstalled,
    isServiceWorkerReady,
    permission,
    isReady: isInstalled && isServiceWorkerReady && permission === 'granted',
    requestPermission,
    showBookingNotification,
  };
}
