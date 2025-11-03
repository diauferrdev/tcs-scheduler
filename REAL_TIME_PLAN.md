# Real-time Chat System - Complete Rebuild Plan

## Problems Identified:
1. ❌ Typing/Recording indicators not showing in UI
2. ❌ Read receipts not updating in real-time
3. ❌ Attachment names still showing (should show [image], [audio], etc.)
4. ❌ WebSocket messages not being properly received/handled

## Root Causes:
1. WebSocket listeners may not be properly connected to ticket ID
2. State updates not triggering UI rebuilds
3. Backend typing/recording endpoints may not be broadcasting correctly
4. Read receipt flow incomplete (missing update triggers)

## Complete Rebuild Strategy:

### Phase 1: Fix Attachment Display (Simple Text Labels)
- Replace all attachment filenames with semantic labels
- [image] for images
- [video] for videos
- [audio] for audio files
- [document] for PDFs and other files
- Show in message preview and bubble subtitle

### Phase 2: Backend WebSocket Events
- Ensure typing/recording events broadcast to correct users
- Add comprehensive logging for all WS sends
- Test event delivery with backend logs

### Phase 3: Frontend WebSocket Listeners
- Rebuild listeners with proper ticketId filtering
- Add console.log for every WS event received
- Ensure setState() called on every relevant event

### Phase 4: Typing Indicator
- Send on every keystroke (debounced 3s)
- Clear on message send
- Display at bottom of chat (not in message list)
- Show "{userName} is typing..."

### Phase 5: Recording Indicator
- Send when recording starts
- Send when recording stops/cancels
- Display at bottom of chat
- Show "{userName} is recording audio..."

### Phase 6: Read Receipts
- Mark read on message receive (if chat open)
- Mark read on entering chat
- Send individual message_read events (not bulk)
- Update checkmark immediately on WS receive

### Phase 7: Testing Protocol
- Test typing: Open 2 browsers, type in one, verify other shows indicator
- Test recording: Start recording in one, verify other shows indicator
- Test read: Send message, open chat, verify sender sees blue checkmark
- Test badges: Send message, verify badge increases, open chat, verify badge decreases

## Implementation Order:
1. ✅ Fix attachment display text
2. ✅ Add backend logging
3. ✅ Rebuild frontend WS listeners
4. ✅ Test typing indicator end-to-end
5. ✅ Test recording indicator end-to-end
6. ✅ Test read receipts end-to-end
7. ✅ Deploy and verify in production
