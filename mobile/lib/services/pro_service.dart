import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_service.dart';
import 'auth_service.dart';

class ProService {
  static const String baseUrl = AuthService.baseUrl;

  // GET /pro/status
  static Future<Map<String, dynamic>> getStatus() async {
    final token = await TokenService.getToken();
    if (token == null) return {'success': false, 'message': 'Non authentifié'};

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/pro/status'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Erreur lors de la récupération du statut'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion'};
    }
  }

  // POST /pro/upload-documents
  static Future<Map<String, dynamic>> uploadDocuments({
    required String qidNum,
    required String qidRectoPath,
    required String qidVersoPath,
    required String attestationPath,
    String? licencePath,
  }) async {
    final token = await TokenService.getToken();
    if (token == null) return {'success': false, 'message': 'Non authentifié'};

    try {
      final uri = Uri.parse('$baseUrl/pro/upload-documents');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

request.fields['qid_number'] = qidNum;
      // Attach QID Recto
      request.files.add(await http.MultipartFile.fromPath(
        'qid_recto',
        qidRectoPath,
      ));

      // Attach QID Verso
      request.files.add(await http.MultipartFile.fromPath(
        'qid_verso',
        qidVersoPath,
      ));

      // Attach Attestation
      request.files.add(await http.MultipartFile.fromPath(
        'attestation',
        attestationPath,
      ));

      // Attach Licence (optional)
      if (licencePath != null && licencePath.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'licence',
          licencePath,
        ));
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['message'] ?? 'Erreur de téléchargement des documents'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur réseau lors de la soumission : ${e.toString()}'};
    }
  }

  // POST /pro/verify
  static Future<Map<String, dynamic>> verify() async {
    final token = await TokenService.getToken();
    if (token == null) return {'success': false, 'message': 'Non authentifié'};

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
          'sessionId': data['sessionId']
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Erreur d\'initialisation de la vérification'};
    } catch (e) {
      return {'success': false, 'message': 'Erreur de connexion'};
    }
  }
}
