import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'token_service.dart';
import 'auth_service.dart';

class ProService {
  static const String baseUrl = AuthService.baseUrl;
  static const String _userError =
      'Une erreur est survenue. Veuillez réessayer plus tard.';

  static Map<String, dynamic> _friendlyError([String? serverMessage]) {
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return {'success': false, 'message': serverMessage};
    }
    return {'success': false, 'message': _userError};
  }

  static MediaType? _mimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    return null;
  }

  // GET /pro/status
  static Future<Map<String, dynamic>> getStatus() async {
    final token = await TokenService.getToken();
    if (token == null) {
      return _friendlyError('Veuillez vous reconnecter.');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pro/status'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final invalidDocs = data['documents_invalides'];
        final docsStatus = data['documents_status'];
        return {
          ...data,
          'success': true,
          'documents_invalides': invalidDocs is List
              ? invalidDocs.map((e) => e.toString()).toList()
              : <String>[],
          'documents_status': docsStatus is Map
              ? Map<String, dynamic>.from(docsStatus)
              : <String, dynamic>{},
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      debugPrint('ProService.getStatus error: ${response.statusCode} ${response.body}');
      return _friendlyError(data['message'] as String?);
    } catch (e) {
      debugPrint('ProService.getStatus exception: $e');
      return _friendlyError();
    }
  }

  // POST /pro/upload-documents (supports partial resubmission)
  static Future<Map<String, dynamic>> uploadDocuments({
    String? qidNum,
    String? qidRectoPath,
    String? qidVersoPath,
    String? attestationPath,
  }) async {
    final token = await TokenService.getToken();
    if (token == null) {
      return _friendlyError('Veuillez vous reconnecter.');
    }

    try {
      final uri = Uri.parse('$baseUrl/pro/upload-documents');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      if (qidNum != null && qidNum.isNotEmpty) {
        request.fields['qid_num'] = qidNum;
      }

      if (qidRectoPath != null && qidRectoPath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'qid_recto',
          qidRectoPath,
          contentType: _mimeFromPath(qidRectoPath),
        ));
      }

      if (qidVersoPath != null && qidVersoPath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'qid_verso',
          qidVersoPath,
          contentType: _mimeFromPath(qidVersoPath),
        ));
      }

      if (attestationPath != null && attestationPath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'attestation',
          attestationPath,
          contentType: _mimeFromPath(attestationPath),
        ));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }

      debugPrint('ProService.uploadDocuments error: ${response.statusCode} ${response.body}');
      return _friendlyError(data['message'] as String?);
    } catch (e) {
      debugPrint('ProService.uploadDocuments exception: $e');
      return _friendlyError();
    }
  }

  // POST /pro/verify
  static Future<Map<String, dynamic>> verify() async {
    final token = await TokenService.getToken();
    if (token == null) {
      return _friendlyError('Veuillez vous reconnecter.');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pro/verify'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {
          'success': true,
          'verificationUrl': data['verificationUrl'],
          'sessionId': data['sessionId'],
          'status': data['status'],
          'message': data['message'],
          'skipVeriff': data['skipVeriff'] == true,
          'useNativeVerification': data['useNativeVerification'] == true,
        };
      }

      debugPrint('ProService.verify error: ${response.statusCode} ${response.body}');
      return {
        'success': false,
        'message': data['message'] as String? ?? _userError,
        'status': data['status'],
        'documents_invalides': data['documents_invalides'],
        'skipVeriff': data['skipVeriff'] == true,
      };
    } catch (e) {
      debugPrint('ProService.verify exception: $e');
      return _friendlyError();
    }
  }

  // POST /pro/complete-native-veriff
  static Future<Map<String, dynamic>> completeNativeVeriff({
    required String sessionId,
    String status = 'approved',
  }) async {
    final token = await TokenService.getToken();
    if (token == null) {
      return _friendlyError('Veuillez vous reconnecter.');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/pro/complete-native-veriff'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'sessionId': sessionId, 'status': status}),
      ).timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {'success': true, ...data};
      }

      debugPrint('ProService.completeNativeVeriff error: ${response.statusCode} ${response.body}');
      return _friendlyError(data['message'] as String?);
    } catch (e) {
      debugPrint('ProService.completeNativeVeriff exception: $e');
      return _friendlyError();
    }
  }
}
