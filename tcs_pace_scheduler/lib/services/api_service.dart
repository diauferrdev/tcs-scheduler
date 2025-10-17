import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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

  String? getSessionCookie() => _sessionCookie;

  Future<Map<String, dynamic>> get(String endpoint) async {
    await initialize(); // Ensure session cookie is loaded

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await _client
        .get(url, headers: headers)
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await initialize(); // Ensure session cookie is loaded

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await _client
        .post(url, headers: headers, body: jsonEncode(data))
        .timeout(ApiConfig.timeout);

    // Extract session cookies from response header (if present)
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

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    await initialize(); // Ensure session cookie is loaded

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await _client
        .put(url, headers: headers, body: jsonEncode(data))
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    await initialize(); // Ensure session cookie is loaded

    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await _client
        .delete(url, headers: headers)
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
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
    return await get('/api/activity-logs$query');
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

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data, {bool isDraft = false}) async {
    final query = isDraft ? '?draft=true' : '';
    final url = Uri.parse('${ApiConfig.baseUrl}/api/bookings$query');
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

  /// Get bookings availability for Admin/Manager (includes PENDING_APPROVAL as intentions)
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

  /// Get questionnaire questions
  Future<dynamic> getQuestionnaire() async {
    return await get('/api/bookings/questionnaire');
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
  Future<void> registerFCMToken(String token) async {
    try {
      final response = await post('/api/fcm/register', {'token': token});
      debugPrint('[API] FCM token registered: $response');
    } catch (e) {
      debugPrint('[API] Error registering FCM token: $e');
      rethrow;
    }
  }

  /// Unregister FCM token from backend
  Future<void> unregisterFCMToken(String token) async {
    try {
      final response = await post('/api/fcm/unregister', {'token': token});
      debugPrint('[API] FCM token unregistered: $response');
    } catch (e) {
      debugPrint('[API] Error unregistering FCM token: $e');
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
