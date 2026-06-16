import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class ClientRegisterScreen extends StatefulWidget {
  final VoidCallback onBack;
  final void Function(String email) onSuccess;

  const ClientRegisterScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  String _selectedCountryCode = '+974';
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _isLoading = false;
  String? _globalError;

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
      if (_passwordController.text.length < 6) {
        _errors['password'] = "Minimum 6 caractères";
      }
      if (_confirmController.text != _passwordController.text) {
        _errors['confirm'] = "Les mots de passe ne correspondent pas";
      }
    });

    return _errors.isEmpty;
  }

  Future<void> _submit() async {
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
      'role': 'client',
    });

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // Auto-login pour obtenir le token et aller directement à l'accueil
      final loginResult = await AuthService.login(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 56, bottom: 20, left: 20, right: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1F3C), Color(0xFF1A3560)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back chevron
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      fixedSize: const Size(36, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Client Indicator
                  Row(
                    children: [
                      const Text("👤", style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      const Text(
                        "Compte Client",
                        style: TextStyle(
                          color: Color(0xFFC9A84C),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Créer mon compte",
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Playfair Display',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Error banner
                    if (_globalError != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
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

                    // Name row (first and last name in 2-column layout)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildNameField(
                            key: "firstName",
                            label: "Prénom",
                            placeholder: "Mohammed",
                            controller: _firstNameController,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildNameField(
                            key: "lastName",
                            label: "Nom",
                            placeholder: "Al-Rashid",
                            controller: _lastNameController,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Email Field
                    _buildField(
                      key: "email",
                      label: "Email",
                      placeholder: "email@exemple.com",
                      icon: Icons.mail_outline,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    // Phone Field with Country Code Dropdown
                    _buildPhoneField(),

                    // Password Field
                    _buildField(
                      key: "password",
                      label: "Mot de passe",
                      placeholder: "Minimum 6 caractères",
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

                    // Confirm Password Field
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

                    // Submit Button
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
                        onPressed: _isLoading ? null : _submit,
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

                    // Toggle back to login
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField({
    required String key,
    required String label,
    required String placeholder,
    required TextEditingController controller,
  }) {
    final hasError = _errors[key] != null;

    return Column(
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: controller,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0D1F3C),
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: const TextStyle(color: Color(0xFFA0ABBE)),
              border: InputBorder.none,
              isDense: true,
            ),
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
}
