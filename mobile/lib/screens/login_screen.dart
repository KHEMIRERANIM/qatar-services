import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/token_service.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onRegister;
  final Function(String phone, dynamic confirmationResult, String? verificationId) onOtp;
  final Function(String email) onEmailVerify;

  const LoginScreen({
    super.key,
    required this.onSuccess,
    required this.onRegister,
    required this.onOtp,
    required this.onEmailVerify,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _showPwd = false;
  bool _isLoading = false;
  String? _identifierError;
  String? _passwordError;
  String? _globalError;

  static final _phoneReg = RegExp(r'^\+?[0-9]{8,15}$');
  static final _emailReg = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _isPhone(String val) => _phoneReg.hasMatch(val.replaceAll(' ', ''));

  bool _validate() {
    final id = _identifierCtrl.text.trim();
    final pwd = _passwordCtrl.text;
    setState(() {
      _identifierError = id.isEmpty
          ? 'Champ requis'
          : (!_emailReg.hasMatch(id) && !_isPhone(id))
              ? 'Email ou numéro de téléphone invalide'
              : null;
      _passwordError = pwd.isEmpty ? 'Champ requis' : null;
      _globalError = null;
    });
    return _identifierError == null && _passwordError == null;
  }

  // ─── EMAIL / PASSWORD LOGIN ───────────────────────────────────────────────
  Future<void> _loginWithPassword() async {
    if (!_validate() || _isLoading) return;
    setState(() => _isLoading = true);

    final id = _identifierCtrl.text.trim();
    final pwd = _passwordCtrl.text;

    // If phone → Firebase Phone OTP flow
    if (_isPhone(id)) {
      await _sendPhoneOtp(id);
      setState(() => _isLoading = false);
      return;
    }

    // Otherwise → backend email/password login
    final result = await AuthService.login(identifier: id, password: pwd);
    if (!mounted) return;

    if (result.success) {
      // Sign in to Firebase to check email verification status
      try {
        final fbUserCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: id,
          password: pwd,
        );
        final fbUser = fbUserCred.user;
        if (fbUser != null && !fbUser.emailVerified) {
          await fbUser.sendEmailVerification();
          setState(() => _isLoading = false);
          widget.onEmailVerify(id);
          return;
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          // If the Firebase account doesn't exist, create it silently and verify
          try {
            final createCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: id,
              password: pwd,
            );
            await createCred.user?.sendEmailVerification();
            setState(() => _isLoading = false);
            widget.onEmailVerify(id);
            return;
          } catch (_) {}
        }
      } catch (e) {
        debugPrint("Firebase email check failed: $e");
      }

      setState(() => _isLoading = false);
      _showSnack('Connexion réussie !', success: true);
      widget.onSuccess();
    } else {
      // Backend login failed. The password might have been reset in Firebase.
      // Let's try to verify with Firebase using this new password.
      try {
        final fbUserCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: id,
          password: pwd,
        );
        final fbUser = fbUserCred.user;
        if (fbUser != null) {
          final idToken = await fbUser.getIdToken();
          if (idToken != null) {
            // Firebase accepted this password! Sync it to our MySQL backend.
            final syncResult = await AuthService.syncPassword(
              email: id,
              password: pwd,
              idToken: idToken,
            );

            if (syncResult.success) {
              // Retry backend login with the synchronized password
              final retryResult = await AuthService.login(identifier: id, password: pwd);
              if (mounted) {
                if (retryResult.success) {
                  if (!fbUser.emailVerified) {
                    await fbUser.sendEmailVerification();
                    setState(() => _isLoading = false);
                    widget.onEmailVerify(id);
                    return;
                  }
                  setState(() => _isLoading = false);
                  _showSnack('Connexion réussie ! (Mot de passe mis à jour)', success: true);
                  widget.onSuccess();
                  return;
                }
              }
            }
          }
        }
      } catch (_) {
        // Firebase login also failed, meaning the password is indeed incorrect.
      }

      setState(() => _isLoading = false);
      setState(() => _globalError = result.message);
    }
  }

  // ─── PHONE OTP VIA FIREBASE ───────────────────────────────────────────────
  Future<void> _sendPhoneOtp(String phone) async {
    // Normalize: ensure +974 prefix if no country code
    final normalized = phone.startsWith('+') ? phone : '+974$phone';

    try {
      // Web: signInWithPhoneNumber returns ConfirmationResult
      final confirmationResult =
          await FirebaseAuth.instance.signInWithPhoneNumber(normalized);
      if (mounted) {
        widget.onOtp(normalized, confirmationResult, null);
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _globalError = _mapFirebaseError(e.code));
      }
    } catch (_) {
      // Fallback for non-web: verifyPhoneNumber
      FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: normalized,
        verificationCompleted: (cred) async {
          await FirebaseAuth.instance.signInWithCredential(cred);
          final token = await FirebaseAuth.instance.currentUser?.getIdToken();
          if (token != null) await TokenService.saveToken(token);
          if (mounted) widget.onSuccess();
        },
        verificationFailed: (e) {
          if (mounted) setState(() => _globalError = _mapFirebaseError(e.code));
        },
        codeSent: (verificationId, _) {
          if (mounted) widget.onOtp(normalized, null, verificationId);
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    }
  }

  // ─── GOOGLE SIGN IN (via Firebase popup — web compatible) ───────────────
  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _globalError = null; });
    try {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      final fbResult = await FirebaseAuth.instance.signInWithPopup(provider);
      final user = fbResult.user;
      if (user == null) throw Exception('Utilisateur introuvable');

      final parts = (user.displayName ?? '').split(' ');
      final prenom = parts.isNotEmpty ? parts[0] : '';
      final nom = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final backendResult = await AuthService.socialLogin(
        email: user.email ?? '',
        prenom: prenom,
        nom: nom,
        photo: user.photoURL,
        uid: user.uid,
      );

      if (!mounted) return;
      if (backendResult.success) {
        _showSnack('Connexion Google réussie !', success: true);
        widget.onSuccess();
      } else {
        setState(() => _globalError = 'Erreur serveur: ${backendResult.message}');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _globalError = _mapFirebaseError(e.code));
    } catch (e) {
      if (mounted) setState(() => _globalError = 'Connexion Google annulée ou échouée.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── APPLE SIGN IN ───────────────────────────────────────────────────────
  Future<void> _signInWithApple() async {
    setState(() { _isLoading = true; _globalError = null; });
    try {
      final provider = OAuthProvider('apple.com')
        ..addScope('email')
        ..addScope('name');
      final fbResult = await FirebaseAuth.instance.signInWithPopup(provider);
      final user = fbResult.user;
      if (user == null) throw Exception('Utilisateur introuvable');

      final parts = (user.displayName ?? '').split(' ');
      final prenom = parts.isNotEmpty ? parts[0] : '';
      final nom = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      final backendResult = await AuthService.socialLogin(
        email: user.email ?? '',
        prenom: prenom,
        nom: nom,
        photo: user.photoURL,
        uid: user.uid,
      );

      if (!mounted) return;
      if (backendResult.success) {
        _showSnack('Connexion Apple réussie !', success: true);
        widget.onSuccess();
      } else {
        setState(() => _globalError = 'Erreur serveur: ${backendResult.message}');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _globalError = _mapFirebaseError(e.code));
    } catch (e) {
      if (mounted) setState(() => _globalError = 'Connexion Apple annulée ou échouée.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found': return 'Aucun compte trouvé avec cet email.';
      case 'wrong-password': return 'Mot de passe incorrect.';
      case 'invalid-email': return 'Adresse email invalide.';
      case 'user-disabled': return 'Ce compte a été désactivé.';
      case 'too-many-requests': return 'Trop de tentatives. Réessayez plus tard.';
      case 'invalid-phone-number': return 'Numéro de téléphone invalide.';
      case 'quota-exceeded': return 'Quota SMS dépassé. Réessayez plus tard.';
      default: return 'Erreur d\'authentification ($code)';
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF2D9B6F) : const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          bool sending = false;
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Mot de passe oublié ?',
                style: TextStyle(color: Color(0xFF0D1F3C), fontWeight: FontWeight.bold)),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Entrez votre email pour recevoir un lien de réinitialisation.',
                  style: TextStyle(color: Color(0xFF6B7A99), fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.08)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
                  decoration: const InputDecoration(
                    hintText: 'email@exemple.com',
                    hintStyle: TextStyle(color: Color(0xFFA0ABBE)),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7A99))),
              ),
              ElevatedButton(
                onPressed: sending
                    ? null
                    : () async {
                        if (!emailCtrl.text.contains('@')) return;
                        setD(() => sending = true);
                        try {
                          await FirebaseAuth.instance
                              .sendPasswordResetEmail(email: emailCtrl.text.trim());
                        } catch (e) {
                          debugPrint('Erreur envoi email: $e');
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _showSnack('Erreur: $e', success: false);
                          }
                          return;
                        }
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          _showSnack('Lien envoyé par email !', success: true);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1F3C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: sending
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Envoyer', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Stack(children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(top: 64, bottom: 32, left: 24, right: 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1F3C), Color(0xFF1A3560)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(children: [
                    Container(
                      width: 64, height: 64,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC9A84C),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      alignment: Alignment.center,
                      child: const Text('QS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)),
                    ),
                    const Text('Qatar Services',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Connectez-vous à votre compte',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13)),
                  ]),
                ),
                Positioned(right: -56, top: -56, child: _circle(192, Colors.white.withOpacity(0.04))),
                Positioned(left: -32, bottom: 0, child: _circle(128, const Color(0xFFC9A84C).withOpacity(0.06))),
              ]),

              // ── Form ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Social buttons
                  Row(children: [
                    Expanded(child: _socialBtn(icon: Icons.g_mobiledata_rounded, label: 'Google', onTap: _signInWithGoogle)),
                    const SizedBox(width: 12),
                    Expanded(child: _socialBtn(icon: Icons.apple, label: 'Apple', onTap: _signInWithApple)),
                  ]),
                  const SizedBox(height: 20),

                  // Divider
                  Row(children: [
                    Expanded(child: Container(height: 1, color: const Color(0xFFE8EDF5))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('ou', style: TextStyle(fontSize: 12, color: Color(0xFFA0ABBE))),
                    ),
                    Expanded(child: Container(height: 1, color: const Color(0xFFE8EDF5))),
                  ]),
                  const SizedBox(height: 20),

                  // Global error
                  if (_globalError != null) ...[
                    _errorBanner(_globalError!),
                    const SizedBox(height: 16),
                  ],

                  // Identifier
                  _label('Email ou téléphone'),
                  _inputBox(
                    controller: _identifierCtrl,
                    icon: Icons.mail_outline,
                    hint: '+974 5XXX XXXX ou email',
                    error: _identifierError,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  if (_identifierError != null) _errText(_identifierError!),
                  const SizedBox(height: 14),

                  // Password
                  _label('Mot de passe'),
                  _passwordBox(),
                  if (_passwordError != null) _errText(_passwordError!),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Mot de passe oublié ?',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFC9A84C))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Submit
                  _submitButton(),
                  const SizedBox(height: 24),

                  // Sign up
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text("Pas de compte ? ",
                        style: TextStyle(fontSize: 14, color: Color(0xFF6B7A99))),
                    GestureDetector(
                      onTap: widget.onRegister,
                      child: const Text("S'inscrire",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFC9A84C))),
                    ),
                  ]),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared Widgets ─────────────────────────────────────────────────────

  Widget _circle(double size, Color color) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D1F3C))),
      );

  Widget _errText(String msg) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(msg, style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
      );

  Widget _errorBanner(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))),
        ]),
      );

  Widget _inputBox({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    String? error,
    TextInputType? keyboardType,
  }) =>
      Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: error != null ? const Color(0xFFEF4444) : const Color(0xFF0D1F3C).withOpacity(0.12),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF6B7A99), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(fontSize: 15, color: Color(0xFF0D1F3C)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFFA0ABBE)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ]),
      );

  Widget _passwordBox() => Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _passwordError != null ? const Color(0xFFEF4444) : const Color(0xFF0D1F3C).withOpacity(0.12),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          const Icon(Icons.lock_outline, color: Color(0xFF6B7A99), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _passwordCtrl,
              obscureText: !_showPwd,
              style: const TextStyle(fontSize: 15, color: Color(0xFF0D1F3C)),
              decoration: const InputDecoration(
                hintText: 'Votre mot de passe',
                hintStyle: TextStyle(color: Color(0xFFA0ABBE)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          IconButton(
            icon: Icon(_showPwd ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF6B7A99), size: 18),
            onPressed: () => setState(() => _showPwd = !_showPwd),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ]),
      );

  Widget _submitButton() => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0D1F3C), Color(0xFF1A3560)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF0D1F3C).withOpacity(0.28), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _loginWithPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('Se connecter',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                ]),
        ),
      );

  Widget _socialBtn({required IconData icon, required String label, required VoidCallback onTap}) =>
      InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.12)),
            boxShadow: [BoxShadow(color: const Color(0xFF0D1F3C).withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: const Color(0xFF0D1F3C)),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C))),
          ]),
        ),
      );
}
