import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String? _cachedBaseUrl;

  static String get defaultBaseUrl {
    if (kIsWeb) return '';
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2'; // Standard loopback for android emulator
      }
    } catch (_) {}
    return 'http://localhost';
  }

  static Future<String> getBaseUrl() async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    final prefs = await SharedPreferences.getInstance();
    _cachedBaseUrl = prefs.getString('api_base_url') ?? defaultBaseUrl;
    return _cachedBaseUrl!;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedBaseUrl = url;
    await prefs.setString('api_base_url', url);
  }

  static Map<String, String> _headers(String? token) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static dynamic _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.statusCode == 204 || res.statusCode == 202 || res.body.isEmpty) return null;
      return json.decode(res.body);
    }

    String errorMsg = 'HTTP Error ${res.statusCode}';
    try {
      final payload = json.decode(res.body);
      errorMsg = payload['errors']?.toString() ??
                 payload['message']?.toString() ??
                 payload['title']?.toString() ??
                 errorMsg;
    } catch (_) {
      if (res.body.isNotEmpty) {
        errorMsg = res.body;
      }
    }
    throw Exception(errorMsg);
  }

  // --- API Methods ---

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final base = await getBaseUrl();
    final res = await http.post(
      Uri.parse('$base/api/login'),
      headers: _headers(null),
      body: json.encode({'email': email, 'password': password}),
    );
    return _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final base = await getBaseUrl();
    final res = await http.post(
      Uri.parse('$base/api/users'),
      headers: _headers(null),
      body: json.encode({'username': username, 'email': email, 'password': password}),
    );
    return _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getUsers(String token) async {
    final base = await getBaseUrl();
    final res = await http.get(
      Uri.parse('$base/api/users'),
      headers: _headers(token),
    );
    return _handleResponse(res) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> data, String token) async {
    final base = await getBaseUrl();
    final res = await http.put(
      Uri.parse('$base/api/users/$id'),
      headers: _headers(token),
      body: json.encode(data),
    );
    return _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<void> deleteUser(String id, String token) async {
    final base = await getBaseUrl();
    final res = await http.delete(
      Uri.parse('$base/api/users/$id'),
      headers: _headers(token),
    );
    _handleResponse(res);
  }

  static Future<List<dynamic>> getReviewsByShelter(String shelterId) async {
    final base = await getBaseUrl();
    final res = await http.get(
      Uri.parse('$base/api/reviews/shelter/$shelterId'),
      headers: _headers(null),
    );
    return _handleResponse(res) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getShelterSummary(String shelterId) async {
    final base = await getBaseUrl();
    final res = await http.get(
      Uri.parse('$base/api/reviews/shelter/$shelterId/summary'),
      headers: _headers(null),
    );
    return _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createReview(Map<String, dynamic> data) async {
    final base = await getBaseUrl();
    final res = await http.post(
      Uri.parse('$base/api/reviews'),
      headers: _headers(null),
      body: json.encode(data),
    );
    return _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<void> deleteReview(String id) async {
    final base = await getBaseUrl();
    final res = await http.delete(
      Uri.parse('$base/api/reviews/$id'),
      headers: _headers(null),
    );
    _handleResponse(res);
  }

  static Future<List<dynamic>> getMetrics() async {
    final base = await getBaseUrl();
    final res = await http.get(
      Uri.parse('$base/api/analytics/metrics'),
      headers: _headers(null),
    );
    return _handleResponse(res) as List<dynamic>;
  }

  static Future<List<dynamic>> getTrends(String from, String to) async {
    final base = await getBaseUrl();
    final res = await http.get(
      Uri.parse('$base/api/analytics/trends?from=$from&to=$to'),
      headers: _headers(null),
    );
    return _handleResponse(res) as List<dynamic>;
  }

  static Future<void> trackEvent(Map<String, dynamic> event) async {
    final base = await getBaseUrl();
    final res = await http.post(
      Uri.parse('$base/api/analytics/events'),
      headers: _headers(null),
      body: json.encode(event),
    );
    _handleResponse(res);
  }

  static Future<Map<String, dynamic>> validateApplication(Map<String, dynamic> data, String token) async {
    final base = await getBaseUrl();
    final res = await http.post(
      Uri.parse('$base/api/adoptions/validate'),
      headers: _headers(token),
      body: json.encode(data),
    );
    return _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> submitApplication(Map<String, dynamic> data, String token) async {
    final base = await getBaseUrl();
    final res = await http.post(
      Uri.parse('$base/api/adoptions'),
      headers: _headers(token),
      body: json.encode(data),
    );
    return _handleResponse(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> scanDocuments({
    required List<int> idBytes,
    required String idFileName,
    required List<int> bankBytes,
    required String bankFileName,
    required String expectedFullName,
    String? token,
  }) async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base/api/adoptions/scan-documents');
    final request = http.MultipartRequest('POST', uri);

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['expectedFullName'] = expectedFullName;

    request.files.add(http.MultipartFile.fromBytes(
      'idDocument',
      idBytes,
      filename: idFileName,
    ));

    request.files.add(http.MultipartFile.fromBytes(
      'bankStatementDocument',
      bankBytes,
      filename: bankFileName,
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    return _handleResponse(response) as Map<String, dynamic>;
  }
}
