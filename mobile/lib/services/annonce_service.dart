import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import 'token_service.dart';

class AnnonceResult {
  final bool success;
  final String? message;
  final dynamic data;

  AnnonceResult({required this.success, this.message, this.data});
}

class AnnonceService {
  static const String baseUrl = AuthService.baseUrl;
  static const Duration _timeout = Duration(seconds: 20);

  static Map<String, String> get _headers => {'Content-Type': 'application/json'};

  static Future<Map<String, String>> _authHeaders() async {
    final token = await TokenService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // GET /api/annonces?page=1&limit=10
  static Future<AnnonceResult> getFeed({
    int page = 1,
    int limit = 10,
    String? categorie,
    String? ville,
    String? filter,
  }) async {
    try {
      final params = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (categorie != null && categorie != 'tous') 'categorie': categorie,
        if (ville != null && ville.isNotEmpty) 'ville': ville,
        if (filter != null) 'filter': filter,
      };
      final uri = Uri.parse('$baseUrl/api/annonces').replace(queryParameters: params);
      final headers = await _authHeaders();
      final response = await http.get(uri, headers: headers).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return AnnonceResult(success: true, data: data);
      }
      return AnnonceResult(success: false, message: data['message'] ?? 'Erreur lors du chargement');
    } on TimeoutException {
      return AnnonceResult(success: false, message: 'Délai dépassé. Vérifiez votre connexion.');
    } catch (e) {
      return AnnonceResult(success: false, message: 'Impossible de contacter le serveur.');
    }
  }

  // GET /api/annonces/:id
  static Future<AnnonceResult> getDetail(int id) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/api/annonces/$id'), headers: headers)
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return AnnonceResult(success: true, data: data['data']);
      return AnnonceResult(success: false, message: data['message'] ?? 'Annonce introuvable');
    } on TimeoutException {
      return AnnonceResult(success: false, message: 'Délai dépassé.');
    } catch (e) {
      return AnnonceResult(success: false, message: 'Erreur réseau.');
    }
  }

  // POST /api/annonces
  static Future<AnnonceResult> createAnnonce({
    required String titre,
    required String description,
    String? categorie,
    double? prix,
    String? ville,
    List<String>? photos,
    String? typePaiement,
    bool urgent = false,
    String? typePublication,
    double? budgetMax,
    String? disponibilite,
  }) async {
    try {
      final headers = await _authHeaders();
      final body = {
        'titre': titre,
        'description': description,
        if (categorie != null) 'categorie': categorie,
        if (prix != null) 'prix': prix,
        if (ville != null && ville.isNotEmpty) 'ville': ville,
        if (photos != null && photos.isNotEmpty) 'photos': photos,
        if (typePaiement != null) 'type_paiement': typePaiement,
        'urgent': urgent,
        if (typePublication != null) 'type_publication': typePublication,
        if (budgetMax != null) 'budget_max': budgetMax,
        if (disponibilite != null) 'disponibilite': disponibilite,
      };
      final response = await http
          .post(Uri.parse('$baseUrl/api/annonces'),
              headers: headers, body: jsonEncode(body))
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) return AnnonceResult(success: true, data: data);
      return AnnonceResult(success: false, message: data['message'] ?? 'Erreur lors de la création');
    } on TimeoutException {
      return AnnonceResult(success: false, message: 'Délai dépassé.');
    } catch (e) {
      return AnnonceResult(success: false, message: 'Erreur réseau.');
    }
  }

  // POST /api/annonces/:id/photos (upload fichier réel vers Cloudinary via backend)
  static Future<AnnonceResult> uploadPhoto(int annonceId, File imageFile) async {
    try {
      final token = await TokenService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/annonces/$annonceId/photos'),
      );
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('photo', imageFile.path));
      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return AnnonceResult(success: true, data: data['photo']);
      return AnnonceResult(success: false, message: data['message'] ?? 'Erreur upload photo');
    } on TimeoutException {
      return AnnonceResult(success: false, message: 'Délai dépassé lors de l\'upload.');
    } catch (e) {
      return AnnonceResult(success: false, message: 'Erreur lors de l\'upload.');
    }
  }

  // DELETE /api/annonces/:id/photos/:pid
  static Future<AnnonceResult> deletePhoto(int annonceId, int photoId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl/api/annonces/$annonceId/photos/$photoId'),
              headers: headers)
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return AnnonceResult(success: true);
      return AnnonceResult(success: false, message: data['message'] ?? 'Erreur suppression photo');
    } on TimeoutException {
      return AnnonceResult(success: false, message: 'Délai dépassé.');
    } catch (e) {
      return AnnonceResult(success: false, message: 'Erreur réseau.');
    }
  }

  // PUT /api/annonces/:id
  static Future<AnnonceResult> updateAnnonce(int id, Map<String, dynamic> fields) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .put(Uri.parse('$baseUrl/api/annonces/$id'),
              headers: headers, body: jsonEncode(fields))
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return AnnonceResult(success: true, data: data);
      return AnnonceResult(success: false, message: data['message'] ?? 'Erreur modification');
    } on TimeoutException {
      return AnnonceResult(success: false, message: 'Délai dépassé.');
    } catch (e) {
      return AnnonceResult(success: false, message: 'Erreur réseau.');
    }
  }

  // DELETE /api/annonces/:id
  static Future<AnnonceResult> deleteAnnonce(int id) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl/api/annonces/$id'), headers: headers)
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return AnnonceResult(success: true);
      return AnnonceResult(success: false, message: data['message'] ?? 'Erreur suppression');
    } on TimeoutException {
      return AnnonceResult(success: false, message: 'Délai dépassé.');
    } catch (e) {
      return AnnonceResult(success: false, message: 'Erreur réseau.');
    }
  }

  // POST /api/annonces/:id/like
  static Future<AnnonceResult> toggleLike(int id) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .post(Uri.parse('$baseUrl/api/annonces/$id/like'), headers: headers)
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return AnnonceResult(success: true, data: data);
      return AnnonceResult(success: false, message: data['message'] ?? 'Erreur like');
    } on TimeoutException {
      return AnnonceResult(success: false, message: 'Délai dépassé.');
    } catch (e) {
      return AnnonceResult(success: false, message: 'Erreur réseau.');
    }
  }

  // POST /api/annonces/:id/commentaires
  static Future<AnnonceResult> addCommentaire(int annonceId, String contenu, String type) async {
    try {
      final token = await TokenService.getToken();
      if (token == null || token.isEmpty) {
        return AnnonceResult(success: false, message: 'Connectez-vous pour commenter.');
      }
      final headers = await _authHeaders();
      final response = await http
          .post(Uri.parse('$baseUrl/api/annonces/$annonceId/commentaires'),
              headers: headers, body: jsonEncode({'contenu': contenu, 'type': type}))
          .timeout(_timeout);
      Map<String, dynamic> data = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}
      if (response.statusCode == 201) {
        return AnnonceResult(success: true, data: data['data'], message: data['message']?.toString());
      }
      return AnnonceResult(
        success: false,
        message: data['message']?.toString() ?? 'Erreur commentaire (${response.statusCode})',
      );
    } on TimeoutException {
      return AnnonceResult(success: false, message: 'Délai dépassé.');
    } catch (e) {
      return AnnonceResult(success: false, message: 'Erreur réseau: $e');
    }
  }

  // DELETE /api/annonces/:id/commentaires/:cid
  static Future<AnnonceResult> deleteCommentaire(int annonceId, int commentId) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .delete(Uri.parse('$baseUrl/api/annonces/$annonceId/commentaires/$commentId'),
              headers: headers)
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return AnnonceResult(success: true);
      return AnnonceResult(success: false, message: data['message'] ?? 'Erreur suppression commentaire');
    } on TimeoutException {
      return AnnonceResult(success: false, message: 'Délai dépassé.');
    } catch (e) {
      return AnnonceResult(success: false, message: 'Erreur réseau.');
    }
  }
}
