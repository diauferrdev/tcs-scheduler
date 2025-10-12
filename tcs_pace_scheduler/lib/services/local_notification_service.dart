import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'navigation_service.dart';
import 'calendar_service.dart';

// Export NotificationResponse for use in main.dart background handler
export 'package:flutter_local_notifications/flutter_local_notifications.dart' show NotificationResponse;

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize local notifications with background handler support
  /// Does NOT request permissions - call requestPermissions() after login
  Future<void> initialize({
    void Function(NotificationResponse)? onBackgroundNotificationResponse,
  }) async {
    if (_initialized) {
      debugPrint('[LocalNotification] Already initialized');
      return;
    }

    try {
      debugPrint('[LocalNotification] Starting initialization...');

      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/tcs_pace_scheduler');

      // iOS initialization settings - DO NOT request permissions during initialization
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,  // Changed to false
        requestBadgePermission: false,  // Changed to false
        requestSoundPermission: false,  // Changed to false
      );

      // Linux initialization settings
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        linux: linuxSettings,
      );

      // Initialize with both foreground and background handlers
      debugPrint('[LocalNotification] Calling _notifications.initialize()...');
      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
        onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationResponse,
      );

      debugPrint('[LocalNotification] Plugin initialized: $initialized');

      // CRITICAL: Create notification channels for Android 8.0+
      await _createNotificationChannels();

      _initialized = true;
      debugPrint('[LocalNotification] ✅ Initialized (permissions NOT requested yet)');
    } catch (e, stackTrace) {
      debugPrint('[LocalNotification] ❌ Initialization error: $e');
      debugPrint('[LocalNotification] Stack trace: $stackTrace');

      // CRITICAL: Set initialized to true anyway for basic functionality
      // Even if there were errors, we want to try showing notifications
      _initialized = true;
      debugPrint('[LocalNotification] ⚠️ Initialized with errors (will try to show notifications anyway)');
    }
  }

  /// Create notification channels (Android 8.0+)
  /// WITHOUT channels, Android SILENTLY IGNORES notifications
  Future<void> _createNotificationChannels() async {
    debugPrint('[LocalNotification] _createNotificationChannels() called');

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin == null) {
      debugPrint('[LocalNotification] Not Android, skipping channel creation');
      return;
    }

    try {
      debugPrint('[LocalNotification] Creating notification channels...');

      // Bookings channel (high importance)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'bookings',
          'Bookings',
          description: 'Notifications about new bookings, updates, and cancellations',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFF4CAF50),
        ),
      );

      // Reminders channel (max importance)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'reminders',
          'Reminders',
          description: 'Booking reminder notifications',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFFFF9800),
        ),
      );

      // Invitations channel (default importance)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'invitations',
          'Invitations',
          description: 'Notifications about sent invitations',
          importance: Importance.defaultImportance,
          playSound: true,
          enableVibration: false,
        ),
      );

      // Test channel (max importance)
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'test',
          'Test',
          description: 'Test notifications',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFF673AB7),
        ),
      );

      debugPrint('[LocalNotification] ✅ Notification channels created');
    } catch (e) {
      debugPrint('[LocalNotification] Error creating channels: $e');
    }
  }

  /// Request notification permissions (Android 13+ / iOS)
  /// CALL THIS AFTER USER LOGS IN
  Future<bool> requestPermissions() async {
    try {
      debugPrint('[LocalNotification] Requesting permissions...');

      // Request Android permissions (API 33+)
      final androidPermission = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      debugPrint('[LocalNotification] Android permission: $androidPermission');

      // Request iOS permissions
      final iosPermission = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );

      debugPrint('[LocalNotification] iOS permission: $iosPermission');

      final granted = (androidPermission != false && iosPermission != false);

      if (!granted) {
        debugPrint('[LocalNotification] ⚠️ Notification permissions denied');
      } else {
        debugPrint('[LocalNotification] ✅ Notification permissions granted');
      }

      return granted;
    } catch (e) {
      debugPrint('[LocalNotification] Error requesting permissions: $e');
      return false;
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[LocalNotification] Notification tapped');
    debugPrint('[LocalNotification] Payload: ${response.payload}');
    debugPrint('[LocalNotification] Action ID: ${response.actionId}');

    _handleNotificationAction(response.payload, response.actionId);
  }

  /// Handle notification action (tap or action button)
  Future<void> _handleNotificationAction(String? payload, String? actionId) async {
    if (payload == null) {
      debugPrint('[LocalNotification] No payload, navigating to notifications');
      _navigateToNotifications();
      return;
    }

    try {
      // Import navigation and calendar services dynamically to avoid circular dependencies
      final navigationService = _getNavigationService();
      final calendarService = _getCalendarService();

      // Parse JSON payload
      final data = _parsePayload(payload);
      final type = data['type'] as String?;
      final bookingId = data['bookingId'] as String?;
      final metadata = data['metadata'] as Map<String, dynamic>?;

      debugPrint('[LocalNotification] Type: $type, BookingId: $bookingId, ActionId: $actionId');

      // Handle action buttons
      if (actionId != null) {
        await _handleActionButton(actionId, metadata, calendarService, navigationService);
        return;
      }

      // Handle notification tap - navigate to booking details if bookingId exists
      if (bookingId != null) {
        debugPrint('[LocalNotification] Navigating to booking details: $bookingId');
        navigationService.navigateToBookingDetails(bookingId);
      } else {
        // Fallback to old behavior if no bookingId
        debugPrint('[LocalNotification] No bookingId, using fallback navigation');
        switch (type) {
          case 'BOOKING_APPROVED':
          case 'BOOKING_CONFIRMED':
          case 'BOOKING_INVITATION':
            navigationService.navigateToCalendar();
            break;
          case 'BOOKING_PENDING_APPROVAL':
            navigationService.navigateToApprovals();
            break;
          case 'BOOKING_UPDATED':
          case 'BOOKING_RESCHEDULED':
          case 'BOOKING_CANCELLED':
            navigationService.navigateToCalendar();
            break;
          default:
            navigationService.navigateToNotifications();
        }
      }

      debugPrint('[LocalNotification] ✅ Navigation handled for type: $type');
    } catch (e) {
      debugPrint('[LocalNotification] Error handling notification action: $e');
      _navigateToNotifications();
    }
  }

  /// Handle action button press
  Future<void> _handleActionButton(
    String actionId,
    Map<String, dynamic>? metadata,
    dynamic calendarService,
    dynamic navigationService,
  ) async {
    debugPrint('[LocalNotification] Handling action: $actionId');

    switch (actionId) {
      case 'calendar':
        // Add to calendar
        if (metadata != null && calendarService != null) {
          final success = await calendarService.addBookingToCalendar(
            companyName: metadata['companyName'] ?? 'Visit',
            date: metadata['date'] ?? '',
            time: metadata['time'] ?? '09:00',
            sector: metadata['sector'],
            expectedAttendees: metadata['expectedAttendees'],
            eventType: metadata['eventType'],
          );

          if (success) {
            navigationService?.showSnackBar('✅ Added to calendar!');
          } else {
            navigationService?.showSnackBar('Could not add to calendar', isError: true);
          }
        }
        break;

      case 'view':
        // View details - navigate to calendar
        navigationService?.navigateToCalendar();
        break;

      case 'reschedule':
        // Navigate to calendar for rescheduling
        navigationService?.navigateToCalendar();
        navigationService?.showSnackBar('Select a new date and time');
        break;

      case 'dismiss':
        // Just dismiss, no action
        debugPrint('[LocalNotification] Notification dismissed');
        break;

      default:
        debugPrint('[LocalNotification] Unknown action: $actionId');
    }
  }

  /// Parse JSON payload safely
  Map<String, dynamic> _parsePayload(String payload) {
    try {
      // Try to parse as JSON
      return _jsonDecode(payload);
    } catch (e) {
      // If not JSON, return simple map with type
      return {'type': payload};
    }
  }

  /// JSON decode helper
  Map<String, dynamic> _jsonDecode(String str) {
    try {
      final decoded = jsonDecode(str);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {'type': str};
    } catch (e) {
      debugPrint('[LocalNotification] Error decoding JSON: $e');
      return {'type': str};
    }
  }

  /// Get navigation service
  NavigationService _getNavigationService() {
    return NavigationService();
  }

  /// Get calendar service
  CalendarService _getCalendarService() {
    return CalendarService();
  }

  /// Navigate to notifications screen (fallback)
  void _navigateToNotifications() {
    final navigationService = NavigationService();
    navigationService.navigateToNotifications();
  }

  /// Build JSON payload for notification
  String _buildPayload({
    required String type,
    String? bookingId,
    Map<String, dynamic>? metadata,
  }) {
    final payload = {
      'type': type,
      if (bookingId != null) 'bookingId': bookingId,
      if (metadata != null) 'metadata': metadata,
    };
    return jsonEncode(payload);
  }

  /// Show notification for new booking
  Future<void> showNewBookingNotification({
    required String companyName,
    required String date,
    required String time,
    String? sector,
    int? expectedAttendees,
    String? eventType,
    String? bookingId,
  }) async {
    try {
      debugPrint('[LocalNotification] 📅 showNewBookingNotification() called');
      debugPrint('[LocalNotification] Company: $companyName, Date: $date, Time: $time');

      if (!_initialized) {
        debugPrint('[LocalNotification] ⚠️ Service not initialized, cannot show notification');
        return;
      }

      final lines = <String>[
      '📅 Date: $date at $time',
      if (sector != null) '🏢 Sector: $sector',
      if (expectedAttendees != null) '👥 Attendees: $expectedAttendees people',
      if (eventType != null) '🎯 Type: $eventType',
      '📍 Location: TCS PacePort São Paulo',
    ];

    final androidDetails = AndroidNotificationDetails(
      'bookings',
      'Bookings',
      channelDescription: 'Notifications about new bookings',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/tcs_pace_scheduler',
      color: Color(0xFF4CAF50), // Green
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
      styleInformation: InboxStyleInformation(
        lines,
        contentTitle: '🎉 New Booking - $companyName',
        summaryText: 'Tap to view details',
      ),
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF4CAF50),
      ledOnMs: 1000,
      ledOffMs: 500,
      // Force heads-up display (ping no topo da tela)
      ticker: '🎉 New Booking - $companyName',
      setAsGroupSummary: false,
      autoCancel: true,
      onlyAlertOnce: false, // CRITICAL: Always alert for each notification
      fullScreenIntent: true, // Show as heads-up even with DND
      actions: [
        AndroidNotificationAction(
          'view',
          'View Details',
          icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'calendar',
          'Add to Calendar',
          icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'New Booking Scheduled',
    );

    const linuxDetails = LinuxNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
      debugPrint('[LocalNotification] Calling _notifications.show() with ID: $notificationId');

      // Build payload with bookingId for navigation
      final payload = _buildPayload(
        type: 'BOOKING_CONFIRMED',
        bookingId: bookingId,
        metadata: {
          'companyName': companyName,
          'date': date,
          'time': time,
          if (sector != null) 'sector': sector,
          if (expectedAttendees != null) 'expectedAttendees': expectedAttendees,
          if (eventType != null) 'eventType': eventType,
        },
      );

      await _notifications.show(
        notificationId,
        '🎉 New Booking Created',
        '$companyName scheduled a visit for $date at $time',
        details,
        payload: payload,
      );

      debugPrint('[LocalNotification] ✅ New booking notification shown');
    } catch (e, stackTrace) {
      debugPrint('[LocalNotification] ❌ Error showing new booking notification: $e');
      debugPrint('[LocalNotification] Stack trace: $stackTrace');
    }
  }

  /// Show notification for booking update
  Future<void> showBookingUpdatedNotification({
    required String companyName,
    required String changes,
    String? previousDate,
    String? newDate,
    String? previousTime,
    String? newTime,
    String? bookingId,
  }) async {
    final changesList = <String>[
      if (previousDate != null && newDate != null)
        '📅 Date: $previousDate → $newDate',
      if (previousTime != null && newTime != null)
        '⏰ Time: $previousTime → $newTime',
      '📝 Changes: $changes',
      '✅ Update confirmed',
    ];

    final androidDetails = AndroidNotificationDetails(
      'bookings',
      'Bookings',
      channelDescription: 'Notifications about booking updates',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/tcs_pace_scheduler',
      color: Color(0xFF2196F3), // Blue
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
      styleInformation: InboxStyleInformation(
        changesList,
        contentTitle: '🔄 Booking Updated - $companyName',
        summaryText: 'See what changed',
      ),
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF2196F3),
      ledOnMs: 1000,
      ledOffMs: 500,
      // Force heads-up display
      ticker: '🔄 Booking Updated - $companyName',
      setAsGroupSummary: false,
      autoCancel: true,
      onlyAlertOnce: false,
      fullScreenIntent: true,
      actions: [
        AndroidNotificationAction(
          'view',
          'View Changes',
          icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'dismiss',
          'Got it',
          icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'Booking Modified',
    );

    const linuxDetails = LinuxNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

    // Build payload with bookingId for navigation
    final payload = _buildPayload(
      type: 'BOOKING_UPDATED',
      bookingId: bookingId,
      metadata: {
        'companyName': companyName,
        if (previousDate != null) 'previousDate': previousDate,
        if (newDate != null) 'newDate': newDate,
        if (previousTime != null) 'previousTime': previousTime,
        if (newTime != null) 'newTime': newTime,
      },
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '🔄 Booking Updated',
      '$companyName booking has been updated: $changes',
      details,
      payload: payload,
    );
  }

  /// Show notification for booking cancellation
  Future<void> showBookingCancelledNotification({
    required String companyName,
    required String date,
    String? reason,
    String? time,
    String? bookingId,
  }) async{
    final detailsList = <String>[
      '📅 Cancelled Date: $date${time != null ? ' at $time' : ''}',
      if (reason != null) '📝 Reason: $reason',
      '⚠️ Time slot has been released',
      '💡 You can reschedule anytime',
    ];

    final androidDetails = AndroidNotificationDetails(
      'bookings',
      'Bookings',
      channelDescription: 'Notifications about booking cancellations',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/tcs_pace_scheduler',
      color: Color(0xFFF44336), // Red
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
      styleInformation: InboxStyleInformation(
        detailsList,
        contentTitle: '❌ Booking Cancelled - $companyName',
        summaryText: 'Reschedule whenever you want',
      ),
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFFF44336),
      ledOnMs: 1000,
      ledOffMs: 500,
      // Force heads-up display
      ticker: '❌ Booking Cancelled - $companyName',
      setAsGroupSummary: false,
      autoCancel: true,
      onlyAlertOnce: false,
      fullScreenIntent: true,
      actions: [
        AndroidNotificationAction(
          'reschedule',
          'Reschedule',
          icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'dismiss',
          'Got it',
          icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'Booking Cancelled',
    );

    const linuxDetails = LinuxNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

    // Build payload with bookingId for navigation
    final payload = _buildPayload(
      type: 'BOOKING_CANCELLED',
      bookingId: bookingId,
      metadata: {
        'companyName': companyName,
        'date': date,
        if (time != null) 'time': time,
        if (reason != null) 'reason': reason,
      },
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '❌ Booking Cancelled',
      '$companyName booking for $date has been cancelled',
      details,
      payload: payload,
    );
  }

  /// Show notification for booking approval
  Future<void> showBookingApprovedNotification({
    required String companyName,
    required String date,
    String? time,
    String? approvedBy,
    String? bookingId,
  }) async {
    final detailsList = <String>[
      '✅ Booking confirmed and approved',
      '📅 Date: $date${time != null ? ' at $time' : ''}',
      if (approvedBy != null) '👤 Approved by: $approvedBy',
      '📍 Location: TCS PacePort São Paulo',
      '📧 Invitations will be sent soon',
    ];

    final androidDetails = AndroidNotificationDetails(
      'bookings',
      'Bookings',
      channelDescription: 'Notifications about booking approvals',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/tcs_pace_scheduler',
      color: Color(0xFF4CAF50), // Green
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
      styleInformation: InboxStyleInformation(
        detailsList,
        contentTitle: '✅ Booking Approved - $companyName',
        summaryText: 'All set!',
      ),
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFF4CAF50),
      ledOnMs: 1000,
      ledOffMs: 500,
      // Force heads-up display
      ticker: '✅ Booking Approved - $companyName',
      setAsGroupSummary: false,
      autoCancel: true,
      onlyAlertOnce: false,
      fullScreenIntent: true,
      actions: [
        AndroidNotificationAction(
          'calendar',
          'Add to Calendar',
          icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'view',
          'View Details',
          icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'Booking Confirmed',
    );

    const linuxDetails = LinuxNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

    // Build payload with bookingId and metadata for "Add to Calendar" functionality
    final payload = _buildPayload(
      type: 'BOOKING_APPROVED',
      bookingId: bookingId,
      metadata: {
        'companyName': companyName,
        'date': date,
        'time': time ?? '09:00',
        if (approvedBy != null) 'approvedBy': approvedBy,
      },
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '✅ Booking Approved',
      '$companyName booking for $date has been approved!',
      details,
      payload: payload,
    );
  }

  /// Show notification for booking reminder
  Future<void> showBookingReminderNotification({
    required String companyName,
    required String time,
    int? minutesUntil,
    String? location,
  }) async {
    final reminderList = <String>[
      '⏰ Time: $time',
      if (minutesUntil != null) '⏱️ Starts in: $minutesUntil minutes',
      '🏢 Company: $companyName',
      '📍 Location: ${location ?? 'TCS PacePort São Paulo'}',
      '💼 Prepare necessary materials',
    ];

    final androidDetails = AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Booking reminder notifications',
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/tcs_pace_scheduler',
      color: Color(0xFFFF9800), // Orange
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
      styleInformation: InboxStyleInformation(
        reminderList,
        contentTitle: '⏰ Reminder - $companyName Visit',
        summaryText: 'Visit is coming up!',
      ),
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFFFF9800),
      ledOnMs: 1000,
      ledOffMs: 500,
      // Force heads-up display
      ticker: '⏰ Reminder - $companyName Visit',
      setAsGroupSummary: false,
      autoCancel: true,
      onlyAlertOnce: false,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.reminder,
      actions: [
        AndroidNotificationAction(
          'directions',
          'Get Directions',
          icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'checklist',
          'View Checklist',
          icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'snooze',
          'Remind in 10min',
          icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'Visit coming up',
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    const linuxDetails = LinuxNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '⏰ Visit Reminder',
      '$companyName visit starts soon at $time!',
      details,
      payload: 'reminder',
    );
  }

  /// Show notification for invitation sent
  Future<void> showInvitationSentNotification({
    required String email,
    String? companyName,
    int? totalInvitees,
  }) async {
    final invitationList = <String>[
      '📧 Email: $email',
      if (companyName != null) '🏢 Company: $companyName',
      if (totalInvitees != null && totalInvitees > 1)
        '👥 Total invitees: $totalInvitees',
      '✅ Invitation sent successfully',
      '📬 Guest will receive email shortly',
    ];

    final androidDetails = AndroidNotificationDetails(
      'invitations',
      'Invitations',
      channelDescription: 'Notifications about sent invitations',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/tcs_pace_scheduler',
      color: Color(0xFF9C27B0), // Purple
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
      styleInformation: InboxStyleInformation(
        invitationList,
        contentTitle: '📧 Invitation Sent',
        summaryText: 'Email delivered',
      ),
      playSound: true,
      enableVibration: false,
      // Force individual display
      ticker: '📧 Invitation Sent',
      setAsGroupSummary: false,
      autoCancel: true,
      onlyAlertOnce: false,
      actions: [
        AndroidNotificationAction(
          'view',
          'View Guest List',
          icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
          showsUserInterface: true,
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'Invitation Sent',
    );

    const linuxDetails = LinuxNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      '📧 Invitation Sent',
      'Invitation sent to $email successfully!',
      details,
      payload: 'invitation_sent',
    );
  }

  /// Test notification (for debug button)
  Future<void> showTestNotification() async {
    try {
      debugPrint('[LocalNotification] 🧪 showTestNotification() called');
      debugPrint('[LocalNotification] Initialized: $_initialized');

      if (!_initialized) {
        debugPrint('[LocalNotification] ⚠️ Service not initialized, cannot show notification');
        return;
      }

      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
      debugPrint('[LocalNotification] Notification ID: $notificationId');

      final testList = <String>[
        '✅ Notification system working',
        '🎨 Rich design with InboxStyle',
        '🔔 Sound and vibration configured',
        '💡 Colored LED activated',
        '🎯 Action buttons available',
        '📱 Compatible with Android 14+',
      ];

      final androidDetails = AndroidNotificationDetails(
        'test',
        'Test',
        channelDescription: 'Test notifications',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/tcs_pace_scheduler',
        color: Color(0xFF673AB7), // Deep Purple
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
        styleInformation: InboxStyleInformation(
          testList,
          contentTitle: '🔔 Notification System Test',
          summaryText: 'Everything working perfectly!',
        ),
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFF673AB7),
        ledOnMs: 1000,
        ledOffMs: 500,
        // Force heads-up display
        ticker: '🔔 Test Notification',
        setAsGroupSummary: false,
        autoCancel: true,
        onlyAlertOnce: false,
        fullScreenIntent: true,
        actions: [
          AndroidNotificationAction(
            'test_action_1',
            '✅ It Worked!',
            icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
          ),
          AndroidNotificationAction(
            'test_action_2',
            '🎉 Perfect!',
            icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
          ),
          AndroidNotificationAction(
            'dismiss',
            'Close',
            icon: DrawableResourceAndroidBitmap('@mipmap/tcs_pace_scheduler'),
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        subtitle: 'System Test',
      );

      const linuxDetails = LinuxNotificationDetails();

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        linux: linuxDetails,
      );

      debugPrint('[LocalNotification] Calling _notifications.show()...');
      await _notifications.show(
        notificationId,
        '🔔 Test Notification',
        'This is a test notification from TCS PacePort Scheduler system!',
        details,
        payload: 'test',
      );
      debugPrint('[LocalNotification] ✅ Notification shown successfully');
    } catch (e, stackTrace) {
      debugPrint('[LocalNotification] ❌ Error showing test notification: $e');
      debugPrint('[LocalNotification] Stack trace: $stackTrace');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancel specific notification
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
