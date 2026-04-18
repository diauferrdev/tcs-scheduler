import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import '../config/api_config.dart';
import '../config/http_config.dart';
import 'token_storage.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final TokenStorage _tokenStorage = TokenStorage();
  final http.Client _client = HttpConfig.createClient();
  String? _sessionCookie;
  bool _initialized = false;

  /// Initialize ApiService and load persisted session cookie
  Future<void> initialize() async {
    if (_initialized) return;

    final savedCookie = await _tokenStorage.readSessionCookie();
    if (savedCookie != null) {
      _sessionCookie = savedCookie;
    }
    _initialized = true;
  }

  Future<void> setSessionCookie(String? cookie) async {
    _sessionCookie = cookie;
    if (cookie != null) {
      await _tokenStorage.saveSessionCookie(cookie);
    } else {
      await _tokenStorage.deleteSessionCookie();
    }
  }

  String? getSessionCookie() {
    return _sessionCookie;
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    await initialize();

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await _client
        .get(url, headers: headers)
        .timeout(ApiConfig.timeout);

    await _extractAndSaveCookies(response, endpoint);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await initialize();

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await _client
        .post(url, headers: headers, body: jsonEncode(data))
        .timeout(ApiConfig.timeout);

    await _extractAndSaveCookies(response, endpoint);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await initialize();

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await _client
        .put(url, headers: headers, body: jsonEncode(data))
        .timeout(ApiConfig.timeout);

    _extractAndSaveCookies(response, endpoint);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await initialize();

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await _client
        .patch(url, headers: headers, body: jsonEncode(data))
        .timeout(ApiConfig.timeout);

    _extractAndSaveCookies(response, endpoint);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    await initialize();

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await _client
        .delete(url, headers: headers)
        .timeout(ApiConfig.timeout);

    _extractAndSaveCookies(response, endpoint);
    return _handleResponse(response);
  }

  /// Extract and save cookies from response header
  Future<void> _extractAndSaveCookies(http.Response response, String endpoint) async {
    final setCookieHeader = response.headers['set-cookie'];

    if (setCookieHeader != null) {
      final cookiePairs = <String>[];
      final cookiesList = setCookieHeader.split(RegExp(r',(?=\s*\w+=)'));
      for (var cookie in cookiesList) {
        final cookieValue = cookie.split(';')[0].trim();
        if (cookieValue.isNotEmpty) {
          cookiePairs.add(cookieValue);
        }
      }
      if (cookiePairs.isNotEmpty) {
        _sessionCookie = cookiePairs.join('; ');
        await _tokenStorage.saveSessionCookie(_sessionCookie!);
      }
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {};
      }
      final decoded = jsonDecode(response.body);
      // If response is a list, wrap it in a map
      if (decoded is List) {
        return {'data': decoded};
      }
      return decoded as Map<String, dynamic>;
    } else if (response.statusCode == 401) {
      throw UnauthorizedException();
    } else {
      final error = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : {'error': 'Request failed'};

      // Handle error field - it could be a string or an object
      String errorMessage = 'Unknown error';
      if (error['error'] != null) {
        if (error['error'] is String) {
          errorMessage = error['error'] as String;
        } else if (error['error'] is Map) {
          // If error is an object, try to extract message
          final errorObj = error['error'] as Map;
          errorMessage = errorObj['message']?.toString() ?? errorObj.toString();
        } else {
          errorMessage = error['error'].toString();
        }
      } else if (error['message'] != null) {
        errorMessage = error['message'].toString();
      }

      throw ApiException(errorMessage, response.statusCode);
    }
  }

  // Dashboard Methods
  Future<Map<String, dynamic>> getDashboardStats() async {
    return await get('/api/dashboard/stats');
  }

  // Analytics Methods (legacy - for backwards compatibility)

  Future<List<dynamic>> getBookingsByMonth(int year) async {
    final response = await get('/api/analytics/bookings-by-month/$year');
    return response['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getBookingsBySector(int year) async {
    final response = await get('/api/analytics/bookings-by-sector?year=$year');
    return response['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getBookingsByInterest(int year) async {
    final response = await get('/api/analytics/bookings-by-interest?year=$year');
    return response['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getTrends(int months) async {
    final response = await get('/api/analytics/trends?months=$months');
    return response['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getTopCompanies(int limit) async {
    final response = await get('/api/analytics/top-companies?limit=$limit');
    return response['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getHourlyBookings() async {
    final response = await get('/api/analytics/hourly-bookings');
    return response['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getResponseRate() async {
    return await get('/api/analytics/response-rate');
  }

  Future<List<dynamic>> getPopularTimeSlots() async {
    final response = await get('/api/analytics/popular-time-slots');
    return response['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getClientInsights() async {
    return await get('/api/analytics/client-insights');
  }

  Future<List<dynamic>> getBookingTrends(int months) async {
    final response = await get('/api/analytics/booking-trends?months=$months');
    return response['data'] as List<dynamic>;
  }

  // Invitations Methods
  Future<dynamic> getInvitations({int limit = 50, int offset = 0}) async {
    return await get('/api/invitations?limit=$limit&offset=$offset');
  }

  Future<Map<String, dynamic>> createInvitation({
    String? email,
    int expiresInDays = 7,
  }) async {
    return await post('/api/invitations', {
      if (email != null) 'email': email,
      'expiresInDays': expiresInDays,
    });
  }

  Future<Map<String, dynamic>> validateInvitationToken(String token) async {
    return await get('/api/invitations/$token/validate');
  }

  // Users Methods
  Future<dynamic> getUsers() async {
    return await get('/api/auth/users');
  }

  Future<Map<String, dynamic>> createUser({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    return await post('/api/auth/users', {
      'email': email,
      'password': password,
      'name': name,
      'role': role,
    });
  }

  Future<Map<String, dynamic>> deleteUser(String userId) async {
    return await delete('/api/auth/users/$userId');
  }

  Future<dynamic> getPendingUsers() async {
    return await get('/api/auth/users/pending');
  }

  Future<Map<String, dynamic>> approveUser(String userId, List<String> roles) async {
    return await post('/api/auth/users/$userId/approve', {
      'roles': roles,
    });
  }

  Future<Map<String, dynamic>> resetUserPassword(String userId, String newPassword) async {
    return await _client
        .patch(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/users/$userId/password'),
          headers: {
            ...ApiConfig.defaultHeaders,
            if (_sessionCookie != null) 'Cookie': _sessionCookie!,
          },
          body: jsonEncode({'password': newPassword}),
        )
        .timeout(ApiConfig.timeout)
        .then(_handleResponse);
  }

  // Activity Logs Methods
  Future<dynamic> getActivityLogs({
    String? userId,
    String? action,
    String? resource,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String>[];
    if (userId != null) queryParams.add('userId=$userId');
    if (action != null) queryParams.add('action=$action');
    if (resource != null) queryParams.add('resource=$resource');
    if (search != null) queryParams.add('search=$search');
    queryParams.add('limit=$limit');
    queryParams.add('offset=$offset');

    final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return await get('/api/audit$query');
  }

  // Bookings Methods
  Future<dynamic> getBookings({
    String? month,
    String? status,
  }) async {
    final queryParams = <String>[];
    if (month != null) queryParams.add('month=$month');
    if (status != null) queryParams.add('status=$status');

    final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return await get('/api/bookings$query');
  }

  Future<Map<String, dynamic>> getBookingById(String id) async {
    return await get('/api/bookings/$id');
  }

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/bookings');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await _client
        .post(url, headers: headers, body: jsonEncode(data))
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateBooking(String id, Map<String, dynamic> data) async {
    return await _client
        .patch(
          Uri.parse('${ApiConfig.baseUrl}/api/bookings/$id'),
          headers: {
            ...ApiConfig.defaultHeaders,
            if (_sessionCookie != null) 'Cookie': _sessionCookie!,
          },
          body: jsonEncode(data),
        )
        .timeout(ApiConfig.timeout)
        .then(_handleResponse);
  }

  Future<Map<String, dynamic>> deleteBooking(String id) async {
    return await delete('/api/bookings/$id');
  }

  Future<dynamic> getBookingsAvailability(String? month) async {
    final query = month != null ? '?month=$month' : '';
    return await get('/api/bookings/availability$query');
  }

  /// Get bookings availability for Admin/Manager
  Future<dynamic> getBookingsAvailabilityForAdmins(String? month) async {
    final query = month != null ? '?month=$month' : '';
    return await get('/api/bookings/availability-admin$query');
  }

  Future<Map<String, dynamic>> checkAvailability(String date, {String? visitType}) async {
    final query = visitType != null ? '?visitType=$visitType' : '';
    return await get('/api/bookings/availability/$date$query');
  }

  Future<Map<String, dynamic>> getAttendeeById(String attendeeId) async {
    return await get('/api/bookings/attendee/$attendeeId');
  }

  Future<Map<String, dynamic>> approveBooking(String id) async {
    return await post('/api/bookings/$id/approve', {});
  }

  Future<Map<String, dynamic>> rescheduleBooking(
    String id,
    String date,
    String startTime,
    String duration,
  ) async {
    return await post('/api/bookings/$id/reschedule', {
      'date': date,
      'startTime': startTime,
      'duration': duration,
    });
  }

  // ==================== NEW STATUS MANAGEMENT METHODS ====================

  /// Manager/Admin: Request edit (CREATED/UNDER_REVIEW → NEED_EDIT)
  Future<Map<String, dynamic>> requestEdit(String id, {String? message}) async {
    return await post('/api/bookings/$id/request-edit', {
      if (message != null) 'message': message,
    });
  }

  /// Manager/Admin: Request reschedule (CREATED/UNDER_REVIEW → NEED_RESCHEDULE)
  Future<Map<String, dynamic>> requestReschedule(String id, {String? message}) async {
    return await post('/api/bookings/$id/request-reschedule', {
      if (message != null) 'message': message,
    });
  }

  /// Manager/Admin: Reject booking (CREATED/UNDER_REVIEW → NOT_APPROVED)
  Future<Map<String, dynamic>> rejectBooking(String id, String rejectionReason) async {
    return await post('/api/bookings/$id/reject', {
      'rejectionReason': rejectionReason,
    });
  }

  /// Manager/Admin: Cancel booking (ANY → CANCELLED)
  Future<Map<String, dynamic>> cancelBooking(String id, String cancellationReason) async {
    return await post('/api/bookings/$id/cancel', {
      'cancellationReason': cancellationReason,
    });
  }

  /// User: Reschedule when status is NEED_RESCHEDULE (NEED_RESCHEDULE → UNDER_REVIEW)
  Future<Map<String, dynamic>> userRescheduleBooking(
    String id,
    String date,
    String startTime,
    String duration,
  ) async {
    return await post('/api/bookings/$id/user-reschedule', {
      'date': date,
      'startTime': startTime,
      'duration': duration,
    });
  }

  /// Manager/Admin: Mark as under review (CREATED → UNDER_REVIEW)
  Future<Map<String, dynamic>> markBookingAsUnderReview(String id) async {
    return await post('/api/bookings/$id/mark-under-review', {});
  }

  /// Get questionnaire questions by event type
  Future<dynamic> getQuestionnaire({String? eventType}) async {
    final query = eventType != null ? '?eventType=$eventType' : '';
    return await get('/api/bookings/questionnaire$query');
  }

  // Notifications Methods
  Future<dynamic> getNotifications({
    bool? isRead,
    String? type,
    int limit = 50,
    int offset = 0,
  }) async {
    final queryParams = <String>[];
    if (isRead != null) queryParams.add('isRead=$isRead');
    if (type != null) queryParams.add('type=$type');
    queryParams.add('limit=$limit');
    queryParams.add('offset=$offset');

    final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return await get('/api/notifications$query');
  }

  Future<Map<String, dynamic>> markNotificationAsRead(String notificationId) async {
    return await _client
        .patch(
          Uri.parse('${ApiConfig.baseUrl}/api/notifications/$notificationId/read'),
          headers: {
            ...ApiConfig.defaultHeaders,
            if (_sessionCookie != null) 'Cookie': _sessionCookie!,
          },
        )
        .timeout(ApiConfig.timeout)
        .then(_handleResponse);
  }

  Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    return await post('/api/notifications/mark-all-read', {});
  }

  Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
    return await delete('/api/notifications/$notificationId');
  }

  Future<Map<String, dynamic>> sendTestNotification({
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    return await post('/api/test-notifications/send-test', {
      'type': type,
      'title': title,
      'message': message,
      if (metadata != null) 'metadata': metadata,
    });
  }

  // Get confirmed bookings (for calendar/agenda)
  Future<dynamic> getConfirmedBookings({String? month}) async {
    return await getBookings(month: month, status: 'APPROVED');
  }

  // FCM Methods
  /// Register FCM token with backend
  Future<void> registerFCMToken(String token, {String? deviceInfo}) async {
    try {
      await post('/api/fcm/register', {
        'token': token,
        if (deviceInfo != null) 'deviceInfo': deviceInfo,
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Unregister FCM token from backend
  Future<void> unregisterFCMToken(String token) async {
    try {
      await post('/api/fcm/unregister', {'token': token});
    } catch (e) {
      rethrow;
    }
  }

  /// Send test FCM notification to all devices (ADMIN only)
  Future<Map<String, dynamic>> sendTestFCMNotification() async {
    try {
      final response = await post('/api/fcm/test-notification', {});
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // User Profile Methods

  /// Change current user's password
  Future<Map<String, dynamic>> changePassword(Map<String, dynamic> data) async {
    return await post('/api/auth/me/change-password', data);
  }

  /// Update current user's profile (name, email)
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return await _client
        .patch(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/me/profile'),
          headers: {
            ...ApiConfig.defaultHeaders,
            if (_sessionCookie != null) 'Cookie': _sessionCookie!,
          },
          body: jsonEncode(data),
        )
        .timeout(ApiConfig.timeout)
        .then(_handleResponse);
  }

  /// Upload avatar image (multipart/form-data)
  /// Works on both mobile and web by accepting bytes directly
  Future<Map<String, dynamic>> uploadAvatar(List<int> fileBytes, String fileName) async {
    await initialize();

    final url = Uri.parse('${ApiConfig.baseUrl}/api/upload/avatar');
    final request = http.MultipartRequest('POST', url);

    // Add all necessary headers
    request.headers.addAll({
      ...ApiConfig.defaultHeaders,
      'Accept': 'application/json',
    });

    // Remove Content-Type as it will be set automatically by MultipartRequest
    request.headers.remove('Content-Type');

    // Add session cookie
    if (_sessionCookie != null) {
      request.headers['Cookie'] = _sessionCookie!;
    } else {
    }

    // Detect MIME type from file extension
    MediaType? contentType;
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        contentType = MediaType('image', 'jpeg');
        break;
      case 'png':
        contentType = MediaType('image', 'png');
        break;
      case 'gif':
        contentType = MediaType('image', 'gif');
        break;
      case 'webp':
        contentType = MediaType('image', 'webp');
        break;
      default:
        contentType = MediaType('image', 'jpeg'); // fallback
    }

    // Add file from bytes (works on web and mobile)
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: contentType,
    ));


    // Send using the same client to maintain session
    final streamedResponse = await _client.send(request).timeout(const Duration(minutes: 2));
    final response = await http.Response.fromStream(streamedResponse);


    return _handleResponse(response);
  }

  /// Upload attachment (image, video, or document) for tickets
  /// Works on both mobile and web by accepting bytes directly
  Future<Map<String, dynamic>> uploadAttachment(List<int> fileBytes, String fileName) async {
    await initialize();

    final url = Uri.parse('${ApiConfig.baseUrl}/api/upload/attachment');
    final request = http.MultipartRequest('POST', url);

    // Add all necessary headers
    request.headers.addAll({
      ...ApiConfig.defaultHeaders,
      'Accept': 'application/json',
    });

    // Remove Content-Type as it will be set automatically by MultipartRequest
    request.headers.remove('Content-Type');

    // Add session cookie
    if (_sessionCookie != null) {
      request.headers['Cookie'] = _sessionCookie!;
    }

    // Detect MIME type from file extension
    MediaType contentType = _getMediaType(fileName);

    // Add file from bytes (works on web and mobile)
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: contentType,
    ));


    // Send using the same client to maintain session
    final streamedResponse = await _client.send(request).timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);


    return _handleResponse(response);
  }

  /// Helper to get MediaType from file extension
  MediaType _getMediaType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;

    // Images
    if (['jpg', 'jpeg'].contains(extension)) return MediaType('image', 'jpeg');
    if (extension == 'png') return MediaType('image', 'png');
    if (extension == 'gif') return MediaType('image', 'gif');
    if (extension == 'webp') return MediaType('image', 'webp');

    // Videos
    if (extension == 'mp4') return MediaType('video', 'mp4');
    if (extension == 'webm') return MediaType('video', 'webm');
    if (extension == 'mov') return MediaType('video', 'quicktime');

    // Audio
    if (extension == 'm4a') return MediaType('audio', 'mp4');
    if (extension == 'mp3') return MediaType('audio', 'mpeg');
    if (extension == 'wav') return MediaType('audio', 'wav');
    if (extension == 'ogg') return MediaType('audio', 'ogg');
    if (extension == 'aac') return MediaType('audio', 'aac');
    if (extension == 'webm') return MediaType('audio', 'webm');

    // Documents
    if (extension == 'pdf') return MediaType('application', 'pdf');
    if (extension == 'doc') return MediaType('application', 'msword');
    if (extension == 'docx') return MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
    if (extension == 'xls') return MediaType('application', 'vnd.ms-excel');
    if (extension == 'xlsx') return MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    if (extension == 'csv') return MediaType('text', 'csv');
    if (extension == 'txt') return MediaType('text', 'plain');

    // Fallback
    return MediaType('application', 'octet-stream');
  }

  // ==================== BUG REPORTS METHODS ====================

  /// Get all bug reports with optional filters
  Future<dynamic> getBugReports({
    String? status,
    String? platform,
    String? search,
    String? sortBy,
    String? order,
  }) async {
    final queryParams = <String>[];
    if (status != null) queryParams.add('status=$status');
    if (platform != null) queryParams.add('platform=$platform');
    if (search != null) queryParams.add('search=$search');
    if (sortBy != null) queryParams.add('sortBy=$sortBy');
    if (order != null) queryParams.add('order=$order');

    final query = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    return await get('/api/feedback$query');
  }

  /// Get bug report by ID
  Future<Map<String, dynamic>> getBugReportById(String id) async {
    return await get('/api/feedback/$id');
  }

  /// Create bug report
  Future<Map<String, dynamic>> createBugReport({
    required String title,
    required String description,
    required String platform,
    Map<String, dynamic>? deviceInfo,
    dynamic attachments, // Can be List<String> or List<Map<String, dynamic>>
  }) async {
    return await post('/api/feedback', {
      'title': title,
      'description': description,
      'platform': platform,
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
      if (attachments != null) 'attachments': attachments,
    });
  }

  /// Update bug report (ADMIN/MANAGER only for status changes)
  Future<Map<String, dynamic>> updateBugReport(
    String id,
    Map<String, dynamic> data,
  ) async {
    return await _client
        .patch(
          Uri.parse('${ApiConfig.baseUrl}/api/feedback/$id'),
          headers: {
            ...ApiConfig.defaultHeaders,
            if (_sessionCookie != null) 'Cookie': _sessionCookie!,
          },
          body: jsonEncode(data),
        )
        .timeout(ApiConfig.timeout)
        .then(_handleResponse);
  }

  /// Delete bug report (ADMIN only)
  Future<Map<String, dynamic>> deleteBugReport(String id) async {
    return await delete('/api/feedback/$id');
  }

  /// Like a bug report
  Future<Map<String, dynamic>> likeBugReport(String id) async {
    return await post('/api/feedback/$id/like', {});
  }

  /// Unlike a bug report
  Future<Map<String, dynamic>> unlikeBugReport(String id) async {
    return await delete('/api/feedback/$id/like');
  }

  /// Check if user has liked a bug report
  Future<bool> hasLikedBug(String id) async {
    final response = await get('/api/feedback/$id/liked');
    return response['liked'] as bool;
  }

  /// Get bug statistics (ADMIN only)
  Future<Map<String, dynamic>> getBugStatistics() async {
    return await get('/api/feedback/stats/overview');
  }

  /// Get comments for a bug report
  Future<dynamic> getBugComments(String bugId) async {
    return await get('/api/feedback/$bugId/comments');
  }

  /// Create comment on bug report
  Future<Map<String, dynamic>> createBugComment(
    String bugId,
    String content, {
    Map<String, dynamic>? deviceInfo,
  }) async {
    return await post('/api/feedback/$bugId/comments', {
      'content': content,
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
    });
  }

  /// Update comment
  Future<Map<String, dynamic>> updateBugComment(
    String commentId,
    String content,
  ) async {
    return await _client
        .patch(
          Uri.parse('${ApiConfig.baseUrl}/api/feedback/comments/$commentId'),
          headers: {
            ...ApiConfig.defaultHeaders,
            if (_sessionCookie != null) 'Cookie': _sessionCookie!,
          },
          body: jsonEncode({'content': content}),
        )
        .timeout(ApiConfig.timeout)
        .then(_handleResponse);
  }

  /// Delete comment
  Future<Map<String, dynamic>> deleteBugComment(String commentId) async {
    return await delete('/api/feedback/comments/$commentId');
  }

  /// Upload attachments for comment (up to 6)
  Future<Map<String, dynamic>> uploadCommentAttachments(
    String commentId,
    List<PlatformFile> files,
  ) async {
    await initialize();


    final url = Uri.parse('${ApiConfig.baseUrl}/api/feedback/comments/$commentId/attachments');
    final request = http.MultipartRequest('POST', url);

    request.headers.addAll({
      ...ApiConfig.defaultHeaders,
      'Accept': 'application/json',
    });

    // Remove Content-Type to let browser set multipart boundary
    request.headers.remove('Content-Type');

    // Add session cookie
    if (_sessionCookie != null) {
      request.headers['Cookie'] = _sessionCookie!;
    } else {
    }

    // Add all files
    for (var file in files) {
      if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          file.bytes!,
          filename: file.name,
        ));
      }
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);


    if (response.statusCode == 201 || response.statusCode == 200) {
      // Extract and save any cookies from response
      await _extractAndSaveCookies(response, '/api/feedback/comments/$commentId/attachments');
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload comment attachments (${response.statusCode}): ${response.body}');
    }
  }

  /// Upload attachment for bug report (images/videos)
  Future<Map<String, dynamic>> uploadBugAttachment(
    List<int> fileBytes,
    String fileName,
    String fileType,
  ) async {
    await initialize();

    final url = Uri.parse('${ApiConfig.baseUrl}/api/upload/attachment');
    final request = http.MultipartRequest('POST', url);

    request.headers.addAll({
      ...ApiConfig.defaultHeaders,
      'Accept': 'application/json',
    });
    request.headers.remove('Content-Type');

    if (_sessionCookie != null) {
      request.headers['Cookie'] = _sessionCookie!;
    }

    // Detect MIME type based on fileType parameter and file extension
    MediaType? contentType;
    final extension = fileName.toLowerCase().split('.').last;

    if (fileType.startsWith('image/')) {
      switch (extension) {
        case 'jpg':
        case 'jpeg':
          contentType = MediaType('image', 'jpeg');
          break;
        case 'png':
          contentType = MediaType('image', 'png');
          break;
        case 'gif':
          contentType = MediaType('image', 'gif');
          break;
        case 'webp':
          contentType = MediaType('image', 'webp');
          break;
        case 'svg':
          contentType = MediaType('image', 'svg+xml');
          break;
        default:
          contentType = MediaType('image', 'jpeg');
      }
    } else if (fileType.startsWith('video/')) {
      switch (extension) {
        case 'mp4':
          contentType = MediaType('video', 'mp4');
          break;
        case 'mov':
          contentType = MediaType('video', 'quicktime');
          break;
        case 'avi':
          contentType = MediaType('video', 'x-msvideo');
          break;
        case 'webm':
          contentType = MediaType('video', 'webm');
          break;
        case 'ogg':
          contentType = MediaType('video', 'ogg');
          break;
        default:
          contentType = MediaType('video', 'mp4');
      }
    } else if (fileType.startsWith('application/') || fileType.startsWith('text/')) {
      // Handle documents and text files
      switch (extension) {
        case 'pdf':
          contentType = MediaType('application', 'pdf');
          break;
        case 'doc':
          contentType = MediaType('application', 'msword');
          break;
        case 'docx':
          contentType = MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
          break;
        case 'xls':
          contentType = MediaType('application', 'vnd.ms-excel');
          break;
        case 'xlsx':
          contentType = MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
          break;
        case 'ppt':
          contentType = MediaType('application', 'vnd.ms-powerpoint');
          break;
        case 'pptx':
          contentType = MediaType('application', 'vnd.openxmlformats-officedocument.presentationml.presentation');
          break;
        case 'txt':
          contentType = MediaType('text', 'plain');
          break;
        case 'csv':
          contentType = MediaType('text', 'csv');
          break;
        default:
          // Use the fileType parameter directly if we don't have specific mapping
          final parts = fileType.split('/');
          if (parts.length == 2) {
            contentType = MediaType(parts[0], parts[1]);
          } else {
            contentType = MediaType('application', 'octet-stream');
          }
      }
    } else {
      contentType = MediaType('application', 'octet-stream');
    }

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: contentType,
    ));


    final streamedResponse = await _client.send(request).timeout(const Duration(minutes: 5));
    final response = await http.Response.fromStream(streamedResponse);


    return _handleResponse(response);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  @override
  String toString() => 'Unauthorized';
}
