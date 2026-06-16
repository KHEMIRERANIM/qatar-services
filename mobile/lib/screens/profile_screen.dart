import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onAddService;

  const ProfileScreen({
    super.key,
    required this.onLogout,
    required this.onAddService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isPro = false;
  bool _isLoadingProfile = true;

  // Profile data (populated from API)
  String _name = "";
  String _email = "";
  String _phone = "";
  String _imageUrl = "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&auto=format";

  // Fallback Pro profile display data
  final String _proName = "Fatima Al-Kuwari";
  final String _proEmail = "fatima@email.com";
  final String _proPhone = "+974 5598 7654";
  final String _proImageUrl = "https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=200&h=200&fit=crop&auto=format";

  final List<Map<String, dynamic>> _proServices = [
    {"id": 1, "title": "Cours d'anglais", "price": "80 QAR/h", "active": true},
    {"id": 2, "title": "Traduction FR/AR", "price": "50 QAR/h", "active": true},
    {"id": 3, "title": "Préparation IELTS", "price": "120 QAR/h", "active": false},
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final result = await AuthService.getProfile();
    if (!mounted) return;
    setState(() => _isLoadingProfile = false);

    if (result.success && result.data != null) {
      final data = result.data!;
      // Backend returns data under 'user' key
      final userData = data['user'] ?? data;
      setState(() {
        _name = '${userData['prenom'] ?? userData['firstName'] ?? ''} ${userData['nom'] ?? userData['lastName'] ?? ''}'.trim();
        if (_name.isEmpty) _name = userData['name'] ?? userData['username'] ?? '';
        _email = userData['email'] ?? '';
        _phone = userData['telephone'] ?? userData['phone'] ?? '';
        _isPro = userData['role'] == 'pro' || userData['isPro'] == true;
        if (userData['photo'] != null && userData['photo'].toString().isNotEmpty) {
          _imageUrl = userData['photo'];
        }
      });
    }

    // Fallback/enrich with Firebase Auth data
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        if (_name.isEmpty && user.displayName != null && user.displayName!.isNotEmpty) {
          _name = user.displayName!;
        }
        if (_email.isEmpty && user.email != null && user.email!.isNotEmpty) {
          _email = user.email!;
        }
        if (_phone.isEmpty && user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
          _phone = user.phoneNumber!;
        }
        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          _imageUrl = user.photoURL!;
        }
      });
    }

    if (_name.isEmpty) _name = 'Utilisateur';

    // Ne PAS rediriger vers login si le profil échoue temporairement
    // L'utilisateur peut toujours utiliser l'app avec les données Firebase
    if (!result.success && result.tokenExpired) {
      debugPrint('Token expired during profile load');
    }
  }

  void _editProfileInfo() {
    final nameController = TextEditingController(text: _isPro ? _proName : _name);
    final emailController = TextEditingController(text: _isPro ? _proEmail : _email);
    final phoneController = TextEditingController(text: _isPro ? _proPhone : _phone);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Modifier mes infos',
                          style: TextStyle(color: Color(0xFF0D1F3C), fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Color(0xFF6B7A99)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildEditField(label: 'Nom complet', controller: nameController),
                  const SizedBox(height: 14),
                  _buildEditField(label: 'Email', controller: emailController, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 14),
                  _buildEditField(label: 'Téléphone', controller: phoneController, keyboardType: TextInputType.phone),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setSheet(() => isSaving = true);
                            final fullName = nameController.text.trim();
                            final nameParts = fullName.split(' ');
                            final prenom = nameParts.isNotEmpty ? nameParts[0] : '';
                            final nom = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

                            final result = await AuthService.updateProfile({
                              'prenom': prenom,
                              'nom': nom,
                              'email': emailController.text.trim(),
                              'telephone': phoneController.text.trim(),
                            });
                            if (!mounted) return;
                            if (result.tokenExpired) { widget.onLogout(); return; }
                            Navigator.pop(context);
                            if (result.success) {
                              setState(() {
                                _name = fullName;
                                _email = emailController.text.trim();
                                _phone = phoneController.text.trim();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profil mis à jour !'),
                                  backgroundColor: Color(0xFF2D9B6F),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(result.message ?? 'Erreur de mise à jour'),
                                  backgroundColor: const Color(0xFFEF4444),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D1F3C),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isSaving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Enregistrer',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D1F3C)),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          ),
        ),
      ],
    );
  }

  // Simulate changing photo
  void _changeProfilePhoto() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Photo de profil",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFC9A84C)),
                title: const Text("Choisir depuis la galerie"),
                onTap: () {
                  setState(() {
                    // Switch to a different mock portrait image
                    _imageUrl = "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop&auto=format";
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Nouvelle photo de profil sélectionnée !"),
                      backgroundColor: Color(0xFF2D9B6F),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF0D1F3C)),
                title: const Text("Prendre une photo"),
                onTap: () {
                  setState(() {
                    _imageUrl = "https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&auto=format";
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Photo capturée avec succès !"),
                      backgroundColor: Color(0xFF2D9B6F),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Navigate to Upgrade Pro Screen
  void _upgradeToProFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpgradeProScreen(
          onComplete: () {
            setState(() {
              _isPro = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Félicitations ! Vous êtes maintenant un Professionnel vérifié."),
                backgroundColor: Color(0xFF2D9B6F),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFC9A84C),
            strokeWidth: 2.5,
          ),
        ),
      );
    }
    return _isPro ? _buildProProfile() : _buildClientProfile();
  }

  /* ─── Client Profile View ────────────────────────────────── */
  Widget _buildClientProfile() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.only(top: 56, bottom: 64, left: 20, right: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1F3C), Color(0xFF1A3560)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Mon Profil",
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: _editProfileInfo,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.edit, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: -48,
                  top: -48,
                  child: Container(
                    width: 144,
                    height: 144,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),

            // Avatar Card Overlay
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D1F3C).withOpacity(0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                    image: NetworkImage(_imageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -4,
                                right: -4,
                                child: InkWell(
                                  onTap: _changeProfilePhoto,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFC9A84C),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D1F3C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8EDF5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    "Client",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6B7A99),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(height: 1, color: const Color(0xFFF0F2F7)),
                      const SizedBox(height: 16),

                      // Email / Phone rows
                      _buildInfoRow(Icons.mail_outline, _email),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.phone_iphone_outlined, _phone),

                      const SizedBox(height: 20),
                      // Edit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _editProfileInfo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0D1F3C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            "Modifier mes infos",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Devenir Pro Gold Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell(
                onTap: _upgradeToProFlow,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC9A84C), Color(0xFFA8893B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC9A84C).withOpacity(0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.star, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "⭐ Devenir Pro",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "Uploadez vos documents et obtenez le badge vérifié",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Navigation menu list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.settings_outlined,
                      label: "Paramètres",
                      iconColor: const Color(0xFF6366F1),
                      onTap: () {},
                    ),
                    Container(height: 1, color: const Color(0xFFF5F7FA)),
                    _buildMenuItem(
                      icon: Icons.logout,
                      label: "Déconnexion",
                      iconColor: const Color(0xFFEF4444),
                      danger: true,
                      onTap: widget.onLogout,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /* ─── Pro Profile View ───────────────────────────────────── */
  Widget _buildProProfile() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.only(top: 56, bottom: 64, left: 20, right: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1F3C), Color(0xFF1A3560)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Mon Profil",
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: _editProfileInfo,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.edit, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: -48,
                  top: -48,
                  child: Container(
                    width: 144,
                    height: 144,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),

            // Avatar Card Overlay
            Transform.translate(
              offset: const Offset(0, -32),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D1F3C).withOpacity(0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  image: DecorationImage(
                                    image: NetworkImage(_proImageUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -4,
                                right: -4,
                                child: InkWell(
                                  onTap: _changeProfilePhoto,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFC9A84C),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _proName,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0D1F3C),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF2D9B6F),
                                      size: 18,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFC9A84C), Color(0xFFA8893B)],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star, color: Colors.white, size: 10),
                                      SizedBox(width: 4),
                                      Text(
                                        "Professionnel vérifié",
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(height: 1, color: const Color(0xFFF0F2F7)),
                      const SizedBox(height: 16),

                      // Email / Phone rows
                      _buildInfoRow(Icons.mail_outline, _proEmail),
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.phone_iphone_outlined, _proPhone),

                      const SizedBox(height: 20),
                      Container(height: 1, color: const Color(0xFFF0F2F7)),
                      const SizedBox(height: 16),

                      // Stats Row
                      Row(
                        children: [
                          _buildStatItem("80", "Services"),
                          _buildStatDivider(),
                          _buildStatItem("4.9★", "Note"),
                          _buildStatDivider(),
                          _buildStatItem("1.2k", "Avis"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Plus Ajouter Service Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFC9A84C), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC9A84C).withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: widget.onAddService,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.add, color: Color(0xFFC9A84C), size: 20),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "➕ Ajouter un service",
                                style: TextStyle(
                                  color: Color(0xFF0D1F3C),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Publiez une nouvelle offre",
                                style: TextStyle(color: Color(0xFF6B7A99), fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Color(0xFFC9A84C), size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Mes services title and list
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Mes services",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D1F3C),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _proServices.length,
                    itemBuilder: (context, index) {
                      final s = _proServices[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s["title"],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0D1F3C),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  s["price"],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFC9A84C),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: s["active"] ? const Color(0xFFECFDF5) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                s["active"] ? "Actif" : "Inactif",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: s["active"] ? const Color(0xFF2D9B6F) : const Color(0xFF6B7A99),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Navigation menu list (Pro)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.settings_outlined,
                      label: "Paramètres",
                      iconColor: const Color(0xFF6366F1),
                      onTap: () {},
                    ),
                    Container(height: 1, color: const Color(0xFFF5F7FA)),
                    _buildMenuItem(
                      icon: Icons.logout,
                      label: "Déconnexion",
                      iconColor: const Color(0xFFEF4444),
                      danger: true,
                      onTap: widget.onLogout,
                    ),
                  ],
                ),
              ),
            ),

            // Dev toggle
            Center(
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _isPro = false;
                  });
                },
                child: const Text(
                  "← Voir profil client",
                  style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 12),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EDF5),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: const Color(0xFF6B7A99), size: 15),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
        ),
      ],
    );
  }

  Widget _buildStatItem(String number, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            number,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7A99)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 32,
      color: const Color(0xFFF0F2F7),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required Color iconColor,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: danger ? iconColor : const Color(0xFF0D1F3C),
                ),
              ),
            ),
            if (!danger) const Icon(Icons.chevron_right, color: Color(0xFFA0ABBE), size: 16),
          ],
        ),
      ),
    );
  }
}

