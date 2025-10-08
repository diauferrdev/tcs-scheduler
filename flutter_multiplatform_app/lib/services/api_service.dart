import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _sessionCookie;

  void setSessionCookie(String? cookie) {
    _sessionCookie = cookie;
  }

  String? getSessionCookie() => _sessionCookie;

  Future<Map<String, dynamic>> get(String endpoint) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
      debugPrint('[API] GET $endpoint with cookie: $_sessionCookie');
    } else {
      debugPrint('[API] GET $endpoint without cookie');
    }

    final response = await http
        .get(url, headers: headers)
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await http
        .post(url, headers: headers, body: jsonEncode(data))
        .timeout(ApiConfig.timeout);

    // Extract ALL session cookies from response
    final setCookieHeader = response.headers['set-cookie'];
    debugPrint('[API] Set-Cookie header: $setCookieHeader');
    if (setCookieHeader != null) {
      // Extract cookie name=value pairs, preserving all cookies
      final cookiePairs = <String>[];
      // Split by comma only if followed by a space and cookie name pattern
      final cookiesList = setCookieHeader.split(RegExp(r',(?=\s*\w+=)'));
      for (var cookie in cookiesList) {
        final cookieValue = cookie.split(';')[0].trim();
        if (cookieValue.isNotEmpty) {
          cookiePairs.add(cookieValue);
        }
      }
      if (cookiePairs.isNotEmpty) {
        _sessionCookie = cookiePairs.join('; ');
        debugPrint('[API] Session cookie set: $_sessionCookie');
      }
    }

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await http
        .put(url, headers: headers, body: jsonEncode(data))
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final headers = {...ApiConfig.defaultHeaders};

    if (_sessionCookie != null) {
      headers['Cookie'] = _sessionCookie!;
    }

    final response = await http
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
      throw ApiException(
        error['error'] as String? ?? 'Unknown error',
        response.statusCode,
      );
    }
  }

  // Analytics Methods
  Future<Map<String, dynamic>> getDashboardStats() async {
    return await get('/api/analytics/dashboard');
  }

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
    return await http
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

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) async {
    return await post('/api/bookings', data);
  }

  Future<Map<String, dynamic>> updateBooking(String id, Map<String, dynamic> data) async {
    return await http
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

  Future<Map<String, dynamic>> checkAvailability(String date) async {
    return await get('/api/bookings/availability/$date');
  }

  Future<Map<String, dynamic>> getAttendeeById(String attendeeId) async {
    return await get('/api/bookings/attendee/$attendeeId');
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
