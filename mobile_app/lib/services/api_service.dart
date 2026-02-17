import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import '../models/intervention.dart';
import '../models/absence.dart';
import '../models/attendance.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  String? _token;
  User? _currentUser;

  // ============================================
  // Token Management
  // ============================================

  Future<String?> getToken() async {
    _token ??= await _storage.read(key: _tokenKey);
    return _token;
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<User?> getStoredUser() async {
    if (_currentUser != null) return _currentUser;
    final userJson = await _storage.read(key: _userKey);
    if (userJson != null) {
      _currentUser = User.fromJson(jsonDecode(userJson));
    }
    return _currentUser;
  }

  Future<void> setStoredUser(User user) async {
    _currentUser = user;
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  Future<void> clearAuth() async {
    _token = null;
    _currentUser = null;
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }

  // ============================================
  // HTTP Helpers
  // ============================================

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> _get(String endpoint) async {
    final headers = await _getHeaders();
    final response = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: headers,
        )
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  Future<dynamic> _post(String endpoint, [Map<String, dynamic>? body]) async {
    final headers = await _getHeaders();
    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  Future<dynamic> _patch(String endpoint, Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final response = await http
        .patch(
          Uri.parse('${ApiConfig.baseUrl}$endpoint'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(ApiConfig.timeout);

    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      final error = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : {'message': 'Erreur inconnue'};
      throw ApiException(
        response.statusCode,
        error['message'] ?? 'Erreur serveur',
      );
    }
  }

  // ============================================
  // Auth API
  // ============================================

  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _post('/auth/login', {
      'email': email,
      'password': password,
    });

    final user = User.fromJson(data['user']);
    final token = data['accessToken'] as String;

    await setToken(token);
    await setStoredUser(user);

    return {'user': user, 'token': token};
  }

  Future<User> getMe() async {
    final data = await _get('/auth/me');
    final user = User.fromJson(data);
    await setStoredUser(user);
    return user;
  }

  Future<void> forgotPassword(String email) async {
    await _post('/auth/forgot-password', {'email': email});
  }

  // ============================================
  // Interventions API
  // ============================================

  Future<List<Intervention>> getMyMissions({
    String? agentId,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? sortBy,
    String? sortOrder,
  }) async {
    final params = <String, String>{};
    if (agentId != null) params['agentId'] = agentId;
    if (status != null) params['status'] = status;
    if (dateFrom != null) params['dateFrom'] = dateFrom;
    if (dateTo != null) params['dateTo'] = dateTo;
    if (sortBy != null) params['sortBy'] = sortBy;
    if (sortOrder != null) params['sortOrder'] = sortOrder;

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final data = await _get('/interventions${queryString.isNotEmpty ? '?$queryString' : ''}');

    if (data is Map && data.containsKey('data')) {
      return (data['data'] as List).map((e) => Intervention.fromJson(e)).toList();
    }
    if (data is List) {
      return data.map((e) => Intervention.fromJson(e)).toList();
    }
    return [];
  }

  Future<Intervention> getMissionById(String id) async {
    final data = await _get('/interventions/$id');
    return Intervention.fromJson(data);
  }

  Future<Intervention> startMission(String id) async {
    final data = await _post('/interventions/$id/start');
    return Intervention.fromJson(data);
  }

  Future<Intervention> completeMission(String id) async {
    final data = await _post('/interventions/$id/complete');
    return Intervention.fromJson(data);
  }

  Future<Intervention> checkIn(String id, double lat, double lng, {double? accuracy}) async {
    final body = <String, dynamic>{
      'latitude': lat,
      'longitude': lng,
    };
    if (accuracy != null) body['accuracy'] = accuracy;
    final data = await _post('/interventions/$id/checkin', body);
    return Intervention.fromJson(data);
  }

  Future<Intervention> checkOut(String id, double lat, double lng, {double? accuracy}) async {
    final body = <String, dynamic>{
      'latitude': lat,
      'longitude': lng,
    };
    if (accuracy != null) body['accuracy'] = accuracy;
    final data = await _post('/interventions/$id/checkout', body);
    return Intervention.fromJson(data);
  }

  Future<Intervention> addPhoto(String id, String photoUrl) async {
    final data = await _post('/interventions/$id/photos', {'photoUrl': photoUrl});
    return Intervention.fromJson(data);
  }

  // ============================================
  // Attendance API
  // ============================================

  Future<ShiftStatus> getShiftStatus() async {
    final data = await _get('/attendance/status');
    return ShiftStatus.fromJson(data);
  }

  Future<Attendance> clockIn({String? notes, double? lat, double? lng}) async {
    final body = <String, dynamic>{};
    if (notes != null) body['notes'] = notes;
    if (lat != null) body['latitude'] = lat;
    if (lng != null) body['longitude'] = lng;
    final data = await _post('/attendance/clock-in', body);
    return Attendance.fromJson(data);
  }

  Future<Attendance> clockOut({String? notes, double? lat, double? lng}) async {
    final body = <String, dynamic>{};
    if (notes != null) body['notes'] = notes;
    if (lat != null) body['latitude'] = lat;
    if (lng != null) body['longitude'] = lng;
    final data = await _post('/attendance/clock-out', body);
    return Attendance.fromJson(data);
  }

  Future<Attendance> pauseShift({String? reason, String? notes}) async {
    final body = <String, dynamic>{};
    if (reason != null) body['reason'] = reason;
    if (notes != null) body['notes'] = notes;
    final data = await _post('/attendance/pause', body);
    return Attendance.fromJson(data);
  }

  Future<Attendance> resumeShift({String? notes}) async {
    final body = <String, dynamic>{};
    if (notes != null) body['notes'] = notes;
    final data = await _post('/attendance/resume', body);
    return Attendance.fromJson(data);
  }

  Future<DailySummary> getDailySummary({String? date}) async {
    final query = date != null ? '?date=$date' : '';
    final data = await _get('/attendance/daily-summary$query');
    return DailySummary.fromJson(data);
  }

  Future<List<Attendance>> getAttendanceHistory({String? startDate, String? endDate}) async {
    final params = <String, String>{};
    if (startDate != null) params['startDate'] = startDate;
    if (endDate != null) params['endDate'] = endDate;
    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final data = await _get('/attendance/history${queryString.isNotEmpty ? '?$queryString' : ''}');
    if (data is List) {
      return data.map((e) => Attendance.fromJson(e)).toList();
    }
    return [];
  }

  // ============================================
  // Absences API
  // ============================================

  Future<List<Absence>> getMyAbsences({String? agentId, String? status}) async {
    final params = <String, String>{};
    if (agentId != null) params['agentId'] = agentId;
    if (status != null) params['status'] = status;
    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final data = await _get('/absences${queryString.isNotEmpty ? '?$queryString' : ''}');
    if (data is List) {
      return data.map((e) => Absence.fromJson(e)).toList();
    }
    return [];
  }

  Future<AbsenceBalance> getAbsenceBalance(String agentId, {int? year}) async {
    final query = year != null ? '?year=$year' : '';
    final data = await _get('/absences/balance/$agentId$query');
    return AbsenceBalance.fromJson(data);
  }

  Future<Absence> createAbsence({
    required String agentId,
    required String absenceType,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    final data = await _post('/absences', {
      'agentId': agentId,
      'absenceType': absenceType,
      'startDate': startDate,
      'endDate': endDate,
      if (reason != null) 'reason': reason,
    });
    return Absence.fromJson(data);
  }

  Future<Absence> cancelAbsence(String id) async {
    final data = await _post('/absences/$id/cancel');
    return Absence.fromJson(data);
  }

  // ============================================
  // Profile API
  // ============================================

  Future<Map<String, dynamic>> getProfile() async {
    return await _get('/profile');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return await _patch('/profile', data);
  }

  // ============================================
  // Notifications API
  // ============================================

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final data = await _get('/notifications/recent?limit=20');
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>> getUnreadCount() async {
    return await _get('/notifications/unread-count');
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