/* ────────────────────────────────────────────────────────── */
/* ─── UPGRADE TO PRO SCREEN (DOCUMENT UPLOADS) ───────────── */
/* ────────────────────────────────────────────────────────── */
class UpgradeProScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const UpgradeProScreen({super.key, required this.onComplete});

  @override
  State<UpgradeProScreen> createState() => _UpgradeProScreenState();
}

class _UpgradeProScreenState extends State<UpgradeProScreen> {
  final _qidController = TextEditingController();

  // Mock uploaded file names
  String? _qidFrontFile;
  String? _qidBackFile;
  String? _diplomaFile;
  String? _licenseFile;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _qidController.dispose();
    super.dispose();
  }

  void _simulateUpload(String docType) {
    String mockFileName = "";
    if (docType == "qid_front") mockFileName = "QID_Front_Card.png";
    if (docType == "qid_back") mockFileName = "QID_Back_Card.png";
    if (docType == "diploma") mockFileName = "Attestation_Diplome.pdf";
    if (docType == "license") mockFileName = "Licence_Professionnelle.pdf";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          content: Row(
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC9A84C))),
              SizedBox(width: 20),
              Text("Téléchargement du fichier...", style: TextStyle(color: Color(0xFF0D1F3C))),
            ],
          ),
        );
      },
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.pop(context); // Close spinner dialog
        setState(() {
          if (docType == "qid_front") _qidFrontFile = mockFileName;
          if (docType == "qid_back") _qidBackFile = mockFileName;
          if (docType == "diploma") _diplomaFile = mockFileName;
          if (docType == "license") _licenseFile = mockFileName;
        });
      }
    });
  }

  void _removeFile(String docType) {
    setState(() {
      if (docType == "qid_front") _qidFrontFile = null;
      if (docType == "qid_back") _qidBackFile = null;
      if (docType == "diploma") _diplomaFile = null;
      if (docType == "license") _licenseFile = null;
    });
  }

  void _submitDossier() {
    if (_qidController.text.trim().length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Le numéro QID doit comporter 11 chiffres."),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_qidFrontFile == null || _qidBackFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez uploader le QID Recto et Verso."),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_diplomaFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez uploader votre attestation/diplôme."),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        Navigator.pop(context); // Exit this screen
        widget.onComplete(); // Set parent state isPro = true
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitting) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC9A84C)),
              ),
              const SizedBox(height: 24),
              const Text(
                "Soumission de votre dossier...",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1F3C),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Cryptage et téléversement sécurisé des documents",
                style: TextStyle(color: Color(0xFF6B7A99), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

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
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
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
                  const Text(
                    "Devenir Professionnel",
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Playfair Display',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Envoyez vos justificatifs pour vérification",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Warning Shield Info
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2D9B6F).withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_user, color: Color(0xFF2D9B6F), size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Vos documents sont cryptés et stockés en toute sécurité. Seuls nos agents de vérification y ont accès.",
                              style: TextStyle(color: Color(0xFF0B6640), fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // QID number field
                    _buildSectionTitle("Numéro de QID *"),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.12)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _qidController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF0D1F3C)),
                        decoration: const InputDecoration(
                          hintText: "Ex: 29037400123",
                          hintStyle: TextStyle(color: Color(0xFFA0ABBE)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // QID Recto / Verso Row
                    _buildSectionTitle("Carte d'identité du Qatar (QID) *"),
                    Row(
                      children: [
                        Expanded(
                          child: _buildUploadBox(
                            label: "QID Recto",
                            fileName: _qidFrontFile,
                            onTap: () => _simulateUpload("qid_front"),
                            onRemove: () => _removeFile("qid_front"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildUploadBox(
                            label: "QID Verso",
                            fileName: _qidBackFile,
                            onTap: () => _simulateUpload("qid_back"),
                            onRemove: () => _removeFile("qid_back"),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Attestation / Diplôme
                    _buildSectionTitle("Attestation ou Diplôme *"),
                    _buildUploadBox(
                      label: "Uploader diplôme / certificat",
                      fileName: _diplomaFile,
                      onTap: () => _simulateUpload("diploma"),
                      onRemove: () => _removeFile("diploma"),
                    ),
                    const SizedBox(height: 20),

                    // Licence (Optionnel)
                    _buildSectionTitle("Licence Professionnelle (Optionnel)"),
                    _buildUploadBox(
                      label: "Uploader licence commerciale",
                      fileName: _licenseFile,
                      onTap: () => _simulateUpload("license"),
                      onRemove: () => _removeFile("license"),
                    ),

                    const SizedBox(height: 32),

                    // Submit button
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D1F3C), Color(0xFF1A3560)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0D1F3C).withOpacity(0.2),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _submitDossier,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          "Soumettre mon dossier",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0D1F3C),
        ),
      ),
    );
  }

  Widget _buildUploadBox({
    required String label,
    required String? fileName,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    final isUploaded = fileName != null;

    return InkWell(
      onTap: isUploaded ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: isUploaded ? const Color(0xFFECFDF5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUploaded ? const Color(0xFF2D9B6F) : const Color(0xFF0D1F3C).withOpacity(0.12),
            width: isUploaded ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: isUploaded
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF2D9B6F), size: 24),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      fileName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0B6640),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onRemove,
                    child: const Text(
                      "Supprimer",
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: Color(0xFFC9A84C), size: 24),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7A99),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
