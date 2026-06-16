import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/client_register_screen.dart';
import 'screens/create_listing_screen.dart';
import 'screens/home_screen.dart';
import 'screens/otp_screen.dart';
import 'screens/email_verification_screen.dart';
import 'services/token_service.dart';
import 'services/auth_service.dart';
import 'screens/reset_password_screen.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // On web, Firebase is initialized via index.html JS SDK.
    // On mobile, we initialize with FirebaseOptions.
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyDr-Y1GV21ErpfGoC4X2EXT9uVumATVqVM',
        authDomain: 'qatar-services.firebaseapp.com',
        projectId: 'qatar-services',
        storageBucket: 'qatar-services.firebasestorage.app',
        messagingSenderId: '422571595222',
        appId: '1:422571595222:android:cf2d61bbc8d3b0f13e8077',
      ),
    );
  } catch (e) {
    // Firebase already initialized (web) — ignore duplicate app error
    debugPrint('Firebase init: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qatar Services',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D1F3C),
          primary: const Color(0xFF0D1F3C),
          secondary: const Color(0xFFC9A84C),
        ),
        useMaterial3: true,
      ),
      home: const AppRouter(),
    );
  }
}

/// AppRouter: checks JWT token on launch and routes accordingly
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  String _screen = 'splash';

  // OTP params (set when phone login triggers OTP)
  String? _otpPhone;
  dynamic _otpConfirmationResult;
  String? _otpVerificationId;

  // Email verification params
  String _pendingEmail = '';

  // Deep linking and password reset
  StreamSubscription<Uri>? _linkSubscription;
  String? _resetPasswordCode;

  @override
  void initState() {
    super.initState();
    _checkToken();
    _initDeepLinking();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  void _initDeepLinking() {
    final appLinks = AppLinks();

    // Check initial link (cold start)
    appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    // Listen to incoming links (warm start)
    _linkSubscription = appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Deep Link received: $uri');

    // Firebase Dynamic Links may wrap the real URL inside a 'link' query param
    Uri targetUri = uri;
    final linkParam = uri.queryParameters['link'];
    if (linkParam != null) {
      try {
        targetUri = Uri.parse(linkParam);
        debugPrint('Unwrapped Dynamic Link: $targetUri');
      } catch (_) {}
    }

    final mode = targetUri.queryParameters['mode'];
    final oobCode = targetUri.queryParameters['oobCode'];

    // Route to reset password screen if:
    // 1. Firebase action URL with mode=resetPassword
    // 2. Custom scheme qatarservices://reset-password?oobCode=...
    // 3. Any link containing oobCode with resetPassword mode
    if (oobCode != null &&
        (mode == 'resetPassword' ||
         targetUri.path.contains('reset-password') ||
         targetUri.host == 'reset-password' ||
         targetUri.path.contains('auth/action'))) {
      debugPrint('Navigating to reset password with oobCode: $oobCode');
      setState(() {
        _resetPasswordCode = oobCode;
        _screen = 'reset_password';
      });
    }
  }

  /// On launch: if JWT exists → home, else → login
  Future<void> _checkToken() async {
    final hasToken = await TokenService.hasToken();
    if (!mounted) return;

    if (hasToken) {
      // Validate token with backend profile endpoint
      final profileResult = await AuthService.getProfile();
      if (!mounted) return;
      if (profileResult.success) {
        setState(() => _screen = 'home');
        return;
      }
      // Token expired or invalid → clear and go to login
      await TokenService.clearAll();
    }
    if (mounted) setState(() => _screen = 'login');
  }

  void _go(String screen) => setState(() => _screen = screen);

  void _showSnack(String msg, {bool success = true}) {
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
    // ── Splash / Loading ──────────────────────────────────────────────────
    if (_screen == 'splash') {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1F3C),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _QsLogo(),
            SizedBox(height: 32),
            CircularProgressIndicator(
              color: Color(0xFFC9A84C),
              strokeWidth: 2.5,
            ),
          ]),
        ),
      );
    }

    // ── Login ─────────────────────────────────────────────────────────────
    if (_screen == 'login') {
      return LoginScreen(
        onSuccess: () {
          _showSnack('Connexion réussie !');
          _go('home');
        },
        onRegister: () => _go('client_register'),
        onOtp: (phone, confirmationResult, verificationId) {
          setState(() {
            _otpPhone = phone;
            _otpConfirmationResult = confirmationResult;
            _otpVerificationId = verificationId;
            _screen = 'otp';
          });
        },
        onEmailVerify: (email) {
          setState(() {
            _pendingEmail = email;
            _screen = 'email_verify';
          });
        },
      );
    }

    // ── OTP ───────────────────────────────────────────────────────────────
    if (_screen == 'otp') {
      return OtpScreen(
        phoneNumber: _otpPhone ?? '',
        confirmationResult: _otpConfirmationResult,
        verificationId: _otpVerificationId,
        onSuccess: () {
          _showSnack('Vérification réussie !');
          _go('home');
        },
        onBack: () => _go('login'),
      );
    }

    // ── Signup ────────────────────────────────────────────────────────────
    if (_screen == 'signup') {
      return SignupScreen(
        onBack: () => _go('login'),
        onSuccess: (String email) {
          setState(() {
            _pendingEmail = email;
            _screen = 'email_verify';
          });
        },
      );
    }

    // ── Client Register ───────────────────────────────────────────────────
    if (_screen == 'client_register') {
      return ClientRegisterScreen(
        onBack: () => _go('login'),
        onSuccess: (String email) {
          setState(() {
            _pendingEmail = email;
            _screen = 'email_verify';
          });
        },
      );
    }

    // ── Email Verification ───────────────────────────────────────────────
    if (_screen == 'email_verify') {
      return EmailVerificationScreen(
        email: _pendingEmail,
        onVerified: () {
          _showSnack('Email vérifié ! Connectez-vous maintenant.');
          _go('login');
        },
        onBack: () => _go('login'),
      );
    }

    // ── Create Listing ────────────────────────────────────────────────────
    if (_screen == 'create_listing') {
      return CreateListingScreen(
        onBack: () => _go('home'),
        onSuccess: () {
          _showSnack('Annonce publiée !');
          _go('home');
        },
      );
    }

    // ── Home ──────────────────────────────────────────────────────────────
    if (_screen == 'home') {
      return HomeScreen(
        onLogout: () async {
          await AuthService.logout();
          _showSnack('Déconnecté avec succès.');
          _go('login');
        },
      );
    }

    // ── Reset Password ───────────────────────────────────────────────────
    if (_screen == 'reset_password' && _resetPasswordCode != null) {
      return ResetPasswordScreen(
        oobCode: _resetPasswordCode!,
        onBackToLogin: () {
          setState(() {
            _resetPasswordCode = null;
            _screen = 'login';
          });
        },
        onLoginSuccess: () {
          setState(() {
            _resetPasswordCode = null;
            _screen = 'home';
          });
        },
      );
    }

    // Fallback
    return const SizedBox.shrink();
  }
}

/// Qatar Services Logo Widget
class _QsLogo extends StatelessWidget {
  const _QsLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFFC9A84C),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFFC9A84C).withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      alignment: Alignment.center,
      child: const Text('QS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 28)),
    );
  }
}
