import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/pro_service.dart';
import 'veriff_verification_screen.dart';
import 'native_identity_verification_screen.dart';

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

  // Changer la photo de profil - vraie sélection depuis galerie ou caméra
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
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF0D1F3C)),
                title: const Text("Prendre une photo"),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile == null || !mounted) return;

    final imageFile = File(pickedFile.path);

    // Show local preview immediately
    setState(() {
      _imageUrl = pickedFile.path;
    });

    final result = await AuthService.uploadProfilePhoto(imageFile);
    if (!mounted) return;

    if (result.success && result.data != null) {
      final photoUrl = result.data!['photo'] ?? result.data!['url'];
      if (photoUrl != null) {
        setState(() {
          _imageUrl = photoUrl;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Photo de profil mise à jour avec succès !"),
          backgroundColor: Color(0xFF2D9B6F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? "Erreur lors de l'upload."),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
                                  color: const Color(0xFFE8EDF5),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: _imageUrl.startsWith('http')
                                      ? Image.network(
                                          _imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40, color: Color(0xFF6B7A99)),
                                        )
                                      : Image.file(
                                          File(_imageUrl),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40, color: Color(0xFF6B7A99)),
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
  final ImagePicker _picker = ImagePicker();

  // Selected file paths
  String? _qidFrontPath;
  String? _qidBackPath;
  String? _diplomaPath;

  // Status state
  bool _isLoadingStatus = true;
  bool _isSubmitting = false;
  String _verificationStatus = 'non_demande';
  String? _raisonRefus;
  String? _statusMessage;
  List<String> _documentsInvalides = [];
  String? _resubmitHint;
  Map<String, dynamic> _documentsStatus = {};
  bool _correctionMode = false;
  
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _qidController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;
    setState(() => _isLoadingStatus = true);
    
    final res = await ProService.getStatus();
    if (!mounted) return;
    
    setState(() {
      _isLoadingStatus = false;
      _verificationStatus = res['statut_verification'] ?? 'non_demande';
      _raisonRefus = res['raison_refus'];
      _statusMessage = res['message'];
      _documentsInvalides = (res['documents_invalides'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      _resubmitHint = res['resubmit_hint'];
      _documentsStatus = res['documents_status'] is Map
          ? Map<String, dynamic>.from(res['documents_status'] as Map)
          : {};
      if (_verificationStatus == 'valide') _correctionMode = false;
    });

    if (_verificationStatus == 'valide') {
      widget.onComplete();
    } else if (_verificationStatus == 'en_attente' || _verificationStatus == 'en_attente_admin') {
      _startStatusPolling();
    } else {
      _statusTimer?.cancel();
    }
  }

  void _startStatusPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final res = await ProService.getStatus();
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final currentStatus = res['statut_verification'] ?? 'non_demande';
      final docsStatus = res['documents_status'] is Map
          ? Map<String, dynamic>.from(res['documents_status'] as Map)
          : <String, dynamic>{};

      final statusChanged = currentStatus != _verificationStatus;
      final docsChanged = docsStatus.toString() != _documentsStatus.toString();

      if (statusChanged || docsChanged) {
        setState(() {
          _verificationStatus = currentStatus;
          _raisonRefus = res['raison_refus'];
          _statusMessage = res['message'];
          _documentsInvalides = (res['documents_invalides'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          _resubmitHint = res['resubmit_hint'];
          _documentsStatus = docsStatus;
          if (currentStatus == 'refuse') _correctionMode = false;
        });

        if (currentStatus == 'valide') {
          timer.cancel();
          widget.onComplete();
        } else if (currentStatus == 'refuse') {
          timer.cancel();
        }
      }
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF2D9B6F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _getFileName(String path) {
    return path.split('/').last.split('\\').last;
  }

  Future<void> _pickDocument(String docType, bool allowPdf, int maxSizeMb) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  "Sélectionnez le document",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1F3C)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFC9A84C)),
                title: const Text("Prendre une photo (Caméra)"),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    _processPickedFile(docType, image.path, maxSizeMb, false);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo, color: Color(0xFFC9A84C)),
                title: const Text("Choisir depuis la galerie"),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    _processPickedFile(docType, image.path, maxSizeMb, false);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFC9A84C)),
                title: const Text("Sélectionner un fichier PDF"),
                onTap: () async {
                  Navigator.pop(context);
                  if (!allowPdf) {
                    _showError("Le format PDF n'est pas autorisé pour ce document (JPEG/PNG requis).");
                    return;
                  }
                  FilePickerResult? result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf'],
                  );
                  if (result != null && result.files.single.path != null) {
                    _processPickedFile(docType, result.files.single.path!, maxSizeMb, true);
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processPickedFile(String docType, String filePath, int maxSizeMb, bool isPdf) async {
    final file = File(filePath);
    final sizeInBytes = await file.length();
    final sizeInMb = sizeInBytes / (1024 * 1024);

    if (sizeInMb > maxSizeMb) {
      _showError("Le fichier dépasse la taille maximale autorisée de $maxSizeMb Mo.");
      return;
    }

    setState(() {
      if (docType == "qid_front") _qidFrontPath = filePath;
      if (docType == "qid_back") _qidBackPath = filePath;
      if (docType == "diploma") _diplomaPath = filePath;
    });
  }

  void _removeFile(String docType) {
    setState(() {
      if (docType == "qid_front") _qidFrontPath = null;
      if (docType == "qid_back") _qidBackPath = null;
      if (docType == "diploma") _diplomaPath = null;
    });
  }

  bool get _isPartialResubmit =>
      _verificationStatus == 'refuse' && _documentsInvalides.isNotEmpty;

  String _docStatut(String key) {
    final doc = _documentsStatus[key];
    if (doc is Map) return doc['statut']?.toString() ?? 'en_cours';
    return 'en_cours';
  }

  String _docStatutLabel(String key) {
    final doc = _documentsStatus[key];
    if (doc is Map) return doc['label']?.toString() ?? '';
    return '';
  }

  bool _canReplaceDoc(String key) {
    final doc = _documentsStatus[key];
    if (doc is Map) return doc['can_replace'] == true;
    return false;
  }

  bool get _needsQid {
    if (_verificationStatus == 'non_demande') return true;
    if (_isPartialResubmit) return _documentsInvalides.contains('qid');
    if (_correctionMode) return _canReplaceDoc('qid');
    return true;
  }

  bool get _needsAttestation {
    if (_verificationStatus == 'non_demande') return true;
    if (_isPartialResubmit) return _documentsInvalides.contains('attestation');
    if (_correctionMode) return _canReplaceDoc('attestation');
    return true;
  }

  String _docLabel(String key) {
    switch (key) {
      case 'qid':
        return "Carte d'identité Qatar (QID)";
      case 'attestation':
        return 'Attestation professionnelle';
      default:
        return key;
    }
  }

Future<void> _submitDossier() async {
    final qidNum = _qidController.text.trim();

    if (_needsQid) {
      if (qidNum.isEmpty) {
        _showError("Veuillez saisir votre numéro QID.");
        return;
      }
      if (_qidFrontPath == null || _qidBackPath == null) {
        _showError("Veuillez charger le QID Recto et Verso.");
        return;
      }
    }

    if (_needsAttestation && _diplomaPath == null) {
      _showError("Veuillez charger votre attestation professionnelle.");
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final uploadRes = await ProService.uploadDocuments(
        qidNum: _needsQid ? qidNum : null,
        qidRectoPath: _needsQid ? _qidFrontPath : null,
        qidVersoPath: _needsQid ? _qidBackPath : null,
        attestationPath: _needsAttestation ? _diplomaPath : null,
      );

      if (!uploadRes['success']) {
        setState(() => _isSubmitting = false);
        _showError(uploadRes['message'] ?? 'Une erreur est survenue. Veuillez réessayer plus tard.');
        return;
      }

      final verifyRes = await ProService.verify();
      setState(() => _isSubmitting = false);

      if (!verifyRes['success']) {
        _showError(verifyRes['message'] ?? 'Une erreur est survenue. Veuillez réessayer plus tard.');
        await _checkStatus();
        return;
      }

      if (verifyRes['status'] == 'valide') {
        await _checkStatus();
        return;
      }

      final skipVeriff = verifyRes['skipVeriff'] == true;
      final useNative = verifyRes['useNativeVerification'] == true;
      final sessionId = verifyRes['sessionId'] as String?;
      final verificationUrl = verifyRes['verificationUrl'] as String?;

      if (!skipVeriff && useNative && sessionId != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NativeIdentityVerificationScreen(
              sessionId: sessionId,
            ),
          ),
        );
      } else if (!skipVeriff &&
          verificationUrl != null &&
          verificationUrl.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VeriffVerificationScreen(
              verificationUrl: verificationUrl,
            ),
          ),
        );
      }

      await _checkStatus();
      if (mounted) setState(() => _correctionMode = false);
    } catch (e) {
      debugPrint('UpgradeProScreen._submitDossier exception: $e');
      setState(() => _isSubmitting = false);
      _showError('Une erreur est survenue. Veuillez réessayer plus tard.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingStatus) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC9A84C))),
              SizedBox(height: 16),
              Text("Chargement de votre statut...", style: TextStyle(color: Color(0xFF0D1F3C), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    if (_isSubmitting) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC9A84C))),
              const SizedBox(height: 24),
              Text(
                _isPartialResubmit
                    ? "Téléversement des documents corrigés..."
                    : "Soumission de votre dossier...",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
              ),
              const SizedBox(height: 8),
              const Text(
                "Vos documents sont en cours de vérification",
                style: TextStyle(color: Color(0xFF6B7A99), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    // Route to appropriate view
    if (_verificationStatus == 'valide') {
      return _buildSuccessScreen();
    }
    if (_verificationStatus == 'refuse' || _correctionMode) {
      return _buildFormScreen();
    }
    if (_verificationStatus == 'en_attente' || _verificationStatus == 'en_attente_admin') {
      return _buildPendingScreen();
    }

    return _buildFormScreen();
  }

  // ⏳ Verification Pending Screen
  Widget _buildPendingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 56, bottom: 24, left: 20, right: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1F3C), Color(0xFF1A3560)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left, color: Colors.white, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      fixedSize: const Size(36, 36),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    "Vérification",
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Playfair Display',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hourglass animation mock
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC9A84C).withOpacity(0.2),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.hourglass_empty, color: Color(0xFFC9A84C), size: 48),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      _verificationStatus == 'en_attente_admin'
                          ? "Vérification en cours"
                          : "Suivi de vos documents",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage ?? 'Suivez l\'état de chaque document ci-dessous.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 13, height: 1.6),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildDocumentStatusCard('qid', "Carte d'identité Qatar (QID)"),
                          const Divider(height: 24, color: Color(0xFFF5F7FA)),
                          _buildDocumentStatusCard('attestation', 'Attestation professionnelle'),
                        ],
                      ),
                    ),
                    if (_canReplaceDoc('qid') || _canReplaceDoc('attestation')) ...[
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _correctionMode = true),
                        icon: const Icon(Icons.edit_document, color: Color(0xFF0D1F3C), size: 18),
                        label: Text(
                          _canReplaceDoc('qid') && _canReplaceDoc('attestation')
                              ? 'Corriger les documents'
                              : _canReplaceDoc('qid')
                                  ? 'Remplacer le QID'
                                  : 'Remplacer l\'attestation',
                          style: const TextStyle(color: Color(0xFF0D1F3C), fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: const Color(0xFF0D1F3C).withOpacity(0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _checkStatus,
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                      label: const Text("Rafraîchir le statut", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D1F3C),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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

  Widget _buildDocumentStatusCard(String docKey, String title) {
    final statut = _docStatut(docKey);
    final label = _docStatutLabel(docKey).isNotEmpty
        ? _docStatutLabel(docKey)
        : _docLabel(docKey);

    Color badgeBg;
    Color badgeText;
    Color badgeBorder;
    Widget badgeIcon;

    switch (statut) {
      case 'valide':
        badgeBg = const Color(0xFFECFDF5);
        badgeText = const Color(0xFF0B6640);
        badgeBorder = const Color(0xFF2D9B6F);
        badgeIcon = const Icon(Icons.check_circle, color: Color(0xFF2D9B6F), size: 14);
        break;
      case 'invalide':
        badgeBg = const Color(0xFFFFF5F5);
        badgeText = const Color(0xFF9B1C1C);
        badgeBorder = const Color(0xFFEF4444);
        badgeIcon = const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 14);
        break;
      case 'en_attente_admin':
        badgeBg = const Color(0xFFEFF6FF);
        badgeText = const Color(0xFF1E40AF);
        badgeBorder = const Color(0xFF3B82F6);
        badgeIcon = const Icon(Icons.admin_panel_settings, color: Color(0xFF3B82F6), size: 14);
        break;
      default:
        badgeBg = const Color(0xFFFFFBEB);
        badgeText = const Color(0xFFC9A84C);
        badgeBorder = const Color(0xFFC9A84C);
        badgeIcon = const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, valueColor: AlwaysStoppedAnimation(Color(0xFFC9A84C))),
        );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0D1F3C))),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, color: badgeText, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: badgeBorder.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              badgeIcon,
              const SizedBox(width: 6),
              Text(
                statut == 'valide'
                    ? 'Validé'
                    : statut == 'invalide'
                        ? 'Invalide'
                        : statut == 'en_attente_admin'
                            ? 'Manuel'
                            : 'En cours',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ Verification Success Screen
  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFC9A84C), Color(0xFFA8893B)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC9A84C).withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.stars, color: Colors.white, size: 70),
                      ),
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      "Félicitations ! Compte professionnel activé !",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Playfair Display',
                        color: Color(0xFF0D1F3C),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Votre profil professionnel est désormais actif. Votre badge de prestataire de confiance est visible par tous les clients.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF6B7A99), fontSize: 14, height: 1.6),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D9B6F),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text("Commencer à proposer des services", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // 📝 Main Upload Form Screen
  Widget _buildFormScreen() {
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
                    onPressed: () {
                      if (_correctionMode) {
                        setState(() => _correctionMode = false);
                      } else {
                        Navigator.pop(context);
                      }
                    },
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
                  Text(
                    _isPartialResubmit || _correctionMode
                        ? "Corriger mes documents"
                        : "Devenir Professionnel",
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Playfair Display',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isPartialResubmit
                        ? "Remplacez uniquement les documents invalides"
                        : _correctionMode
                            ? "Remplacez uniquement le document concerné"
                            : "Envoyez votre QID et votre attestation professionnelle",
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_isPartialResubmit || _correctionMode) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _statusMessage ??
                                  (_isPartialResubmit
                                      ? 'Documents invalides : ${_documentsInvalides.map(_docLabel).join(', ')}'
                                      : 'Sélectionnez un nouveau fichier pour le document à remplacer.'),
                              style: const TextStyle(
                                color: Color(0xFF9B1C1C),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                            if (_resubmitHint != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _resubmitHint!,
                                style: const TextStyle(
                                  color: Color(0xFF9B1C1C),
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (!_needsQid && _docStatut('qid') == 'valide')
                              _buildDocumentStatusCard('qid', "Carte d'identité Qatar (QID)"),
                            if (!_needsQid && _docStatut('qid') == 'valide' &&
                                (!_needsAttestation || _docStatut('attestation') == 'valide'))
                              const Divider(height: 20, color: Color(0xFFF5F7FA)),
                            if (!_needsAttestation && _docStatut('attestation') == 'valide')
                              _buildDocumentStatusCard('attestation', 'Attestation professionnelle'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

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
                              "Vos données d'identité sont chiffrées de bout en bout et conservées en toute sécurité.",
                              style: TextStyle(color: Color(0xFF0B6640), fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_needsQid) ...[
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
                          style: const TextStyle(fontSize: 15, color: Color(0xFF0D1F3C), fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: "Ex: 29037400123",
                            hintStyle: TextStyle(color: Color(0xFFA0ABBE), fontWeight: FontWeight.normal),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle("Carte d'identité Qatar (QID) — Recto / Verso (JPG/PNG) *"),
                      Row(
                        children: [
                          Expanded(
                            child: _buildUploadBox(
                              label: "QID Recto",
                              filePath: _qidFrontPath,
                              onTap: () => _pickDocument("qid_front", false, 5),
                              onRemove: () => _removeFile("qid_front"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildUploadBox(
                              label: "QID Verso",
                              filePath: _qidBackPath,
                              onTap: () => _pickDocument("qid_back", false, 5),
                              onRemove: () => _removeFile("qid_back"),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    if (_needsAttestation) ...[
                      _buildSectionTitle("Attestation professionnelle (JPG/PNG/PDF) *"),
                      _buildUploadBox(
                        label: "Uploader l'attestation (Max 10 Mo)",
                        filePath: _diplomaPath,
                        onTap: () => _pickDocument("diploma", true, 10),
                        onRemove: () => _removeFile("diploma"),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Le QR code sera scanné automatiquement. S'il est absent ou illisible, un administrateur vérifiera votre document manuellement.",
                        style: TextStyle(color: Color(0xFF6B7A99), fontSize: 11, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const SizedBox(height: 16),

                    // Submit Button
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
                        child: Text(
                          _isPartialResubmit || _correctionMode
                              ? "Resoumettre les documents corrigés"
                              : "Soumettre mon dossier",
                          style: const TextStyle(
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
    required String? filePath,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    final isUploaded = filePath != null;
    final fileName = isUploaded ? _getFileName(filePath) : null;

    return InkWell(
      onTap: isUploaded ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 105,
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
                      fileName!,
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

