import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/token_service.dart';

class SignupScreen extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String email) onSuccess;

  const SignupScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _selectedVille;
  int _selectedDay = 1;
  int _selectedMonth = 1;
  int _selectedYear = 2000;

  String _selectedCountryCode = '+974';
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _isLoading = false;

  final Map<String, String?> _errors = {};

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
   _confirmController.dispose();
   super.dispose();
  }

  bool _validate() {
    setState(() {
      _errors.clear();
      if (_firstNameController.text.trim().isEmpty) {
        _errors['firstName'] = "Requis";
      }
      if (_lastNameController.text.trim().isEmpty) {
        _errors['lastName'] = "Requis";
      }
      if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(_emailController.text)) {
        _errors['email'] = "Email invalide";
      }
      if (_phoneController.text.length < 6) {
        _errors['phone'] = "Numéro invalide";
      }
     if (_passwordController.text.length < 8) {
       _errors['password'] = "Minimum 8 caractères";
     }
      if (_confirmController.text != _passwordController.text) {
        _errors['confirm'] = "Ne correspond pas";
      }
    });

    return _errors.isEmpty;
  }

  String? _globalError;

  Future<void> _register() async {
    if (!_validate() || _isLoading) return;
    setState(() { _isLoading = true; _globalError = null; });

    try {
      // 1. Création sur Firebase pour générer l'email de vérification
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      await userCredential.user?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // Compte Firebase existant : se connecter et renvoyer la vérification
        try {
          final signInResult = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
          final user = signInResult.user;
          if (user != null && !user.emailVerified) {
            await user.sendEmailVerification();
          }
        } catch (err) {
          debugPrint('Firebase resend verification failed: $err');
          setState(() {
            _isLoading = false;
            _globalError = "Cet email est déjà utilisé avec un autre mot de passe.";
          });
          return; // ABORT Node.js registration
        }
      } else {
        debugPrint('Firebase Auth Error (Verification): $e');
        setState(() {
          _isLoading = false;
          _globalError = "Erreur de création de compte Firebase : ${e.message}";
        });
        return; // ABORT Node.js registration
      }
    } catch (e) {
      debugPrint('Firebase Auth Error (Verification): $e');
      setState(() {
        _isLoading = false;
        _globalError = "Une erreur est survenue lors de la création du compte.";
      });
      return; // ABORT Node.js registration
    }

    // 2. Inscription sur le backend Node.js (Base de données principale)
 final result = await AuthService.register({
   'prenom': _firstNameController.text.trim(),
   'nom': _lastNameController.text.trim(),
   'email': _emailController.text.trim(),
   'telephone': '$_selectedCountryCode${_phoneController.text.trim()}',
   'mot_de_passe': _passwordController.text,
 'ville': _selectedVille ?? '',
   'date_naissance': '${_selectedYear.toString().padLeft(4, '0')}-${_selectedMonth.toString().padLeft(2, '0')}-${_selectedDay.toString().padLeft(2, '0')}',
   'role': 'pro',
 });
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // Auto-login pour obtenir le token et aller directement à l'accueil
      await AuthService.login(
        identifier: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compte créé ! Un email de vérification vous a été envoyé.'),
          backgroundColor: Color(0xFF2D9B6F),
          duration: Duration(seconds: 4),
        ),
      );
      widget.onSuccess(_emailController.text.trim());
    } else {
      setState(() => _globalError = result.message);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() { _isLoading = true; _globalError = null; });
    try {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      final fbResult = await FirebaseAuth.instance.signInWithPopup(provider);
      final user = fbResult.user;
      if (user == null) throw Exception('Utilisateur Google introuvable');

      // Parse name from Firebase display name
      final parts = (user.displayName ?? '').split(' ');
      final prenom = parts.isNotEmpty ? parts[0] : '';
      final nom = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      // Register/login in MySQL backend
      final backendResult = await AuthService.socialLogin(
        email: user.email ?? '',
        prenom: prenom,
        nom: nom,
        photo: user.photoURL,
        uid: user.uid,
      );

      if (!mounted) return;
      if (backendResult.success) {
        widget.onSuccess(user.email ?? '');
      } else {
        setState(() => _globalError = 'Erreur backend: ${backendResult.message}');
      }
    } catch (e) {
      if (mounted) setState(() => _globalError = 'Connexion Google échouée.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() { _isLoading = true; _globalError = null; });
    try {
      final provider = OAuthProvider('apple.com')..addScope('email')..addScope('name');
      final fbResult = await FirebaseAuth.instance.signInWithPopup(provider);
      final user = fbResult.user;
      if (user == null) throw Exception('Utilisateur Apple introuvable');

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
        widget.onSuccess(user.email ?? '');
      } else {
        setState(() => _globalError = 'Erreur backend: ${backendResult.message}');
      }
    } catch (e) {
      if (mounted) setState(() => _globalError = 'Connexion Apple échouée.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
              // Header
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
                        // Logo
                        Container(
                          width: 64,
                          height: 64,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC9A84C),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "QS",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        const Text(
                          "Qatar Services",
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Playfair Display',
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Créez votre compte gratuitement",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: -56,
                    top: -56,
                    child: Container(
                      width: 192,
                      height: 192,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    left: -32,
                    bottom: 0,
                    child: Container(
                      width: 128,
                      height: 128,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC9A84C).withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),

              // Form
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Social Login
                    Row(
                      children: [
                        Expanded(
                          child: _buildSocialButton(
                            icon: Icons.g_mobiledata_rounded,
                            label: "Google",
                            onPressed: _signInWithGoogle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSocialButton(
                            icon: Icons.apple,
                            label: "Apple",
                            onPressed: _signInWithApple,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFE8EDF5),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "ou",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA0ABBE),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: const Color(0xFFE8EDF5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Global error banner
                    if (_globalError != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_globalError!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))),
                        ]),
                      ),
                    ],

                    // Fields
                    _buildField(
                      key: "firstName",
                      label: "Prénom",
                      placeholder: "Mohammed",
                      icon: Icons.person_outline,
                      controller: _firstNameController,
                    ),
                    _buildField(
                      key: "lastName",
                      label: "Nom",
                      placeholder: "Al-Rashid",
                      icon: Icons.person_outline,
                      controller: _lastNameController,
                    ),
                    _buildField(
                      key: "email",
                      label: "Email",
                      placeholder: "email@exemple.com",
                      icon: Icons.mail_outline,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                   _buildPhoneField(),
                   _buildVilleDropdown(),
                   _buildDateNaissanceSelector(),
                   _buildField(
                     key: "password",
                      label: "Mot de passe",
                      placeholder: "Minimum 8 caractères",
                      icon: Icons.lock_outline,
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      rightWidget: IconButton(
                        icon: Icon(
                          _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF6B7A99),
                          size: 16,
                        ),
                        onPressed: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                    _buildField(
                      key: "confirm",
                      label: "Confirmer le mot de passe",
                      placeholder: "Répétez le mot de passe",
                      icon: Icons.lock_outline,
                      controller: _confirmController,
                      obscureText: !_showConfirm,
                      rightWidget: IconButton(
                        icon: Icon(
                          _showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: const Color(0xFF6B7A99),
                          size: 16,
                        ),
                        onPressed: () {
                          setState(() {
                            _showConfirm = !_showConfirm;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Submit
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D1F3C), Color(0xFF1A3560)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D1F3C).withOpacity(0.28),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                "S'inscrire",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Back to login
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Déjà inscrit ? ",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7A99),
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onBack,
                          child: const Text(
                            "Se connecter",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC9A84C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String key,
    required String label,
    required String placeholder,
    required IconData icon,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? rightWidget,
  }) {
    final hasError = _errors[key] != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D1F3C),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasError
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF0D1F3C).withOpacity(0.12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: const Color(0xFF6B7A99),
                  size: 17,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    obscureText: obscureText,
                    keyboardType: keyboardType,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0D1F3C),
                    ),
                    decoration: InputDecoration(
                      hintText: placeholder,
                      hintStyle: const TextStyle(color: Color(0xFFA0ABBE)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (rightWidget != null) rightWidget,
              ],
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Text(
              _errors[key]!,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    final hasError = _errors['phone'] != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Téléphone",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D1F3C),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasError
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF0D1F3C).withOpacity(0.12),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountryCode,
                    icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF6B7A99)),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C), fontWeight: FontWeight.bold),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() { _selectedCountryCode = newValue; });
                      }
                    },
                    items: <Map<String, String>>[
                      {'code': '+974', 'flag': '🇶🇦'},
                      {'code': '+33', 'flag': '🇫🇷'},
                      {'code': '+216', 'flag': '🇹🇳'},
                      {'code': '+212', 'flag': '🇲🇦'},
                      {'code': '+213', 'flag': '🇩🇿'},
                      {'code': '+971', 'flag': '🇦🇪'},
                      {'code': '+966', 'flag': '🇸🇦'},
                    ].map<DropdownMenuItem<String>>((Map<String, String> item) {
                      return DropdownMenuItem<String>(
                        value: item['code'],
                        child: Text('${item['flag']} ${item['code']}'),
                      );
                    }).toList(),
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  color: const Color(0xFF0D1F3C).withOpacity(0.12),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                ),
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
                    decoration: const InputDecoration(
                      hintText: "5XXX XXXX",
                      hintStyle: TextStyle(color: Color(0xFFA0ABBE)),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Text(
              _errors['phone']!,
              style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVilleDropdown() {
    final hasError = _errors['ville'] != null;
    final villes = ['Doha', 'Al Rayyan', 'Al Wakrah', 'Umm Salal', 'Al Khor', 'Al Daayen', 'Al Shahaniya', 'Al Shamal'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Ville (Qatar)",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D1F3C))),
          const SizedBox(height: 6),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasError ? const Color(0xFFEF4444) : const Color(0xFF0D1F3C).withOpacity(0.12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFF6B7A99), size: 17),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedVille,
                      isExpanded: true,
                      hint: const Text("Sélectionnez votre ville", style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 14)),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF6B7A99)),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
                      onChanged: (String? newValue) {
                        setState(() { _selectedVille = newValue; });
                      },
                      items: villes.map<DropdownMenuItem<String>>((String v) {
                        return DropdownMenuItem<String>(value: v, child: Text(v));
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 4),
            Text(_errors['ville']!, style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444))),
          ],
        ],
      ),
    );
  }

  String _formatDate() {
    return '${_selectedDay.toString().padLeft(2, '0')}/${_selectedMonth.toString().padLeft(2, '0')}/$_selectedYear';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth, _selectedDay),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D1F3C),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0D1F3C),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDay = picked.day;
        _selectedMonth = picked.month;
        _selectedYear = picked.year;
      });
    }
  }

  Widget _buildDateNaissanceSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Date de naissance",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D1F3C)),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.12)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.cake_outlined, color: Color(0xFF6B7A99), size: 17),
                  const SizedBox(width: 12),
                  Text(
                    _formatDate(),
                    style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
                  ),
                  const Spacer(),
                  const Icon(Icons.calendar_today_outlined, color: Color(0xFF6B7A99), size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D1F3C).withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF0D1F3C)),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D1F3C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
