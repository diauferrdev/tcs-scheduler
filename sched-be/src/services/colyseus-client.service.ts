import { Client, Room } from 'colyseus.js';

// Colyseus URL - uses environment variable or defaults to local
// For production with ngrok: wss://shingly-adulatingly-lakia.ngrok-free.dev
const COLYSEUS_URL = process.env.COLYSEUS_URL || 'ws://localhost:2567';

class ColyseusClientService {
  private client: Client;
  private notificationRoom: Room | null = null;
  private calendarRoom: Room | null = null;

  constructor() {
    this.client = new Client(COLYSEUS_URL);
  }

  async ensureNotificationRoom(organization: string): Promise<Room> {
    if (this.notificationRoom && this.notificationRoom.connection.isOpen) {
      return this.notificationRoom;
    }

    try {
      this.notificationRoom = await this.client.joinOrCreate('notifications', {
        organization,
        source: 'backend',
      });

      console.log('[Colyseus] Connected to notification room');
      return this.notificationRoom;
    } catch (error) {
      console.error('[Colyseus] Failed to connect to notification room:', error);
      throw error;
    }
  }

  async ensureCalendarRoom(organization: string): Promise<Room> {
    if (this.calendarRoom && this.calendarRoom.connection.isOpen) {
      return this.calendarRoom;
    }

    try {
      this.calendarRoom = await this.client.joinOrCreate('calendar', {
        organization,
        source: 'backend',
      });

      console.log('[Colyseus] Connected to calendar room');
      return this.calendarRoom;
    } catch (error) {
      console.error('[Colyseus] Failed to connect to calendar room:', error);
      throw error;
    }
  }

  async sendNotification(organization: string, userId: string, notification: any) {
    try {
      const room = await this.ensureNotificationRoom(organization);
      room.send('send_notification', {
        userId,
        notification,
      });
    } catch (error) {
      console.error('[Colyseus] Error sending notification:', error);
    }
  }

  async broadcastBookingUpdate(organization: string, booking: any, action: 'created' | 'updated' | 'deleted') {
    try {
      const room = await this.ensureCalendarRoom(organization);
      room.send(`booking_${action}`, { booking });
    } catch (error) {
      console.error('[Colyseus] Error broadcasting booking update:', error);
    }
  }

  disconnect() {
    if (this.notificationRoom) {
      this.notificationRoom.leave();
      this.notificationRoom = null;
    }
    if (this.calendarRoom) {
      this.calendarRoom.leave();
      this.calendarRoom = null;
    }
  }
}

export const colyseusClient = new ColyseusClientService();
