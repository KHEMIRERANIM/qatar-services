import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/pro_service.dart';
import '../services/annonce_service.dart';
import '../widgets/user_avatar.dart';
import '../utils/profile_navigation.dart';
import 'veriff_verification_screen.dart';
import 'native_identity_verification_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final VoidCallback onAddService;
  final Function(Map<String, dynamic>)? onAnnonceTap;
  final Function(Map<String, dynamic>)? onEditAnnonce;
  final Function(int)? onDeleteAnnonce;

  const ProfileScreen({
    super.key,
    required this.onLogout,
    required this.onAddService,
    this.onAnnonceTap,
    this.onEditAnnonce,
    this.onDeleteAnnonce,
  });

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  bool _isVerifie = false;
  bool _isLoadingProfile = true;

  bool _badgeVerifie = false;
  bool _badgeTopPrestataire = false;
  double _topPrestataireProgression = 0.0;
  double _topPrestataireNote = 0.0;
  int _topPrestataireNbAvis = 0;
  bool _badgePro = false;

  // Profile data (populated from API)
  String _name = "";
  String _email = "";
  String _phone = "";
  String _bio = "";
  String _city = "";
  String _dateNaissance = "";
  String _rating = "0";
  int _reviewCount = 0;
  List<Map<String, dynamic>> _avisParCategorie = [];
  List<Map<String, dynamic>> _avisRecents = [];
  bool _isLoadingAvis = true;
  String _imageUrl = "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&auto=format";

  // Fallback Pro profile display data
  final String _proName = "Fatima Al-Kuwari";
  final String _proEmail = "fatima@email.com";
  final String _proPhone = "+974 5598 7654";
  final String _proBio =
      "Plombier professionnel avec 15 ans d'expérience au Qatar. Spécialisé dans les installations résidentielles et commerciales. Disponible 7j/7 pour les urgences.";
  final String _proImageUrl = "https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=200&h=200&fit=crop&auto=format";

  List<Map<String, dynamic>> _myAnnonces = [];
  bool _isLoadingAnnonces = true;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    loadMyAnnonces();
    _loadAvisStats();
    _loadProStatus();
  }

  Future<void> _loadAvisStats() async {
    final result = await AuthService.getMyAvisStats();
    if (!mounted) return;
    setState(() {
      _isLoadingAvis = false;
      if (result.success && result.data != null) {
        final data = result.data!;
        final noteGlobale = data['note_globale'];
        if (noteGlobale != null) {
          _rating = double.tryParse(noteGlobale.toString())?.toStringAsFixed(1) ?? noteGlobale.toString();
        } else {
          _rating = '0';
        }
        _reviewCount = int.tryParse(data['nb_avis_total']?.toString() ?? '0') ?? 0;
        _avisParCategorie = List<Map<String, dynamic>>.from(data['par_categorie'] ?? []);
        _avisRecents = List<Map<String, dynamic>>.from(data['avis_recents'] ?? []);
      }
    });
  }

  Future<void> _loadProStatus() async {
    final res = await ProService.getStatus();
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _badgeVerifie = res['verifie'] == true;
        _badgePro = res['pro'] == true;
        final top = res['top_prestataire'];
        if (top != null) {
          _badgeTopPrestataire = top['obtenu'] == true;
          _topPrestataireProgression = double.tryParse(top['progression']?.toString() ?? '0.0') ?? 0.0;
          _topPrestataireNote = double.tryParse(top['note']?.toString() ?? '0.0') ?? 0.0;
          _topPrestataireNbAvis = int.tryParse(top['nb_avis']?.toString() ?? '0') ?? 0;
        }
      });
    }
  }

  String get _ratingHeaderText {
    if (_reviewCount == 0) return '— (0 avis)';
    return '$_rating★ ($_reviewCount avis)';
  }

  String get _ratingStatText {
    if (_reviewCount == 0) return '—';
    return '$_rating★';
  }

  String _formatRelativeDate(dynamic raw) {
    if (raw == null) return '';
    final date = DateTime.tryParse(raw.toString());
    if (date == null) return raw.toString();
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return 'Il y a 1 jour';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    if (diff.inDays < 30) return 'Il y a ${(diff.inDays / 7).floor()} semaine${diff.inDays >= 14 ? 's' : ''}';
    if (diff.inDays < 365) return 'Il y a ${(diff.inDays / 30).floor()} mois';
    return 'Il y a ${(diff.inDays / 365).floor()} an${diff.inDays >= 730 ? 's' : ''}';
  }

  String _formatCategoryLabel(String? cat) {
    if (cat == null || cat.isEmpty) return 'Autre';
    return '${_categoryEmoji(cat)} ${cat[0].toUpperCase()}${cat.substring(1)}';
  }

  Future<void> loadMyAnnonces() async {
    print('📋 [PROFILE] Chargement de mes annonces...');
    final result = await AnnonceService.getFeed(filter: 'mine', limit: 50);
    _loadAvisStats();
    print('📋 [PROFILE] Résultat: success=${result.success}, message=${result.message}, data=${result.data}');
    if (!mounted) return;
    setState(() {
      _isLoadingAnnonces = false;
      if (result.success && result.data != null) {
        final data = result.data as Map<String, dynamic>;
        _myAnnonces = List<Map<String, dynamic>>.from(data['data'] ?? []);
        print('📋 [PROFILE] ${_myAnnonces.length} annonces chargées');
      } else {
        print('📋 [PROFILE] ERREUR: ${result.message}');
      }
    });
  }

  Future<void> _loadProfile() async {
    final result = await AuthService.getProfile();
    if (!mounted) return;
    setState(() => _isLoadingProfile = false);

    if (result.success && result.data != null) {
      final data = result.data!;
      final userData = data['user'] ?? data;
      setState(() {
        _name = '${userData['prenom'] ?? userData['firstName'] ?? ''} ${userData['nom'] ?? userData['lastName'] ?? ''}'.trim();
        _currentUserId = int.tryParse(userData['id']?.toString() ?? '');
        if (_name.isEmpty) _name = userData['name'] ?? userData['username'] ?? '';
        _email = userData['email'] ?? '';
        _phone = userData['telephone'] ?? userData['phone'] ?? '';
        _bio = userData['bio'] ?? userData['description'] ?? '';
        _city = userData['ville'] ?? userData['city'] ?? '';
        _dateNaissance = userData['date_naissance']?.toString() ?? '';
        final ratingRaw = userData['note'] ?? userData['rating'];
        if (ratingRaw != null) _rating = ratingRaw.toString();
        final avisRaw = userData['nb_avis'] ?? userData['reviewCount'];
        if (avisRaw != null) _reviewCount = int.tryParse(avisRaw.toString()) ?? 0;
        _isVerifie = userData['role'] == 'pro' || userData['isPro'] == true;
        if (userData['photo'] != null && userData['photo'].toString().isNotEmpty) {
          _imageUrl = userData['photo'];
        }
      });
    }

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
        if (_imageUrl.isEmpty && user.photoURL != null && user.photoURL!.isNotEmpty) {
          _imageUrl = user.photoURL!;
        }
      });
    }

    if (_name.isEmpty) _name = 'Utilisateur';

    if (!result.success && result.tokenExpired) {
      debugPrint('Token expired during profile load');
    }
  }

  void _editProfileInfo() {
    final nameController = TextEditingController(text: _isVerifie ? _proName : _name);
    final emailController = TextEditingController(text: _isVerifie ? _proEmail : _email);
    final phoneController = TextEditingController(text: _isVerifie ? _proPhone : _phone);
    final bioController = TextEditingController(text: _isVerifie ? _proBio : _bio);
String? selectedVille = _city.isNotEmpty ? _city : null;
final villes = ['Doha', 'Al Rayyan', 'Al Wakrah', 'Umm Salal', 'Al Khor', 'Al Daayen', 'Al Shahaniya', 'Al Shamal'];
    // Parse existing date_naissance
    int editDay = 1;
    int editMonth = 1;
    int editYear = 2000;
    if (_dateNaissance.isNotEmpty) {
      try {
        final parts = _dateNaissance.split('-');
        if (parts.length == 3) {
          editYear = int.tryParse(parts[0]) ?? 2000;
          editMonth = int.tryParse(parts[1]) ?? 1;
          editDay = int.tryParse(parts[2]) ?? 1;
        }
      } catch (_) {}
    }
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
                  const SizedBox(height: 14),
                  _buildEditField(label: 'À propos (bio)', controller: bioController, keyboardType: TextInputType.multiline, maxLines: 3),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Ville (Qatar)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D1F3C))),
                      const SizedBox(height: 6),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.08)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedVille,
                            isExpanded: true,
                            hint: const Text("Sélectionnez votre ville", style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 14)),
                            icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF6B7A99)),
                            style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
                            onChanged: (String? newValue) {
                              setSheet(() { selectedVille = newValue; });
                            },
                            items: villes.map<DropdownMenuItem<String>>((String v) {
                              return DropdownMenuItem<String>(value: v, child: Text(v));
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date de naissance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0D1F3C))),
                      const SizedBox(height: 6),
                      Builder(builder: (context) {
                        String formatDate() {
                          return '${editDay.toString().padLeft(2, '0')}/${editMonth.toString().padLeft(2, '0')}/$editYear';
                        }

                        Future<void> pickDate() async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime(editYear, editMonth, editDay),
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
                            setSheet(() {
                              editDay = picked.day;
                              editMonth = picked.month;
                              editYear = picked.year;
                            });
                          }
                        }

                        return GestureDetector(
                          onTap: pickDate,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.08)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                const Icon(Icons.cake_outlined, color: Color(0xFF6B7A99), size: 17),
                                const SizedBox(width: 12),
                                Text(
                                  formatDate(),
                                  style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
                                ),
                                const Spacer(),
                                const Icon(Icons.calendar_today_outlined, color: Color(0xFF6B7A99), size: 16),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
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
                           'bio': bioController.text.trim(),
                           'ville': selectedVille ?? '',
                           'date_naissance': '${editYear.toString().padLeft(4, '0')}-${editMonth.toString().padLeft(2, '0')}-${editDay.toString().padLeft(2, '0')}',
                         });
                            if (!mounted) return;
                            if (result.tokenExpired) { widget.onLogout(); return; }
                            Navigator.pop(context);
                            if (result.success) {
                              setState(() {
                                _name = fullName;
                                _email = emailController.text.trim();
                                _phone = phoneController.text.trim();
                                _bio = bioController.text.trim();
                                _city = selectedVille ?? '';
                                _dateNaissance = '${editYear.toString().padLeft(4, '0')}-${editMonth.toString().padLeft(2, '0')}-${editDay.toString().padLeft(2, '0')}';
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
    int maxLines = 1,
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
          height: maxLines > 1 ? 88 : 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.08)),
          ),
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: maxLines > 1 ? 10 : 0),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          ),
        ),
      ],
    );
  }

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
    setState(() { _imageUrl = pickedFile.path; });

    final result = await AuthService.uploadProfilePhoto(imageFile);
    if (!mounted) return;

    if (result.success && result.data != null) {
      final photoUrl = result.data!['photo'] ?? result.data!['url'];
      if (photoUrl != null) setState(() { _imageUrl = photoUrl; });
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

  void _upgradeToProFlow() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UpgradeProScreen(
          onComplete: () {
            setState(() { _isVerifie = true; });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Félicitations ! Vous êtes maintenant un Professionnel vérifié."),
                backgroundColor: Color(0xFF2D9B6F),
                behavior: SnackBarBehavior.floating,
              ),
            );
            _loadProStatus();
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
          child: CircularProgressIndicator(color: Color(0xFFC9A84C), strokeWidth: 2.5),
        ),
      );
    }
    return _isVerifie ? _buildProProfile() : _buildClientProfile();
  }

  // ── Shared profile header ────────────────────────────────
  Widget _buildProfileHeader({
    required String name,
    required List<Widget> infoLines,
    required Widget roleBadge,
    required String imageUrl,
    required VoidCallback onEditTap,
    required VoidCallback onCameraTap,
  }) {
    final bool isNetwork = imageUrl.startsWith('http');
    return Container(
      padding: const EdgeInsets.only(top: 56, bottom: 32, left: 20, right: 20),
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
          Row(
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.settings_outlined, color: Colors.white70, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFC9A84C), width: 2),
                      color: const Color(0xFF13294D),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: isNetwork
                          ? Image.network(imageUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white54, size: 36))
                          : Image.file(File(imageUrl), fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white54, size: 36)),
                    ),
                  ),
                  Positioned(
                    bottom: -4,
                    right: -4,
                    child: InkWell(
                      onTap: onCameraTap,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(color: Color(0xFFC9A84C), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Color(0xFF0D1F3C), size: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    ...infoLines,
                    const SizedBox(height: 6),
                    roleBadge,
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEditTap,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerInfoLine(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: const Color(0xFFC9A84C)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── UPDATED Stats bar with highlighted middle item ────────
  Widget _buildStatsBar(List<List<String>> stats, {int highlightIndex = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D1F3C).withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: List.generate(stats.length * 2 - 1, (i) {
            if (i.isOdd) return _buildStatDivider();
            final idx = i ~/ 2;
            final s = stats[idx];
            final isHighlighted = idx == highlightIndex;
            return _buildStatItem(s[0], s[1], highlighted: isHighlighted);
          }),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, Widget? trailing, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D1F3C))),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildServicesTags() {
    final categories = _myAnnonces
        .map((a) => a['categorie']?.toString())
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    return _sectionCard(
      title: "Services proposés",
      trailing: GestureDetector(
        onTap: widget.onAddService,
        child: const Icon(Icons.edit, size: 14, color: Color(0xFFC9A84C)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...categories.map((c) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1F3C).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_categoryEmoji(c)} ${c[0].toUpperCase()}${c.substring(1)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D1F3C)),
                ),
              )),
          if (categories.isEmpty)
            const Text(
              "Ajoutez un service pour qu'il apparaisse ici.",
              style: TextStyle(fontSize: 12, color: Color(0xFF9AAAC0)),
            ),
          OutlinedButton(
            onPressed: widget.onAddService,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFC9A84C)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('+ Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFC9A84C))),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgesSection() {
    return _sectionCard(
      title: "Badges",
      child: Column(
        children: [
          // ── Badge Vérifié ──
          _buildBadgeRow(
            icon: Icons.verified,
            label: 'Vérifié',
            description: 'Identité confirmée',
            activeColor: const Color(0xFF2D9B6F),
            obtained: _badgeVerifie,
            trailing: _badgeVerifie
                ? _buildObtenuPill()
                : _buildActionLink('Vérifier ›', _upgradeToProFlow),
          ),
          const Divider(height: 1, color: Color(0xFFF0F2F5)),
          // ── Badge Top prestataire ──
          _buildBadgeRow(
            icon: Icons.workspace_premium,
            label: 'Top prestataire',
            description: 'Note ≥ 4.8 et 20 avis sur 3 mois requis',
            activeColor: const Color(0xFFC9A84C),
            obtained: _badgeTopPrestataire,
            trailing: _badgeTopPrestataire
                ? _buildObtenuPill()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_topPrestataireNote.toStringAsFixed(1)}★ · ${_topPrestataireNbAvis} avis',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF6B7A99)),
                      ),
                    ],
                  ),
            progressValue: _badgeTopPrestataire ? null : _topPrestataireProgression,
          ),
          const Divider(height: 1, color: Color(0xFFF0F2F5)),
          // ── Badge Pro ──
          _buildBadgeRow(
            icon: Icons.diamond_outlined,
            label: 'Pro',
            description: 'Abonnement mensuel',
            activeColor: const Color(0xFF6366F1),
            obtained: _badgePro,
            trailing: _badgePro
                ? _buildObtenuPill()
                : _buildActionLink('Débloquer ›', _subscribePro),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeRow({
    required IconData icon,
    required String label,
    required String description,
    required Color activeColor,
    required bool obtained,
    required Widget trailing,
    double? progressValue,
  }) {
    final color = obtained ? activeColor : const Color(0xFFBCC5D3);
    final bgColor = obtained ? activeColor.withOpacity(0.1) : const Color(0xFFF0F2F5);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: obtained ? const Color(0xFF0D1F3C) : const Color(0xFF6B7A99),
                    )),
                    const SizedBox(height: 2),
                    Text(description, style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF9AAAC0),
                    )),
                  ],
                ),
              ),
              trailing,
            ],
          ),
          if (progressValue != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressValue,
                backgroundColor: const Color(0xFFE8ECF1),
                valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                minHeight: 5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildObtenuPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2D9B6F).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Obtenu',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2D9B6F),
        ),
      ),
    );
  }

  Widget _buildActionLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF3B82F6),
        ),
      ),
    );
  }

  Future<void> _subscribePro() async {
    if (!_badgeVerifie) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez être vérifié pour souscrire à l\'abonnement Pro.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final res = await ProService.subscribe();
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() { _badgePro = true; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Félicitations ! Abonnement Pro activé 🎉'),
          backgroundColor: Color(0xFF2D9B6F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Erreur lors de la souscription.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildAboutSection(String bio) {
    return _sectionCard(
      title: "À propos",
      child: Text(
        bio.isNotEmpty ? bio : "Ajoutez une description de votre activité pour rassurer vos clients.",
        style: const TextStyle(fontSize: 13, color: Color(0xFF6B7A99), height: 1.6),
      ),
    );
  }

  Widget _buildAvisParCategorieSection() {
    return _sectionCard(
      title: "Notes par catégorie",
      trailing: Text(_ratingHeaderText,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC9A84C))),
      child: _isLoadingAvis
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF0D1F3C), strokeWidth: 2)),
            )
          : _avisParCategorie.isEmpty
              ? const Text(
                  "Aucun avis pour le moment. Les notes apparaîtront ici dès que vos clients laisseront un avis sur vos offres.",
                  style: TextStyle(fontSize: 12, color: Color(0xFF9AAAC0), height: 1.4),
                )
              : Column(
                  children: _avisParCategorie.map((item) {
                    final cat = item['categorie']?.toString() ?? '';
                    final note = double.tryParse(item['note']?.toString() ?? '') ?? 0;
                    final nbAvis = int.tryParse(item['nb_avis']?.toString() ?? '0') ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _formatCategoryLabel(cat),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0D1F3C)),
                            ),
                          ),
                          const Icon(Icons.star, color: Color(0xFFC9A84C), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            note.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D1F3C)),
                          ),
                          Text(
                            ' ($nbAvis avis)',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A99)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
    );
  }

  Widget _buildReviewsSection() {
    return _sectionCard(
      title: "Avis clients",
      trailing: Text(_ratingHeaderText,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC9A84C))),
      child: _isLoadingAvis
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF0D1F3C), strokeWidth: 2)),
            )
          : _avisRecents.isEmpty
              ? const Text(
                  "Aucun avis reçu pour le moment.",
                  style: TextStyle(fontSize: 12, color: Color(0xFF9AAAC0)),
                )
              : Column(
                  children: List.generate(_avisRecents.length, (i) {
                    final r = _avisRecents[i];
                    final name = r['nom_user']?.toString() ?? 'Client';
                    final String? photoUser = r['avatar_user']?.toString();
                    final reviewerId = int.tryParse(r['user_id']?.toString() ?? '');
                    final rating = int.tryParse(r['note']?.toString() ?? '5') ?? 5;
                    final comment = r['contenu']?.toString() ?? '';
                    final date = _formatRelativeDate(r['created_at']);
                    final categorie = r['categorie']?.toString();
                    return Padding(
                      padding: EdgeInsets.only(bottom: i == _avisRecents.length - 1 ? 0 : 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          UserAvatar(
                            radius: 18,
                            imageUrl: photoUser,
                            name: name,
                            onTap: reviewerId != null
                                ? () => ProfileNavigation.open(
                                      context,
                                      userId: reviewerId,
                                      currentUserId: _currentUserId,
                                    )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0D1F3C))),
                                    ),
                                    Text(date, style: const TextStyle(fontSize: 10, color: Color(0xFF9AAAC0))),
                                  ],
                                ),
                                if (categorie != null && categorie.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(_formatCategoryLabel(categorie),
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF9AAAC0))),
                                ],
                                const SizedBox(height: 2),
                                Row(
                                  children: List.generate(
                                    5,
                                    (j) => Icon(
                                      j < rating ? Icons.star : Icons.star_border,
                                      size: 12,
                                      color: const Color(0xFFC9A84C),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(comment,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A99), height: 1.4)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
    );
  }

  /* ─── Client Profile View ────────────────────────────────── */
  Widget _buildClientProfile() {
    final displayCity = _city;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileHeader(
              name: _name,
              infoLines: [
                _headerInfoLine(Icons.location_on_outlined, displayCity),
                _headerInfoLine(Icons.star, _ratingHeaderText),
              ],
              roleBadge: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text("Client",
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              imageUrl: _imageUrl,
              onEditTap: _editProfileInfo,
              onCameraTap: _changeProfilePhoto,
            ),
            const SizedBox(height: 20),
            // ── Stats bar (client) ──
            _buildStatsBar([
              ["${_myAnnonces.length}", "Annonces"],
              [_ratingStatText, "Note"],
              ["98%", "Réponse"],
            ], highlightIndex: 1),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Devenir Vérifié — carte dorée
                  InkWell(
                    onTap: _upgradeToProFlow,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFC9A84C), Color(0xFFA8893B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC9A84C).withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.star, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("✅ Devenir Vérifié",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                SizedBox(height: 2),
                                Text("Uploadez vos documents et obtenez le badge vérifié",
                                    style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  ),

                  // ── À propos ──
                  _buildAboutSection(_bio),

                  // ── Services proposés ──
                  _buildServicesTags(),

                  // ── Badges ──
                  _buildBadgesSection(),

                  _buildAvisParCategorieSection(),

                  _buildReviewsSection(),

                  // ── Mes annonces ──
                  _sectionCard(
                    title: "Mes annonces",
                    child: _isLoadingAnnonces
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: Color(0xFF0D1F3C))),
                          )
                        : _myAnnonces.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text("Vous n'avez aucune annonce.",
                                    style: TextStyle(color: Color(0xFF9AAAC0), fontSize: 13)),
                              )
                            : Column(children: _myAnnonces.map((a) => _buildAnnonceCard(a)).toList()),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
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
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ─── Pro Profile View ───────────────────────────────────── */
  Widget _buildProProfile() {
    final displayCity = _city;
    final displayName = _name.isNotEmpty ? _name : _proName;
    final displayBio = _bio.isNotEmpty ? _bio : _proBio;
    final displayImage = _imageUrl.isNotEmpty ? _imageUrl : _proImageUrl;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProfileHeader(
              name: displayName,
              infoLines: [
                _headerInfoLine(Icons.location_on_outlined, displayCity),
                _headerInfoLine(Icons.star, _ratingHeaderText),
              ],
              roleBadge: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFC9A84C), Color(0xFFA8893B)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.white, size: 10),
                    SizedBox(width: 4),
                    Text("Professionnel vérifié",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
              imageUrl: displayImage,
              onEditTap: _editProfileInfo,
              onCameraTap: _changeProfilePhoto,
            ),
            const SizedBox(height: 20),
            _buildStatsBar([
              ["${_myAnnonces.length}", "Annonces"],
              [_ratingStatText, "Note"],
              ["98%", "Réponse"],
            ], highlightIndex: 1),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildAboutSection(displayBio),

                  // Ajouter un service
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
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
                                  Text("➕ Ajouter un service",
                                      style: TextStyle(
                                          color: Color(0xFF0D1F3C), fontWeight: FontWeight.bold, fontSize: 15)),
                                  SizedBox(height: 2),
                                  Text("Publiez une nouvelle offre",
                                      style: TextStyle(color: Color(0xFF6B7A99), fontSize: 11)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Color(0xFFC9A84C), size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),

                  _buildServicesTags(),

                  _sectionCard(
                    title: "Mes services",
                    child: _isLoadingAnnonces
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: Color(0xFF0D1F3C))),
                          )
                        : _myAnnonces.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text("Vous n'avez aucune annonce.",
                                    style: TextStyle(color: Color(0xFF9AAAC0), fontSize: 13)),
                              )
                            : Column(children: _myAnnonces.map((a) => _buildAnnonceCard(a)).toList()),
                  ),

                  _buildBadgesSection(),

                  _buildAvisParCategorieSection(),

                  _buildReviewsSection(),

                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
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

                  Center(
                    child: TextButton(
                      onPressed: () { setState(() { _isVerifie = false; }); },
                      child: const Text("← Voir profil client",
                          style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
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
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ── UPDATED _buildStatItem with highlighted support ────────
  Widget _buildStatItem(String number, String label, {bool highlighted = false}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: highlighted
            ? BoxDecoration(
                color: const Color(0xFF0D1F3C),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          children: [
            Text(
              number,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: highlighted ? Colors.white : const Color(0xFF0D1F3C),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: highlighted ? Colors.white70 : const Color(0xFF6B7A99),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 32, color: const Color(0xFFF0F2F7));
  }

  // ── Category helpers ──────────────────────────────────────
  String _categoryEmoji(String? cat) {
    switch (cat) {
      case 'plomberie': return '🔧';
      case 'electricite': return '⚡';
      case 'nettoyage': return '🧹';
      case 'cours': return '📚';
      case 'peinture': return '🎨';
      case 'livraison': return '🚚';
      case 'renovation': return '🏗️';
      default: return '📦';
    }
  }

  String _formatPrixLabel(Map<String, dynamic> a) {
    final typePublication = (a['type_publication'] ?? 'offre').toString();
    if (typePublication == 'demande') {
      final budgetVal = a['budget_max'] != null ? double.tryParse(a['budget_max'].toString()) : null;
      if (budgetVal == null) return 'Budget non défini';
      return 'Budget: ${budgetVal.toStringAsFixed(0)} QAR';
    }
    final type = a['type_paiement']?.toString() ?? '';
    if (type == 'quote') return 'Sur devis';
    final prixVal = a['prix'] != null ? double.tryParse(a['prix'].toString()) : null;
    if (prixVal == null) return 'Sur devis';
    if (type == 'hourly') return '${prixVal.toStringAsFixed(0)} QAR/heure';
    return '${prixVal.toStringAsFixed(0)} QAR';
  }

  bool _isUrgentActive(Map<String, dynamic> a) {
    if (a['urgent'] != 1 && a['urgent'] != true) return false;
    final until = a['urgent_until'];
    if (until == null) return true;
    try {
      return DateTime.parse(until.toString()).isAfter(DateTime.now());
    } catch (_) { return true; }
  }

  Color _categoryColor(String? cat) {
    switch (cat) {
      case 'plomberie': return const Color(0xFF1565C0);
      case 'electricite': return const Color(0xFFF57F17);
      case 'nettoyage': return const Color(0xFF2E7D32);
      case 'cours': return const Color(0xFF6A1B9A);
      case 'peinture': return const Color(0xFFAD1457);
      case 'livraison': return const Color(0xFF558B2F);
      case 'renovation': return const Color(0xFF00838F);
      default: return const Color(0xFF0D1F3C);
    }
  }

  List<Color> _categoryGradient(String? cat) {
    switch (cat) {
      case 'plomberie': return [const Color(0xFF1565C0), const Color(0xFF1E88E5)];
      case 'electricite': return [const Color(0xFFF57F17), const Color(0xFFFFA726)];
      case 'nettoyage': return [const Color(0xFF2E7D32), const Color(0xFF43A047)];
      case 'cours': return [const Color(0xFF6A1B9A), const Color(0xFF8E24AA)];
      case 'peinture': return [const Color(0xFFAD1457), const Color(0xFFE91E63)];
      case 'livraison': return [const Color(0xFF558B2F), const Color(0xFF7CB342)];
      case 'renovation': return [const Color(0xFF00838F), const Color(0xFF00ACC1)];
      default: return [const Color(0xFF0D1F3C), const Color(0xFF1A3560)];
    }
  }

  Widget _buildAnnonceCard(Map<String, dynamic> a) {
    final String titre = a['titre'] ?? '';
    final String? premierePhoto = a['premiere_photo'];
    final String emoji = _categoryEmoji(a['categorie']);
    final String categorie = a['categorie'] ?? '';
    final Color catColor = _categoryColor(a['categorie']);
    final List<Color> catGrad = _categoryGradient(a['categorie']);
    final String ville = a['ville'] ?? '';
    final String prixLabel = _formatPrixLabel(a);
    final int nbLikes = a['nb_likes'] ?? 0;
    final int nbCommentaires = a['nb_commentaires'] ?? 0;
    final bool isUrgent = _isUrgentActive(a);
    final String typePublication = (a['type_publication'] ?? 'OFFRE').toString().toUpperCase();

    return GestureDetector(
      onTap: () => widget.onAnnonceTap?.call(a),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF0D1F3C).withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (premierePhoto != null)
                    Image.network(premierePhoto, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: catGrad,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                          ),
                          alignment: Alignment.center,
                          child: Text(emoji, style: const TextStyle(fontSize: 60)),
                        ))
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: catGrad, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 60)),
                    ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: typePublication == 'OFFRE'
                            ? const Color(0xFF0D1F3C)
                            : const Color(0xFF2D9B6F),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        typePublication == 'OFFRE' ? '📢 OFFRE' : '🔍 DEMANDE',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12, left: 12, right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFC9A84C), width: 2),
                            ),
                            child: ClipOval(
                              child: _isVerifie
                                  ? Image.network(_proImageUrl, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.person, size: 16, color: Color(0xFF6B7A99)))
                                  : (_imageUrl.startsWith('http')
                                      ? Image.network(_imageUrl, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.person, size: 16, color: Color(0xFF6B7A99)))
                                      : Image.file(File(_imageUrl), fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.person, size: 16, color: Color(0xFF6B7A99)))),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_isVerifie ? _proName : _name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  shadows: [Shadow(blurRadius: 4)])),
                        ]),
                        if (isUrgent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Text('⚡ URGENT',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$emoji $categorie',
                          style: TextStyle(
                              color: catColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    if (isUrgent) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('⚡ URGENT',
                            style: TextStyle(
                                color: Color(0xFFE65100),
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  Text(titre,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  if (ville.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF9AAAC0)),
                        const SizedBox(width: 3),
                        Text(ville, style: const TextStyle(color: Color(0xFF9AAAC0), fontSize: 12)),
                      ],
                    ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(prixLabel,
                          style: const TextStyle(
                              color: Color(0xFFC9A84C),
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Row(children: [
                        const Text('🤍', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 3),
                        Text('$nbLikes',
                            style: const TextStyle(color: Color(0xFF9AAAC0), fontSize: 12)),
                        const SizedBox(width: 12),
                        const Text('💬', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 3),
                        Text('$nbCommentaires',
                            style: const TextStyle(color: Color(0xFF9AAAC0), fontSize: 12)),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onEditAnnonce?.call(a),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D1F3C),
                          side: const BorderSide(color: Color(0xFF0D1F3C), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('Modifier',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onDeleteAnnonce
                            ?.call(int.tryParse(a['id'].toString()) ?? 0),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 15),
                        label: const Text('Supprimer',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
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

  String? _qidFrontPath;
  String? _qidBackPath;
  String? _diplomaPath;

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
      if (!mounted) { timer.cancel(); return; }

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF2D9B6F),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _getFileName(String path) => path.split('/').last.split('\\').last;

  Future<void> _pickDocument(String docType, bool allowPdf, int maxSizeMb) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text("Sélectionnez le document",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D1F3C))),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFC9A84C)),
                title: const Text("Prendre une photo (Caméra)"),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                  if (image != null) _processPickedFile(docType, image.path, maxSizeMb, false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo, color: Color(0xFFC9A84C)),
                title: const Text("Choisir depuis la galerie"),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) _processPickedFile(docType, image.path, maxSizeMb, false);
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
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
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

  Future<void> _processPickedFile(
      String docType, String filePath, int maxSizeMb, bool isPdf) async {
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
      case 'qid': return "Carte d'identité Qatar (QID)";
      case 'attestation': return 'Attestation professionnelle';
      default: return key;
    }
  }

  Future<void> _submitDossier() async {
    final qidNum = _qidController.text.trim();
    if (_needsQid) {
      if (qidNum.isEmpty) { _showError("Veuillez saisir votre numéro QID."); return; }
      if (_qidFrontPath == null || _qidBackPath == null) {
        _showError("Veuillez charger le QID Recto et Verso."); return;
      }
    }
    if (_needsAttestation && _diplomaPath == null) {
      _showError("Veuillez charger votre attestation professionnelle."); return;
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

      if (verifyRes['status'] == 'valide') { await _checkStatus(); return; }

      final skipVeriff = verifyRes['skipVeriff'] == true;
      final useNative = verifyRes['useNativeVerification'] == true;
      final sessionId = verifyRes['sessionId'] as String?;
      final verificationUrl = verifyRes['verificationUrl'] as String?;

      if (!skipVeriff && useNative && sessionId != null) {
        await Navigator.push(context, MaterialPageRoute(
            builder: (context) => NativeIdentityVerificationScreen(sessionId: sessionId)));
      } else if (!skipVeriff && verificationUrl != null && verificationUrl.isNotEmpty) {
        await Navigator.push(context, MaterialPageRoute(
            builder: (context) => VeriffVerificationScreen(verificationUrl: verificationUrl)));
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
              CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC9A84C))),
              SizedBox(height: 16),
              Text("Chargement de votre statut...",
                  style: TextStyle(color: Color(0xFF0D1F3C), fontWeight: FontWeight.w500)),
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
              const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC9A84C))),
              const SizedBox(height: 24),
              Text(
                _isPartialResubmit
                    ? "Téléversement des documents corrigés..."
                    : "Soumission de votre dossier...",
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
              ),
              const SizedBox(height: 8),
              const Text("Vos documents sont en cours de vérification",
                  style: TextStyle(color: Color(0xFF6B7A99), fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_verificationStatus == 'valide') return _buildSuccessScreen();
    if (_verificationStatus == 'refuse' || _correctionMode) return _buildFormScreen();
    if (_verificationStatus == 'en_attente' || _verificationStatus == 'en_attente_admin') {
      return _buildPendingScreen();
    }
    return _buildFormScreen();
  }

  Widget _buildPendingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
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
                  const Text("Vérification",
                      style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Playfair Display',
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
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
                    Center(
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFC9A84C).withOpacity(0.2),
                                blurRadius: 24,
                                offset: const Offset(0, 8))
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
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _statusMessage ?? "Suivez l'état de chaque document ci-dessous.",
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
                                  : "Remplacer l'attestation",
                          style: const TextStyle(
                              color: Color(0xFF0D1F3C), fontWeight: FontWeight.bold),
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
                      label: const Text("Rafraîchir le statut",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final label = _docStatutLabel(docKey).isNotEmpty ? _docStatutLabel(docKey) : _docLabel(docKey);

    Color badgeBg, badgeText, badgeBorder;
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
          width: 12, height: 12,
          child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(Color(0xFFC9A84C))),
        );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0D1F3C))),
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

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFC9A84C), Color(0xFFA8893B)]),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFC9A84C).withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 10))
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
                    color: Color(0xFF0D1F3C)),
              ),
              const SizedBox(height: 16),
              const Text(
                "Votre profil professionnel est désormais actif. Votre badge de prestataire de confiance est visible par tous les clients.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7A99), fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D9B6F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Commencer à proposer des services",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isPartialResubmit || _correctionMode
                        ? "Corriger mes documents"
                        : "Devenir Vérifié",
                    style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Playfair Display',
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
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
                                  height: 1.5),
                            ),
                            if (_resubmitHint != null) ...[
                              const SizedBox(height: 8),
                              Text(_resubmitHint!,
                                  style: const TextStyle(
                                      color: Color(0xFF9B1C1C), fontSize: 12, height: 1.4)),
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
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)
                          ],
                        ),
                        child: Column(
                          children: [
                            if (!_needsQid && _docStatut('qid') == 'valide')
                              _buildDocumentStatusCard('qid', "Carte d'identité Qatar (QID)"),
                            if (!_needsQid &&
                                _docStatut('qid') == 'valide' &&
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
                              style: TextStyle(
                                  color: Color(0xFF0B6640), fontSize: 12, height: 1.4),
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
                          border:
                              Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.12)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _qidController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF0D1F3C),
                              fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: "Ex: 29037400123",
                            hintStyle: TextStyle(
                                color: Color(0xFFA0ABBE), fontWeight: FontWeight.normal),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionTitle(
                          "Carte d'identité Qatar (QID) — Recto / Verso (JPG/PNG) *"),
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

                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF0D1F3C), Color(0xFF1A3560)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: const Color(0xFF0D1F3C).withOpacity(0.2),
                              blurRadius: 16,
                              offset: const Offset(0, 6))
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
                              fontWeight: FontWeight.bold),
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
      child: Text(title,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C))),
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
                    child: Text(fileName!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0B6640),
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onRemove,
                    child: const Text("Supprimer",
                        style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: Color(0xFFC9A84C), size: 24),
                  const SizedBox(height: 8),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A99))),
                ],
              ),
      ),
    );
  }
}