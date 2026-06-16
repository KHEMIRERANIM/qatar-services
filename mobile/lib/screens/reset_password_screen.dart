import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String oobCode;
  final VoidCallback onBackToLogin;
  final VoidCallback onLoginSuccess;

  const ResetPasswordScreen({
    super.key,
    required this.oobCode,
    required this.onBackToLogin,
    required this.onLoginSuccess,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _showPwd = false;
  bool _showConfirmPwd = false;
  bool _isLoading = false;
  bool _isValidatingCode = true;
  String? _codeError;
  String? _email;

  String? _passwordError;
  String? _confirmPasswordError;
  String? _globalError;

  @override
  void initState() {
    super.initState();
    _verifyResetCode();
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  /// Verifies the action code sent from email link
  Future<void> _verifyResetCode() async {
    setState(() {
      _isValidatingCode = true;
      _codeError = null;
    });
    try {
      final email = await FirebaseAuth.instance.verifyPasswordResetCode(widget.oobCode);
      if (mounted) {
        setState(() {
          _email = email;
          _isValidatingCode = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _codeError = _mapFirebaseErrorCode(e.code);
          _isValidatingCode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _codeError = "Impossible de vérifier le lien de réinitialisation.";
          _isValidatingCode = false;
        });
      }
    }
  }

  String _mapFirebaseErrorCode(String code) {
    switch (code) {
      case 'expired-action-code':
        return 'Le lien de réinitialisation a expiré. Veuillez en demander un nouveau.';
      case 'invalid-action-code':
        return 'Le lien de réinitialisation est invalide ou a déjà été utilisé.';
      case 'user-disabled':
        return 'Le compte associé à ce lien a été désactivé.';
      case 'user-not-found':
        return 'Utilisateur introuvable.';
      default:
        return 'Erreur de lien de réinitialisation ($code).';
    }
  }

  bool _validate() {
    final pwd = _passwordCtrl.text;
    final cpwd = _confirmPasswordCtrl.text;
    setState(() {
      _passwordError = pwd.isEmpty
          ? 'Champ requis'
          : pwd.length < 8
              ? 'Le mot de passe doit contenir au moins 8 caractères'
              : null;
      _confirmPasswordError = cpwd.isEmpty
          ? 'Champ requis'
          : cpwd != pwd
              ? 'Les mots de passe ne correspondent pas'
              : null;
      _globalError = null;
    });
    return _passwordError == null && _confirmPasswordError == null;
  }

  Future<void> _resetPassword() async {
    if (!_validate() || _isLoading) return;
    setState(() {
      _isLoading = true;
      _globalError = null;
    });

    try {
      // 1. Reset password in Firebase Auth using the action code
      await FirebaseAuth.instance.confirmPasswordReset(
        code: widget.oobCode,
        newPassword: _passwordCtrl.text,
      );

      // 2. Auto-login in backend
      if (_email != null) {
        var loginResult = await AuthService.login(
          identifier: _email!,
          password: _passwordCtrl.text,
        );
        
        // If it fails, try to sync password first
        if (!loginResult.success) {
          final idToken = await FirebaseAuth.instance.currentUser?.getIdToken() ?? '';
          await AuthService.syncPassword(
            email: _email!,
            password: _passwordCtrl.text,
            idToken: idToken,
          );
          loginResult = await AuthService.login(
            identifier: _email!,
            password: _passwordCtrl.text,
          );
        }

        if (loginResult.success && mounted) {
          _showSnack('Mot de passe modifié avec succès !', success: true);
          widget.onLoginSuccess();
          return;
        }
      }

      if (mounted) {
        _showSnack('Mot de passe modifié ! Veuillez vous connecter.', success: true);
        widget.onBackToLogin();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _globalError = _mapFirebaseResetError(e.code);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _globalError = "Une erreur est survenue lors de la réinitialisation.";
          _isLoading = false;
        });
      }
    }
  }

  String _mapFirebaseResetError(String code) {
    switch (code) {
      case 'expired-action-code':
        return 'Le lien a expiré. Veuillez refaire une demande.';
      case 'invalid-action-code':
        return 'Lien invalide.';
      case 'weak-password':
        return 'Le mot de passe choisi est trop faible.';
      default:
        return 'Une erreur est survenue ($code).';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        top: false,
        child: _isValidatingCode
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF0D1F3C),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Vérification du lien...',
                      style: TextStyle(color: Color(0xFF0D1F3C), fontWeight: FontWeight.w500),
                    )
                  ],
                ),
              )
            : _codeError != null
                ? _buildErrorState()
                : _buildResetForm(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Lien expiré ou invalide',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D1F3C),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _codeError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7A99),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: widget.onBackToLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1F3C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text(
                  'Retour à la connexion',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResetForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header with Brand Colors ──────────────────────────────────────────
          Stack(
            children: [
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
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC9A84C),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC9A84C).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'QS',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                        ),
                      ),
                    ),
                    const Text(
                      'Qatar Services',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Nouveau mot de passe',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: -48,
                top: -48,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                left: -24,
                bottom: 0,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A84C).withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),

          // ── Form ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_email != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1F3C).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_circle_outlined, color: Color(0xFF0D1F3C), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Compte : $_email',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0D1F3C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Global error banner
                if (_globalError != null) ...[
                  _errorBanner(_globalError!),
                  const SizedBox(height: 16),
                ],

                // Nouveau Mot de Passe
                _label('Nouveau mot de passe'),
                _passwordBox(
                  controller: _passwordCtrl,
                  hint: 'Entrez au moins 8 caractères',
                  error: _passwordError,
                  showVal: _showPwd,
                  onToggleShow: () => setState(() => _showPwd = !_showPwd),
                ),
                if (_passwordError != null) _errText(_passwordError!),
                const SizedBox(height: 16),

                // Confirmer Mot de Passe
                _label('Confirmer le mot de passe'),
                _passwordBox(
                  controller: _confirmPasswordCtrl,
                  hint: 'Saisissez à nouveau le mot de passe',
                  error: _confirmPasswordError,
                  showVal: _showConfirmPwd,
                  onToggleShow: () => setState(() => _showConfirmPwd = !_showConfirmPwd),
                ),
                if (_confirmPasswordError != null) _errText(_confirmPasswordError!),
                const SizedBox(height: 24),

                // Submit Button
                _submitButton(),
                const SizedBox(height: 20),

                // Cancel Link
                TextButton(
                  onPressed: widget.onBackToLogin,
                  child: const Text(
                    'Annuler et retourner au Login',
                    style: TextStyle(
                      color: Color(0xFF6B7A99),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0D1F3C),
          ),
        ),
      );

  Widget _errText(String msg) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          msg,
          style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
        ),
      );

  Widget _errorBanner(String msg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
              ),
            ),
          ],
        ),
      );

  Widget _passwordBox({
    required TextEditingController controller,
    required String hint,
    required String? error,
    required bool showVal,
    required VoidCallback onToggleShow,
  }) =>
      Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: error != null ? const Color(0xFFEF4444) : const Color(0xFF1A237E).withOpacity(0.12),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Color(0xFF6B7A99), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                obscureText: !showVal,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A237E)),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Color(0xFFA0ABBE)),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                showVal ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: const Color(0xFF6B7A99),
                size: 18,
              ),
              onPressed: onToggleShow,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );

  Widget _submitButton() => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A237E).withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _resetPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Enregistrer',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                  ],
                ),
        ),
      );
}
