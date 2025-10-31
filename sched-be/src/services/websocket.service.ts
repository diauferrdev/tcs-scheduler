import type { ServerWebSocket } from 'bun';

interface WebSocketData {
  userId: string;
  createdAt: number;
}

// Map to store user connections: userId -> Set of WebSocket connections
const userConnections = new Map<string, Set<ServerWebSocket<WebSocketData>>>();

export function addConnection(userId: string, ws: ServerWebSocket<WebSocketData>) {
  if (!userConnections.has(userId)) {
    userConnections.set(userId, new Set());
  }
  userConnections.get(userId)!.add(ws);

  console.log(`[WS] User ${userId} connected. Total connections: ${getTotalConnections()}`);
}

export function removeConnection(userId: string, ws: ServerWebSocket<WebSocketData>) {
  const connections = userConnections.get(userId);
  if (connections) {
    connections.delete(ws);
    if (connections.size === 0) {
      userConnections.delete(userId);
    }
  }

  console.log(`[WS] User ${userId} disconnected. Total connections: ${getTotalConnections()}`);
}

export function sendToUser(userId: string, message: any) {
  const connections = userConnections.get(userId);
  if (!connections || connections.size === 0) {
    console.log(`[WS] No active connections for user ${userId}`);
    return false;
  }

  const messageStr = JSON.stringify(message);
  let sentCount = 0;

  connections.forEach((ws) => {
    try {
      ws.send(messageStr);
      sentCount++;
    } catch (error) {
      console.error(`[WS] Failed to send message to user ${userId}:`, error);
      // Remove dead connection
      connections.delete(ws);
    }
  });

  console.log(`[WS] Sent message to ${sentCount} connection(s) for user ${userId}`);
  return sentCount > 0;
}

export function sendToMultipleUsers(userIds: string[], message: any) {
  const messageStr = JSON.stringify(message);
  let totalSent = 0;

  userIds.forEach((userId) => {
    const connections = userConnections.get(userId);
    if (connections) {
      connections.forEach((ws) => {
        try {
          ws.send(messageStr);
          totalSent++;
        } catch (error) {
          console.error(`[WS] Failed to send to user ${userId}:`, error);
          connections.delete(ws);
        }
      });
    }
  });

  console.log(`[WS] Broadcast to ${totalSent} connection(s) across ${userIds.length} user(s)`);
  return totalSent;
}

export function broadcast(message: any) {
  const messageStr = JSON.stringify(message);
  let totalSent = 0;

  userConnections.forEach((connections) => {
    connections.forEach((ws) => {
      try {
        ws.send(messageStr);
        totalSent++;
      } catch (error) {
        console.error('[WS] Failed to broadcast:', error);
      }
    });
  });

  console.log(`[WS] Broadcast to ${totalSent} total connection(s)`);
  return totalSent;
}

export function getTotalConnections(): number {
  let total = 0;
  userConnections.forEach((connections) => {
    total += connections.size;
  });
  return total;
}

export function getConnectedUserIds(): string[] {
  return Array.from(userConnections.keys());
}

export function isUserConnected(userId: string): boolean {
  return userConnections.has(userId) && userConnections.get(userId)!.size > 0;
}

// Message types for type safety
export type WebSocketMessage =
  | { type: 'connected'; data: any }
  | { type: 'notification'; data: any }
  | { type: 'booking_created'; data: any }
  | { type: 'booking_updated'; data: any }
  | { type: 'booking_deleted'; data: any }
  | { type: 'booking_approved'; data: any }
  | { type: 'participant_response'; data: any }
  | { type: 'bug_created'; data: any }
  | { type: 'bug_updated'; data: any }
  | { type: 'bug_deleted'; data: any }
  | { type: 'bug_liked'; data: any }
  | { type: 'bug_unliked'; data: any }
  | { type: 'bug_comment_created'; data: any }
  | { type: 'bug_comment_updated'; data: any }
  | { type: 'bug_comment_deleted'; data: any }
  | { type: 'ticket_created'; data: any }
  | { type: 'ticket_updated'; data: any }
  | { type: 'ticket_message'; data: any }
  | { type: 'ping' }
  | { type: 'pong' };

// Bug report real-time events
export function broadcastBugCreated(bug: any) {
  return broadcast({ type: 'bug_created', data: bug });
}

export function broadcastBugUpdated(bug: any) {
  return broadcast({ type: 'bug_updated', data: bug });
}

export function broadcastBugDeleted(bugId: string) {
  return broadcast({ type: 'bug_deleted', data: { id: bugId } });
}

export function broadcastBugLiked(bugId: string, userId: string, likeCount: number) {
  return broadcast({ type: 'bug_liked', data: { bugId, userId, likeCount } });
}

export function broadcastBugUnliked(bugId: string, userId: string, likeCount: number) {
  return broadcast({ type: 'bug_unliked', data: { bugId, userId, likeCount } });
}

export function broadcastBugCommentCreated(comment: any) {
  return broadcast({ type: 'bug_comment_created', data: comment });
}

export function broadcastBugCommentUpdated(comment: any) {
  return broadcast({ type: 'bug_comment_updated', data: comment });
}

export function broadcastBugCommentDeleted(commentId: string, bugReportId: string) {
  return broadcast({ type: 'bug_comment_deleted', data: { id: commentId, bugReportId } });
}

export function sendNotification(userId: string, notification: any) {
  return sendToUser(userId, {
    type: 'notification',
    data: notification,
  });
}

export function sendBookingUpdate(userIds: string[], booking: any) {
  return sendToMultipleUsers(userIds, {
    type: 'booking_updated',
    data: booking,
  });
}

export function broadcastBookingCreated(booking: any) {
  return broadcast({
    type: 'booking_created',
    data: { booking },
  });
}

export function broadcastBookingUpdated(booking: any) {
  return broadcast({
    type: 'booking_updated',
    data: { booking },
  });
}

export function broadcastBookingDeleted(bookingId: string) {
  return broadcast({
    type: 'booking_deleted',
    data: { bookingId },
  });
}

export function broadcastBookingApproved(booking: any) {
  return broadcast({
    type: 'booking_approved',
    data: { booking },
  });
}

export function sendParticipantResponse(userIds: string[], response: any) {
  return sendToMultipleUsers(userIds, {
    type: 'participant_response',
    data: response,
  });
}

// Ticket real-time events
export function broadcastTicketCreated(ticket: any) {
  return broadcast({ type: 'ticket_created', data: ticket });
}

export function broadcastTicketUpdated(ticket: any) {
  return broadcast({ type: 'ticket_updated', data: ticket });
}

export function sendTicketMessage(userIds: string[], message: any) {
  return sendToMultipleUsers(userIds, {
    type: 'ticket_message',
    data: message,
  });
}
