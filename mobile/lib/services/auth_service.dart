import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'token_service.dart';

class AuthResult {
  final bool success;
  final String? message;
  final Map<String, dynamic>? data;
  final bool tokenExpired;

  AuthResult({
    required this.success,
    this.message,
    this.data,
    this.tokenExpired = false,
  });
}

class AuthService {
  // Utilisez 10.0.2.2 pour l'émulateur Android. (Utilisez l'IP locale ex: 192.168.1.X pour un vrai téléphone)
static const String baseUrl = 'http://192.168.1.16:3000';
  static const Duration _timeout = Duration(seconds: 15);

  static Map<String, String> get _headers => {'Content-Type': 'application/json'};

  static Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // POST /auth/login
  static Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: _headers,
            body: jsonEncode({'email': identifier, 'mot_de_passe': password}),
          )
          .timeout(_timeout);

      if (response.statusCode == 401 || response.statusCode == 404) {
        return AuthResult(success: false, message: 'Email ou mot de passe incorrect');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return AuthResult(success: false, message: 'Service temporairement indisponible.');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final token = data['token'] ?? data['access_token'];
        final rToken = data['refreshToken'] ?? data['refresh_token'];
        if (token != null) await TokenService.saveToken(token.toString());
        if (rToken != null) await TokenService.saveRefreshToken(rToken.toString());
        return AuthResult(success: true, data: data);
      }
      return AuthResult(
          success: false,
          message: data['message'] ?? 'Email ou mot de passe incorrect');
    } on TimeoutException {
      return AuthResult(
          success: false,
          message: 'Délai dépassé. Vérifiez votre connexion.');
    } catch (e) {
      return AuthResult(
          success: false, message: 'Impossible de contacter le serveur. (Erreur réseau)');
    }
  }

  // POST /auth/register
  static Future<AuthResult> register(Map<String, dynamic> userData) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: _headers,
            body: jsonEncode(userData),
          )
          .timeout(_timeout);

      if (response.statusCode == 409) {
        return AuthResult(success: false, message: 'Cet email est déjà utilisé');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return AuthResult(success: false, message: 'Service temporairement indisponible.');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final token = data['token'] ?? data['access_token'];
        final rToken = data['refreshToken'] ?? data['refresh_token'];
        if (token != null) await TokenService.saveToken(token.toString());
        if (rToken != null) await TokenService.saveRefreshToken(rToken.toString());
        return AuthResult(success: true, data: data);
      }
      // Traduction des messages d'erreur backend en messages lisibles
      final backendMsg = data['message'] as String? ?? '';
      String friendlyMsg;
      if (backendMsg.toLowerCase().contains('email') && (backendMsg.toLowerCase().contains('utilisé') || backendMsg.toLowerCase().contains('existe'))) {
        friendlyMsg = 'Cet email est déjà utilisé.';
      } else if (backendMsg.toLowerCase().contains('téléphone') && backendMsg.toLowerCase().contains('utilisé')) {
        friendlyMsg = 'Ce numéro de téléphone est déjà utilisé.';
      } else if (backendMsg.toLowerCase().contains('obligatoire')) {
        friendlyMsg = 'Veuillez remplir tous les champs obligatoires.';
      } else if (backendMsg.toLowerCase().contains('mot de passe')) {
        friendlyMsg = 'Le mot de passe doit contenir au moins 8 caractères.';
      } else {
        friendlyMsg = backendMsg.isNotEmpty ? backendMsg : "Erreur lors de l'inscription";
      }
      return AuthResult(success: false, message: friendlyMsg);
    } on TimeoutException {
      return AuthResult(success: false, message: 'Délai dépassé.');
    } catch (e) {
      return AuthResult(success: false, message: 'Impossible de contacter le serveur. (Erreur réseau)');
    }
  }

  // POST /auth/logout
  static Future<void> logout() async {
    final token = await TokenService.getToken();
    if (token != null) {
      try {
        await http
            .post(Uri.parse('$baseUrl/auth/logout'),
                headers: _authHeaders(token))
            .timeout(_timeout);
      } catch (_) {}
    }
    await TokenService.clearAll();
  }

  // POST /auth/refresh
  static Future<String?> refreshAccessToken() async {
    final refreshToken = await TokenService.getRefreshToken();
    if (refreshToken == null) return null;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: _headers,
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final newToken = data['token'];
        if (newToken != null) {
          await TokenService.saveToken(newToken.toString());
          return newToken.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  // GET /auth/profile
  static Future<AuthResult> getProfile() async {
    final token = await TokenService.getToken();
    if (token == null) {
      return AuthResult(
          success: false, message: 'Non authentifié', tokenExpired: true);
    }
    try {
      var response = await http
          .get(Uri.parse('$baseUrl/auth/profile'), headers: _authHeaders(token))
          .timeout(_timeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        final newToken = await refreshAccessToken();
        if (newToken != null) {
          response = await http
              .get(Uri.parse('$baseUrl/auth/profile'), headers: _authHeaders(newToken))
              .timeout(_timeout);
        } else {
          await TokenService.clearAll();
          return AuthResult(
              success: false, message: 'Session expirée', tokenExpired: true);
        }
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) return AuthResult(success: true, data: data);
      return AuthResult(success: false, message: data['message'] ?? 'Erreur');
    } catch (e) {
      return AuthResult(success: false, message: 'Erreur réseau');
    }
  }

  // GET /auth/profile/avis
  static Future<AuthResult> getMyAvisStats() async {
    final token = await TokenService.getToken();
    if (token == null) {
      return AuthResult(
          success: false, message: 'Non authentifié', tokenExpired: true);
    }
    try {
      var response = await http
          .get(Uri.parse('$baseUrl/auth/profile/avis'), headers: _authHeaders(token))
          .timeout(_timeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        final newToken = await refreshAccessToken();
        if (newToken != null) {
          response = await http
              .get(Uri.parse('$baseUrl/auth/profile/avis'), headers: _authHeaders(newToken))
              .timeout(_timeout);
        } else {
          await TokenService.clearAll();
          return AuthResult(
              success: false, message: 'Session expirée', tokenExpired: true);
        }
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) return AuthResult(success: true, data: data);
      return AuthResult(success: false, message: data['message'] ?? 'Erreur');
    } catch (e) {
      return AuthResult(success: false, message: 'Erreur réseau');
    }
  }

  // PUT /auth/profile/update
  static Future<AuthResult> updateProfile(Map<String, dynamic> profileData) async {
    final token = await TokenService.getToken();
    if (token == null) {
      return AuthResult(
          success: false, message: 'Non authentifié', tokenExpired: true);
    }
    try {
      var response = await http
          .put(
            Uri.parse('$baseUrl/auth/profile/update'),
            headers: _authHeaders(token),
            body: jsonEncode(profileData),
          )
          .timeout(_timeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        final newToken = await refreshAccessToken();
        if (newToken != null) {
          response = await http
              .put(
                Uri.parse('$baseUrl/auth/profile/update'),
                headers: _authHeaders(newToken),
                body: jsonEncode(profileData),
              )
              .timeout(_timeout);
        } else {
          await TokenService.clearAll();
          return AuthResult(
              success: false, message: 'Session expirée', tokenExpired: true);
        }
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) return AuthResult(success: true, data: data);
      return AuthResult(
          success: false,
          message: data['message'] ?? 'Erreur de mise à jour');
    } catch (e) {
      return AuthResult(success: false, message: 'Erreur réseau');
    }
  }

  // POST /auth/profile/photo
  static Future<AuthResult> uploadProfilePhoto(File imageFile) async {
    final token = await TokenService.getToken();
    if (token == null) {
      return AuthResult(success: false, message: 'Non authentifié', tokenExpired: true);
    }
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/auth/profile/photo'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('photo', imageFile.path));

      var streamedResponse = await request.send().timeout(_timeout);
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401 || response.statusCode == 403) {
        final newToken = await refreshAccessToken();
        if (newToken != null) {
          request = http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/auth/profile/photo'),
          );
          request.headers['Authorization'] = 'Bearer $newToken';
          request.files.add(await http.MultipartFile.fromPath('photo', imageFile.path));
          streamedResponse = await request.send().timeout(_timeout);
          response = await http.Response.fromStream(streamedResponse);
        } else {
          await TokenService.clearAll();
          return AuthResult(
              success: false, message: 'Session expirée', tokenExpired: true);
        }
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return AuthResult(success: true, data: data);
      }
      return AuthResult(success: false, message: data['message'] ?? 'Erreur upload photo');
    } on TimeoutException {
      return AuthResult(success: false, message: 'Délai dépassé lors de l\'upload.');
    } catch (e) {
      return AuthResult(success: false, message: 'Erreur lors de l\'upload.');
    }
  }

  // POST /auth/verify-email
  static Future<AuthResult> verifyEmailBackend() async {
    final token = await TokenService.getToken();
    if (token == null) {
      return AuthResult(
          success: false, message: 'Non authentifié', tokenExpired: true);
    }
    try {
      var response = await http
          .post(
            Uri.parse('$baseUrl/auth/verify-email'),
            headers: _authHeaders(token),
          )
          .timeout(_timeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        final newToken = await refreshAccessToken();
        if (newToken != null) {
          response = await http
              .post(
                Uri.parse('$baseUrl/auth/verify-email'),
                headers: _authHeaders(newToken),
              )
              .timeout(_timeout);
        } else {
          await TokenService.clearAll();
          return AuthResult(
              success: false, message: 'Session expirée', tokenExpired: true);
        }
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) return AuthResult(success: true, data: data);
      return AuthResult(success: false, message: data['message'] ?? 'Erreur');
    } catch (e) {
      return AuthResult(success: false, message: 'Erreur réseau');
    }
  }

  // POST /auth/social-login (Google / Apple)
  static Future<AuthResult> socialLogin({
    required String email,
    required String? prenom,
    required String? nom,
    required String? photo,
    required String? uid,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/social-login'),
            headers: _headers,
            body: jsonEncode({
              'email': email,
              'prenom': prenom ?? '',
              'nom': nom ?? '',
              'photo': photo ?? '',
              'uid': uid ?? '',
            }),
          )
          .timeout(_timeout);

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return AuthResult(success: false, message: 'Erreur du serveur');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final token = data['token'] ?? data['access_token'];
        final rToken = data['refreshToken'] ?? data['refresh_token'];
        if (token != null) await TokenService.saveToken(token.toString());
        if (rToken != null) await TokenService.saveRefreshToken(rToken.toString());
        return AuthResult(success: true, data: data);
      }
      return AuthResult(success: false, message: data['message'] ?? 'Connexion sociale échouée');
    } on TimeoutException {
      return AuthResult(success: false, message: 'Délai dépassé. Vérifiez votre connexion.');
    } catch (e) {
      return AuthResult(success: false, message: 'Impossible de contacter le serveur.');
    }
  }

  // POST /auth/sync-password (Sync Firebase password to MySQL)
  static Future<AuthResult> syncPassword({
    required String email,
    required String password,
    required String idToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/sync-password'),
            headers: _headers,
            body: jsonEncode({
              'email': email,
              'password': password,
              'idToken': idToken,
            }),
          )
          .timeout(_timeout);

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return AuthResult(success: false, message: 'Erreur du serveur');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AuthResult(success: true, data: data);
      }
      return AuthResult(success: false, message: data['message'] ?? 'Échec de la synchronisation');
    } on TimeoutException {
      return AuthResult(success: false, message: 'Délai dépassé.');
    } catch (e) {
      return AuthResult(success: false, message: 'Erreur réseau.');
    }
  }

  // POST /auth/check-phone
  static Future<AuthResult> checkPhone(String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/check-phone'),
            headers: _headers,
            body: jsonEncode({'telephone': phone}),
          )
          .timeout(_timeout);

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return AuthResult(success: false, message: 'Erreur du serveur');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AuthResult(success: true, data: data);
      }
      return AuthResult(
        success: false,
        message: data['message'] ?? 'Numéro non reconnu',
      );
    } on TimeoutException {
      return AuthResult(success: false, message: 'Délai dépassé.');
    } catch (e) {
      return AuthResult(success: false, message: 'Erreur réseau.');
    }
  }

  // POST /auth/login-phone
  static Future<AuthResult> loginPhone(String phone) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login-phone'),
            headers: _headers,
            body: jsonEncode({'telephone': phone}),
          )
          .timeout(_timeout);

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return AuthResult(success: false, message: 'Erreur du serveur');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final token = data['token'] ?? data['access_token'];
        final rToken = data['refreshToken'] ?? data['refresh_token'];
        if (token != null) await TokenService.saveToken(token.toString());
        if (rToken != null) await TokenService.saveRefreshToken(rToken.toString());
        return AuthResult(success: true, data: data);
      }
      return AuthResult(
        success: false,
        message: data['message'] ?? 'Erreur d\'authentification',
      );
    } on TimeoutException {
      return AuthResult(success: false, message: 'Délai dépassé.');
    } catch (e) {
      return AuthResult(success: false, message: 'Erreur réseau.');
    }
  }
}
