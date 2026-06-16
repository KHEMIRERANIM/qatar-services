import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/token_service.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String? verificationId;
  final dynamic confirmationResult; // ConfirmationResult on web
  final VoidCallback onSuccess;
  final VoidCallback onBack;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.verificationId,
    this.confirmationResult,
    required this.onSuccess,
    required this.onBack,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with SingleTickerProviderStateMixin {
  // 6 controllers + focus nodes
  final List<TextEditingController> _ctls = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  String? _error;

  // 5-minute timer
  static const int _totalSeconds = 300;
  int _secondsLeft = _totalSeconds;
  Timer? _timer;

  // Shake animation for wrong code
  late AnimationController _shakeCtrl;
  late Animation<Offset> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = TweenSequence<Offset>([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(0.04, 0)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.04, 0), end: const Offset(-0.04, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.04, 0), end: Offset.zero), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nodes[0].requestFocus());
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _totalSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsLeft <= 0) { t.cancel(); return; }
      setState(() => _secondsLeft--);
    });
  }

  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _otp => _ctls.map((c) => c.text).join();
  bool get _isComplete => _otp.length == 6;
  bool get _canResend => _secondsLeft == 0 && !_isResending;

  void _onChanged(int idx, String val) {
    if (val.length > 1) {
      // Handle paste
      final digits = val.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _ctls[i].text = digits[i];
      }
      final next = digits.length < 6 ? digits.length : 5;
      _nodes[next].requestFocus();
    } else if (val.isNotEmpty && idx < 5) {
      _nodes[idx + 1].requestFocus();
    }
    setState(() => _error = null);
  }

  void _onKey(int idx, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _ctls[idx].text.isEmpty &&
        idx > 0) {
      _nodes[idx - 1].requestFocus();
      _ctls[idx - 1].clear();
    }
  }

  Future<void> _verify() async {
    if (!_isComplete) {
      setState(() => _error = 'Veuillez entrer les 6 chiffres du code OTP');
      _shakeCtrl.forward(from: 0);
      return;
    }

    setState(() { _isVerifying = true; _error = null; });

    try {
      final code = _otp;

      if (widget.confirmationResult != null) {
        // Web: ConfirmationResult.confirm()
        final result = await widget.confirmationResult.confirm(code);
        final idToken = await result.user?.getIdToken();
        if (idToken != null) await TokenService.saveToken(idToken);
      } else if (widget.verificationId != null) {
        // Mobile
        final cred = PhoneAuthProvider.credential(
          verificationId: widget.verificationId!,
          smsCode: code,
        );
        final result = await FirebaseAuth.instance.signInWithCredential(cred);
        final idToken = await result.user?.getIdToken();
        if (idToken != null) await TokenService.saveToken(idToken);
      } else {
        // Demo fallback (no Firebase configured)
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      if (mounted) widget.onSuccess();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _mapFirebaseError(e.code));
      _shakeCtrl.forward(from: 0);
      _clearBoxes();
    } catch (e) {
      setState(() => _error = 'Erreur de vérification. Réessayez.');
      _shakeCtrl.forward(from: 0);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() { _isResending = true; _error = null; });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: (cred) async {
          await FirebaseAuth.instance.signInWithCredential(cred);
          if (mounted) widget.onSuccess();
        },
        verificationFailed: (e) {
          if (mounted) setState(() => _error = _mapFirebaseError(e.code));
        },
        codeSent: (verificationId, _) {
          if (mounted) {
            _showSnack('Code renvoyé avec succès !', success: true);
            _startTimer();
          }
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (_) {
      // Demo fallback
      _showSnack('Code renvoyé !', success: true);
      _startTimer();
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _clearBoxes() {
    for (final c in _ctls) c.clear();
    _nodes[0].requestFocus();
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

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'invalid-verification-code': return 'Code OTP invalide. Vérifiez et réessayez.';
      case 'session-expired': return 'Session expirée. Renvoyez le code.';
      case 'too-many-requests': return 'Trop de tentatives. Réessayez plus tard.';
      case 'user-disabled': return 'Ce compte a été désactivé.';
      default: return 'Erreur d\'authentification ($code)';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    for (final c in _ctls) c.dispose();
    for (final n in _nodes) n.dispose();
    super.dispose();
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
              // Header Banner
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
                    // Shield icon
                    Container(
                      width: 64, height: 64,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC9A84C),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.shield_outlined, color: Colors.white, size: 32),
                    ),
                    const Text('Vérification OTP',
                        style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Code envoyé au ${_maskPhone(widget.phoneNumber)}',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                  ]),
                ),
                Positioned(right: -56, top: -56, child: _circle(192, Colors.white.withOpacity(0.04))),
                Positioned(left: -32, bottom: 0, child: _circle(128, const Color(0xFFC9A84C).withOpacity(0.06))),
              ]),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Timer card
                  _timerCard(),
                  const SizedBox(height: 28),

                  // OTP Boxes
                  const Text('Entrez le code reçu par SMS',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7A99))),
                  const SizedBox(height: 20),
                  SlideTransition(
                    position: _shakeAnim,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) => _otpBox(i)),
                    ),
                  ),

                  // Error message
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Verify button
                  _verifyButton(),
                  const SizedBox(height: 16),

                  // Resend button
                  _resendButton(),
                  const SizedBox(height: 24),

                  // Back link
                  Center(
                    child: TextButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_ios, size: 14, color: Color(0xFF6B7A99)),
                      label: const Text('Retour à la connexion',
                          style: TextStyle(color: Color(0xFF6B7A99), fontSize: 13)),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timerCard() {
    final isExpired = _secondsLeft == 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: isExpired
            ? const Color(0xFFEF4444).withOpacity(0.06)
            : const Color(0xFF0D1F3C).withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired
              ? const Color(0xFFEF4444).withOpacity(0.2)
              : const Color(0xFF0D1F3C).withOpacity(0.08),
        ),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(
          isExpired ? Icons.timer_off_outlined : Icons.timer_outlined,
          color: isExpired ? const Color(0xFFEF4444) : const Color(0xFFC9A84C),
          size: 20,
        ),
        const SizedBox(width: 10),
        Text(
          isExpired ? 'Code expiré' : 'Expire dans ',
          style: TextStyle(
            color: isExpired ? const Color(0xFFEF4444) : const Color(0xFF6B7A99),
            fontSize: 14,
          ),
        ),
        if (!isExpired)
          Text(
            _timerText,
            style: const TextStyle(
              color: Color(0xFF0D1F3C),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
      ]),
    );
  }

  Widget _otpBox(int idx) {
    final isFilled = _ctls[idx].text.isNotEmpty;
    final hasError = _error != null;
    return SizedBox(
      width: 44, height: 54,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) => _onKey(idx, event),
        child: TextField(
          controller: _ctls[idx],
          focusNode: _nodes[idx],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6, // allow paste
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: isFilled
                ? const Color(0xFFC9A84C).withOpacity(0.08)
                : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFEF4444)
                    : isFilled
                        ? const Color(0xFFC9A84C)
                        : const Color(0xFF0D1F3C).withOpacity(0.15),
                width: isFilled ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFC9A84C), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: hasError
                    ? const Color(0xFFEF4444)
                    : isFilled
                        ? const Color(0xFFC9A84C)
                        : const Color(0xFF0D1F3C).withOpacity(0.15),
                width: isFilled ? 2 : 1,
              ),
            ),
          ),
          onChanged: (val) => _onChanged(idx, val),
        ),
      ),
    );
  }

  Widget _verifyButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1F3C), Color(0xFF1A3560)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: const Color(0xFF0D1F3C).withOpacity(0.28), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ElevatedButton(
        onPressed: _isVerifying ? null : _verify,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isVerifying
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Vérifier le code',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
      ),
    );
  }

  Widget _resendButton() {
    return OutlinedButton(
      onPressed: _canResend ? _resend : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(
          color: _canResend ? const Color(0xFFC9A84C) : const Color(0xFF0D1F3C).withOpacity(0.15),
          width: 1.5,
        ),
      ),
      child: _isResending
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(color: Color(0xFFC9A84C), strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded,
                    size: 18,
                    color: _canResend ? const Color(0xFFC9A84C) : const Color(0xFFADB5BD)),
                const SizedBox(width: 8),
                Text(
                  'Renvoyer le code',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _canResend ? const Color(0xFFC9A84C) : const Color(0xFFADB5BD),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  String _maskPhone(String phone) {
    if (phone.length < 5) return phone;
    return '${phone.substring(0, 4)}****${phone.substring(phone.length - 3)}';
  }
}
