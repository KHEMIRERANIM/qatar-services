import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'profile_screen.dart';
import 'create_listing_screen.dart';
import '../services/annonce_service.dart';
import '../services/token_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey<ProfileScreenState>();

  // Filtre onglet : "mine" ou "others"
  String _selectedFilter = 'others';
  bool _isLoggedIn = false;

  // Filtre catégorie
  String _selectedCategory = 'tous';

  // Recherche locale
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Feed data
  List<Map<String, dynamic>> _annonces = [];
  bool _feedLoading = false;
  String? _feedError;
  int _currentPage = 1;
  int _totalAnnonces = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed({bool reset = false}) async {
    if (_feedLoading) return;
    final token = await TokenService.getToken();
    final loggedIn = token != null;

    setState(() {
      _isLoggedIn = loggedIn;
      // Si non connecté, forcer "others"
      if (!loggedIn && _selectedFilter == 'mine') _selectedFilter = 'others';
      _feedLoading = true;
      _feedError = null;
      if (reset) {
        _annonces = [];
        _currentPage = 1;
      }
    });

    final result = await AnnonceService.getFeed(
      page: _currentPage,
      limit: _pageSize,
      categorie: _selectedCategory == 'tous' ? null : _selectedCategory,
      filter: _selectedFilter,
    );

    if (!mounted) return;
    if (result.success) {
      final data = result.data as Map<String, dynamic>;
      final List<dynamic> newItems = data['data'] ?? [];
      setState(() {
        _feedLoading = false;
        _totalAnnonces = data['total'] ?? 0;
        if (reset) {
          _annonces = List<Map<String, dynamic>>.from(newItems);
        } else {
          _annonces.addAll(List<Map<String, dynamic>>.from(newItems));
        }
      });
    } else {
      setState(() {
        _feedLoading = false;
        _feedError = result.message;
      });
    }
  }

  void _onCategoryChanged(String cat) {
    setState(() {
      _selectedCategory = cat;
      _currentPage = 1;
    });
    _loadFeed(reset: true);
  }

  void _onFilterChanged(String f) {
    if (_selectedFilter == f) return;
    setState(() => _selectedFilter = f);
    _loadFeed(reset: true);
  }

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

  String _normalizePricingType(Map<String, dynamic> a) {
    final type = a['type_paiement']?.toString() ?? '';
    if (['hourly', 'fixed', 'quote'].contains(type)) return type;
    return a['prix'] == null ? 'quote' : 'fixed';
  }

 String _formatPrixLabel(Map<String, dynamic> a) {
     print('>>> type_publication: ${a['type_publication']}  budget_max: ${a['budget_max']}');

     final typePublication = (a['type_publication'] ?? 'offre').toString();
     if (typePublication == 'demande') {
       final budgetVal = a['budget_max'] != null ? double.tryParse(a['budget_max'].toString()) : null;
       if (budgetVal == null) return 'Budget non défini';
       return 'Budget: ${budgetVal.toStringAsFixed(0)} QAR';
     }
     final type = _normalizePricingType(a);
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
    } catch (_) {
      return true;
    }
  }

  Widget _buildPhotoCarousel({
    required List<String> urls,
    required String emoji,
    required int currentIndex,
    required ValueChanged<int> onIndexChanged,
    double height = 180,
  }) {
    if (urls.isEmpty) {
      return Container(
        height: 90,
        decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 50)),
      );
    }

    final idx = currentIndex.clamp(0, urls.length - 1);
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            urls[idx],
            height: height,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: height,
              color: const Color(0xFFF5F7FA),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 50)),
            ),
          ),
        ),
        if (urls.length > 1) ...[
          Positioned(
            left: 8,
            child: IconButton(
              onPressed: idx > 0 ? () => onIndexChanged(idx - 1) : null,
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
          ),
          Positioned(
            right: 8,
            child: IconButton(
              onPressed: idx < urls.length - 1 ? () => onIndexChanged(idx + 1) : null,
              icon: const Icon(Icons.chevron_right, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black45),
            ),
          ),
          Positioned(
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
              child: Text('${idx + 1}/${urls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildUrgentBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('URGENT',
          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showLikesList(List<Map<String, dynamic>> likes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE8EDF5), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('${likes.length} J\'aime',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            if (likes.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Aucun like pour le moment.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 13)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: likes.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF5F7FA)),
                  itemBuilder: (_, i) {
                    final l = likes[i];
                    final avatar = l['avatar_user'];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFFE8EDF5),
                        backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                        child: avatar == null
                            ? const Icon(Icons.person, size: 18, color: Color(0xFF6B7A99))
                            : null,
                      ),
                      title: Text(l['nom_user'] ?? 'Utilisateur',
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0D1F3C), fontSize: 14)),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLikesForAnnonce(int annonceId) async {
    if (annonceId == 0) return;
    final res = await AnnonceService.getDetail(annonceId);
    if (!mounted) return;
    if (res.success && res.data != null) {
      final likes = List<Map<String, dynamic>>.from(
          (res.data as Map<String, dynamic>)['likes'] ?? []);
      _showLikesList(likes);
    }
  }

  // ─────────────────── DELETE ────────────────────────────────
  Future<void> _deleteAnnonce(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer cette offre ?',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C))),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final res = await AnnonceService.deleteAnnonce(id);
    if (!mounted) return;
    if (res.success) {
      setState(() => _annonces.removeWhere((a) => a['id'] == id));
      if (_profileKey.currentState != null) {
        _profileKey.currentState!.loadMyAnnonces();
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Offre supprimée avec succès'),
        backgroundColor: Color(0xFF2D9B6F),
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res.message ?? 'Erreur lors de la suppression'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─────────────────── EDIT MODAL ────────────────────────────
  Future<void> _showEditModal(Map<String, dynamic> annonce) async {
    final annonceId = int.tryParse(annonce['id'].toString()) ?? 0;
    if (annonceId == 0) return;

    final titreCtrl = TextEditingController(text: annonce['titre'] ?? '');
    final descCtrl = TextEditingController(text: annonce['description'] ?? '');
    final prixCtrl = TextEditingController(
        text: annonce['prix'] != null ? annonce['prix'].toString() : '');
    final villeCtrl = TextEditingController(text: annonce['ville'] ?? '');

    String selectedPricingType = _normalizePricingType(annonce);
    bool urgent = _isUrgentActive(annonce);
    List<Map<String, dynamic>> existingPhotos = [];

    // Déterminer le type de publication
    final typePublication = (annonce['type_publication'] ?? 'offre').toString();
    final isOffre = typePublication == 'offre';

    // Champs spécifiques aux demandes
    final budgetMaxCtrl = TextEditingController(
        text: annonce['budget_max'] != null ? annonce['budget_max'].toString() : '');
    final disponibiliteCtrl = TextEditingController(
        text: annonce['disponibilite'] ?? '');

    // Catégorie sélectionnée
    String? selectedCategory = annonce['categorie']?.toString();

    final detailRes = await AnnonceService.getDetail(annonceId);
    if (detailRes.success && detailRes.data != null) {
      final det = detailRes.data as Map<String, dynamic>;
      if (isOffre) {
        existingPhotos = List<Map<String, dynamic>>.from(det['photos'] ?? []);
      }
      selectedPricingType = _normalizePricingType(det);
      urgent = _isUrgentActive(det);
      if (det['prix'] != null) prixCtrl.text = det['prix'].toString();
      if (det['budget_max'] != null && budgetMaxCtrl.text.isEmpty) {
        budgetMaxCtrl.text = det['budget_max'].toString();
      }
      if (det['disponibilite'] != null && disponibiliteCtrl.text.isEmpty) {
        disponibiliteCtrl.text = det['disponibilite'].toString();
      }
      if (det['categorie'] != null) selectedCategory = det['categorie'].toString();
    }

    if (!mounted) return;

    bool saving = false;

    Future<void> pickAndUploadPhoto(void Function(void Function()) setSheet) async {
      if (existingPhotos.length >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Maximum 2 photos par annonce.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFFEF4444),
        ));
        return;
      }
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      final uploadRes = await AnnonceService.uploadPhoto(annonceId, File(picked.path));
      if (!mounted) return;
      if (uploadRes.success) {
        final refresh = await AnnonceService.getDetail(annonceId);
        if (refresh.success && refresh.data != null) {
          setSheet(() {
            existingPhotos = List<Map<String, dynamic>>.from(
                (refresh.data as Map<String, dynamic>)['photos'] ?? []);
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(uploadRes.message ?? 'Erreur upload photo'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24, right: 24, top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Titre du modal ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isOffre ? 'Modifier l\'offre' : 'Modifier la demande',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D1F3C)),
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Color(0xFF6B7A99))),
                  ],
                ),
                const SizedBox(height: 14),

                // ── Photos (Offre uniquement) ──
                if (isOffre) ...[
                  const Text('Photos',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D1F3C))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (existingPhotos.length < 2)
                        InkWell(
                          onTap: () => pickAndUploadPhoto(setSheet),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC9A84C).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: const Color(0xFFC9A84C).withOpacity(0.5),
                                  width: 2),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined,
                                color: Color(0xFFC9A84C), size: 22),
                          ),
                        ),
                      ...existingPhotos.map((p) {
                        final photoId = int.tryParse(p['id'].toString()) ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(left: 10),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(p['url'],
                                    width: 72, height: 72, fit: BoxFit.cover),
                              ),
                              Positioned(
                                right: -6,
                                top: -6,
                                child: GestureDetector(
                                  onTap: () async {
                                    if (photoId == 0) return;
                                    final delRes = await AnnonceService
                                        .deletePhoto(annonceId, photoId);
                                    if (!mounted) return;
                                    if (delRes.success) {
                                      setSheet(() => existingPhotos
                                          .removeWhere((e) => e['id'] == p['id']));
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.close,
                                        color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Titre ──
                _editField('Titre', titreCtrl),
                const SizedBox(height: 10),

                // ── Description ──
                _editField(
                  isOffre ? 'Description' : 'Description du besoin',
                  descCtrl,
                  maxLines: 3,
                ),
                const SizedBox(height: 10),

                // ── Catégorie ──
                const Text('Catégorie',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0D1F3C))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF0D1F3C).withValues(alpha: 0.08)),
                  ),
                  child: DropdownButton<String>(
                    value: categories.any((c) => c.id == selectedCategory)
                        ? selectedCategory
                        : null,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    hint: const Text('Choisir une catégorie',
                        style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 14)),
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.emoji} ${c.label}',
                                  style: const TextStyle(fontSize: 14)),
                            ))
                        .toList(),
                    onChanged: (v) => setSheet(() => selectedCategory = v),
                  ),
                ),
                const SizedBox(height: 10),

                // ── Type de tarification (Offre uniquement) ──
                if (isOffre) ...[
                  const Text('Type de tarification',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D1F3C))),
                  const SizedBox(height: 6),
                  Row(
                    children: pricingTypes.map((pt) {
                      final isSelected = selectedPricingType == pt.id;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: pt.id != 'quote' ? 6.0 : 0.0),
                          child: InkWell(
                            onTap: () =>
                                setSheet(() => selectedPricingType = pt.id),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFFBEB)
                                    : const Color(0xFFF5F7FA),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFC9A84C)
                                      : const Color(0xFFE8EDF5),
                                ),
                              ),
                              child: Text(pt.label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? const Color(0xFFC9A84C)
                                        : const Color(0xFF6B7A99),
                                  )),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (selectedPricingType != 'quote') ...[
                    const SizedBox(height: 10),
                    _editField('Prix (QAR)', prixCtrl,
                        keyboardType: TextInputType.number),
                  ],
                  const SizedBox(height: 10),
                ],

                // ── Budget maximum (Demande uniquement) ──
                if (!isOffre) ...[
                  _editField('Budget maximum (QAR)', budgetMaxCtrl,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                ],

                // ── Disponibilité souhaitée (Demande uniquement) ──
                if (!isOffre) ...[
                  _editField('Disponibilité souhaitée', disponibiliteCtrl),
                  const SizedBox(height: 10),
                ],

                // ── Zone / Ville ──
                _editField(
                    isOffre ? 'Zone d\'intervention' : 'Zone souhaitée',
                    villeCtrl),
                const SizedBox(height: 12),

                // ── Urgent ──
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOffre ? 'Annonce urgente' : 'Demande urgente',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D1F3C),
                                fontSize: 13),
                          ),
                          const Text('Mise en avant 3 jours',
                              style: TextStyle(
                                  color: Color(0xFF6B7A99), fontSize: 11)),
                        ],
                      ),
                      Switch(
                        value: urgent,
                        activeColor: const Color(0xFFC9A84C),
                        onChanged: (v) => setSheet(() => urgent = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Bouton Enregistrer ──
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setSheet(() => saving = true);
                          final fields = <String, dynamic>{
                            if (titreCtrl.text.trim().isNotEmpty)
                              'titre': titreCtrl.text.trim(),
                            if (descCtrl.text.trim().isNotEmpty)
                              'description': descCtrl.text.trim(),
                            'urgent': urgent,
                            if (villeCtrl.text.trim().isNotEmpty)
                              'ville': villeCtrl.text.trim(),
                            if (selectedCategory != null)
                              'categorie': selectedCategory,
                          };
                          if (isOffre) {
                            fields['type_paiement'] = selectedPricingType;
                            if (selectedPricingType != 'quote') {
                              fields['prix'] =
                                  double.tryParse(prixCtrl.text);
                            }
                          } else {
                            if (budgetMaxCtrl.text.trim().isNotEmpty) {
                              fields['budget_max'] =
                                  double.tryParse(budgetMaxCtrl.text);
                            }
                            if (disponibiliteCtrl.text.trim().isNotEmpty) {
                              fields['disponibilite'] =
                                  disponibiliteCtrl.text.trim();
                            }
                          }
                          final res = await AnnonceService.updateAnnonce(
                              annonceId, fields);
                          setSheet(() => saving = false);
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          if (res.success) {
                            _loadFeed(reset: true);
                            if (_profileKey.currentState != null) {
                              _profileKey.currentState!.loadMyAnnonces();
                            }
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(isOffre
                                  ? 'Offre modifiée avec succès'
                                  : 'Demande modifiée avec succès'),
                              backgroundColor: const Color(0xFF2D9B6F),
                              behavior: SnackBarBehavior.floating,
                            ));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(res.message ?? 'Erreur'),
                              backgroundColor: const Color(0xFFEF4444),
                              behavior: SnackBarBehavior.floating,
                            ));
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D1F3C),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _editField(String label, TextEditingController ctrl,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D1F3C))),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.08)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          ),
        ),
      ],
    );
  }

  // ─────────────────── DETAIL OFFRE ───────────────────────────
  void _showOffreProposeeDetails(Map<String, dynamic> annonce, {required bool fromMineTab}) {
    final commentCtrl = TextEditingController();
    final reviewCtrl = TextEditingController();
    final replyCtrl = TextEditingController();
    final int annonceId = int.tryParse(annonce['id'].toString()) ?? 0;
    bool likedLocally = false;
    int likesLocally = annonce['nb_likes'] ?? 0;
    bool sendingComment = false;
    bool sendingReview = false;
    bool sendingReply = false;
    bool isOwner = fromMineTab;
    bool detailLoading = true;
    bool detailLoaded = false;
    List<Map<String, dynamic>> commentaires = [];
    List<Map<String, dynamic>> avis = [];
    List<Map<String, dynamic>> reponses = [];
    List<Map<String, dynamic>> likesList = [];
    int selectedRating = 5;
    int? activeReplyToId;

    List<String> photoUrls = annonce['premiere_photo'] != null
        ? [annonce['premiere_photo'].toString()]
        : <String>[];
    int photoIndex = 0;
    Map<String, dynamic> displayData = Map<String, dynamic>.from(annonce);

    void loadDetail(void Function(void Function()) setSheet) {
      if (detailLoaded || annonceId == 0) return;
      detailLoaded = true;
      AnnonceService.getDetail(annonceId).then((res) {
        if (!mounted) return;
        if (res.success && res.data != null) {
          setSheet(() {
            final det = res.data as Map<String, dynamic>;
            displayData = {...displayData, ...det};
            likedLocally = det['is_liked'] == true;
            isOwner = fromMineTab || det['is_owner'] == true;
            likesLocally = det['likes_count'] ?? likesLocally;
            commentaires = List<Map<String, dynamic>>.from(det['commentaires'] ?? []);
            avis = List<Map<String, dynamic>>.from(det['avis'] ?? []);
            reponses = List<Map<String, dynamic>>.from(det['reponses'] ?? []);
            likesList = List<Map<String, dynamic>>.from(det['likes'] ?? []);
            final photos = List<Map<String, dynamic>>.from(det['photos'] ?? []);
            if (photos.isNotEmpty) {
              photoUrls = photos.map((p) => p['url'].toString()).toList();
            }
            detailLoading = false;
          });
        } else {
          setSheet(() => detailLoading = false);
        }
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom),
        child: StatefulBuilder(
          builder: (sheetCtx, setSheet) {
            loadDetail(setSheet);

            final String titre = displayData['titre'] ?? '';
            final String nomUser = displayData['nom_user'] ?? 'Inconnu';
            final String? telUser = displayData['tel_user'];
            final String? avatarUser = displayData['avatar_user'];
            final String description = displayData['description'] ?? '';
            final String ville = displayData['ville'] ?? '';
            final String emoji = _categoryEmoji(displayData['categorie']);
            final String prixLabel = _formatPrixLabel(displayData);
            final bool showAsOwner = fromMineTab || isOwner;
            final bool canComment = _isLoggedIn && !showAsOwner;
            final bool isUrgent = _isUrgentActive(displayData);
            final bool isOffre = (displayData['type_publication'] ?? 'offre').toString() == 'offre';

            Future<void> sendComment() async {
              final txt = commentCtrl.text.trim();
              if (txt.isEmpty || sendingComment) return;
              if (annonceId == 0) return;
              setSheet(() => sendingComment = true);
              try {
                final res = await AnnonceService.addCommentaire(annonceId, txt, 'commentaire');
                if (!mounted) return;
                if (res.success) {
                  commentCtrl.clear();
                  final detailRes = await AnnonceService.getDetail(annonceId);
                  if (detailRes.success && detailRes.data != null && mounted) {
                    setSheet(() {
                      commentaires = List<Map<String, dynamic>>.from(
                          (detailRes.data as Map<String, dynamic>)['commentaires'] ?? []);
                    });
                  }
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Commentaire envoyé.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Color(0xFF2D9B6F),
                  ));
                }
              } finally {
                if (mounted) setSheet(() => sendingComment = false);
              }
            }

            Future<void> sendReview() async {
              final txt = reviewCtrl.text.trim();
              if (txt.isEmpty || sendingReview) return;
              setSheet(() => sendingReview = true);
              try {
                final res = await AnnonceService.addCommentaire(
                  annonceId,
                  txt,
                  'avis',
                  note: selectedRating
                );
                if (res.success) {
                  reviewCtrl.clear();
                  final detailRes = await AnnonceService.getDetail(annonceId);
                  if (detailRes.success && detailRes.data != null && mounted) {
                    setSheet(() {
                      avis = List<Map<String, dynamic>>.from(
                          (detailRes.data as Map<String, dynamic>)['avis'] ?? []);
                    });
                  }
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Avis envoyé avec succès.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Color(0xFF2D9B6F),
                  ));
                }
              } finally {
                setSheet(() => sendingReview = false);
              }
            }
Future<void> sendReply(int parentId) async {
  final txt = replyCtrl.text.trim();
  if (txt.isEmpty || sendingReply) return;
  setSheet(() => sendingReply = true);
  try {
    final res = await AnnonceService.addCommentaire(
      annonceId,
      txt,
      'reponse',
      parentId: parentId
    );
    if (res.success) {
      replyCtrl.clear();
      setSheet(() => activeReplyToId = null);
      final detailRes = await AnnonceService.getDetail(annonceId);
      if (detailRes.success && detailRes.data != null && mounted) {
        setSheet(() {
          reponses = List<Map<String, dynamic>>.from(
              (detailRes.data as Map<String, dynamic>)['reponses'] ?? []);
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Réponse envoyée.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF2D9B6F),
      ));
    } else {
      print('ECHEC REPONSE: ${res.message}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('ECHEC: ${res.message ?? "raison inconnue"}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  } catch (e) {
    print('EXCEPTION REPONSE: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('EXCEPTION: $e'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFEF4444),
      ));
    }
  } finally {
    if (mounted) setSheet(() => sendingReply = false);
  }
}

            Widget buildStars(int count, {double size = 16, bool clickable = false}) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final filled = index < count;
                  return GestureDetector(
                    onTap: clickable ? () => setSheet(() => selectedRating = index + 1) : null,
                    child: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: const Color(0xFFC9A84C),
                      size: size,
                    ),
                  );
                }),
              );
            }

            String formatCommentDate(dynamic raw) {
              if (raw == null) return '';
              try {
                final dt = DateTime.parse(raw.toString()).toLocal();
                final now = DateTime.now();
                final diff = now.difference(dt);
                if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
                if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
                if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
                return '${dt.day}/${dt.month}/${dt.year}';
              } catch (_) {
                return '';
              }
            }

            Widget buildCommentTile(Map<String, dynamic> c, {bool showContact = false}) {
              final avatar = c['avatar_user'];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFE8EDF5),
                      backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                      child: avatar == null
                          ? const Icon(Icons.person, size: 16, color: Color(0xFF6B7A99))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(c['nom_user'] ?? 'Utilisateur',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C), fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Text(formatCommentDate(c['created_at']),
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF9AAAC0))),
                                ],
                              ),
                            ),
                            if (showContact)
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(sheetCtx);
                                  _showContactOptions(c['nom_user'] ?? 'Utilisateur', c['tel_user']);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8EDF5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.chat_bubble_outline, size: 12, color: Color(0xFF0D1F3C)),
                                      SizedBox(width: 4),
                                      Text('Contacter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C))),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(c['contenu'] ?? '', style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 13, height: 1.5)),
                      ]),
                    ),
                  ],
                ),
              );
            }

            Widget buildAvisTile(Map<String, dynamic> a) {
              final avatar = a['avatar_user'];
              final int rating = a['note'] ?? 5;
              final int reviewId = a['id'];
              final userReponses = reponses.where((r) => r['parent_id'] == reviewId).toList();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8EDF5))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFE8EDF5),
                          backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                          child: avatar == null
                              ? const Icon(Icons.person, size: 14, color: Color(0xFF6B7A99))
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(a['nom_user'] ?? 'Anonyme',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0D1F3C))),
                                  const SizedBox(width: 8),
                                  Text(formatCommentDate(a['created_at']),
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF9AAAC0))),
                                ],
                              ),
                              const SizedBox(height: 2),
                              buildStars(rating, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(a['contenu'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF6B7A99))),

                    // Réponses existantes
                    if (userReponses.isNotEmpty)
                      ...userReponses.map((rep) {
                        final repAvatar = rep['avatar_user'];
                        final repName = rep['nom_user'] ?? nomUser;
                        return Container(
                          margin: const EdgeInsets.only(top: 8, left: 16),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.subdirectory_arrow_right, size: 14, color: Color(0xFFC9A84C)),
                              const SizedBox(width: 6),
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: const Color(0xFFE8EDF5),
                                backgroundImage: repAvatar != null ? NetworkImage(repAvatar) : null,
                                child: repAvatar == null
                                    ? const Icon(Icons.person, size: 11, color: Color(0xFF6B7A99))
                                    : null,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(repName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0D1F3C))),
                                        const SizedBox(width: 6),
                                        Text(formatCommentDate(rep['created_at']),
                                            style: const TextStyle(fontSize: 9, color: Color(0xFF9AAAC0))),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(rep['contenu'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A99))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    // Formulaire de réponse pour l'owner si pas encore de réponse
                    if (showAsOwner && userReponses.isEmpty) ...[
                      const SizedBox(height: 8),
                      if (activeReplyToId == reviewId) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.08)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: TextField(
                            controller: replyCtrl,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0D1F3C)),
                            decoration: const InputDecoration(
                              hintText: 'Écrire une réponse...',
                              hintStyle: TextStyle(color: Color(0xFFA0ABBE)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => sendReply(reviewId),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF0D1F3C),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.send, size: 16),
                      ),
                    ],
                  ),
                      ] else ...[
                        TextButton.icon(
                          onPressed: () => setSheet(() => activeReplyToId = reviewId),
                          icon: const Icon(Icons.reply, size: 14, color: Color(0xFFC9A84C)),
                          label: const Text('Répondre', style: TextStyle(fontSize: 12, color: Color(0xFFC9A84C))),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                        ),
                      ],
                    ],
                  ],
                ),
              );
            }

            return SizedBox(
              height: MediaQuery.of(sheetCtx).size.height * 0.85,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      children: [
                        Center(child: Container(width: 40, height: 4,
                            decoration: BoxDecoration(color: const Color(0xFFE8EDF5), borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 16),

                        // ── HEADER UTILISATEUR (Style Réseau Social) ──
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFFE8EDF5),
                              backgroundImage: avatarUser != null ? NetworkImage(avatarUser) : null,
                              child: avatarUser == null ? const Icon(Icons.person, size: 22, color: Color(0xFF6B7A99)) : null
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nomUser,
                                    style: const TextStyle(
                                      color: Color(0xFF0D1F3C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16
                                    )
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      if (ville.isNotEmpty) ...[
                                        const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFA0ABBE)),
                                        const SizedBox(width: 2),
                                        Text(ville, style: const TextStyle(color: Color(0xFFA0ABBE), fontSize: 13)),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isUrgent) ...[
                              _buildUrgentBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ── CAROUSEL DE PHOTOS ──
                        _buildPhotoCarousel(
                          urls: photoUrls,
                          emoji: emoji,
                          currentIndex: photoIndex,
                          onIndexChanged: (i) => setSheet(() => photoIndex = i),
                        ),
                        const SizedBox(height: 16),

                        // ── BARRE D'ACTIONS (Prix, Likes) ──
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFC9A84C).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.monetization_on_outlined, size: 18, color: Color(0xFFC9A84C)),
                                  const SizedBox(width: 6),
                                  Text(
                                    prixLabel,
                                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFC9A84C), fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    if (!_isLoggedIn) {
                                      ScaffoldMessenger.of(sheetCtx).showSnackBar(const SnackBar(
                                        content: Text('Connectez-vous pour liker cette offre.'),
                                        behavior: SnackBarBehavior.floating,
                                      ));
                                      return;
                                    }
                                    final res = await AnnonceService.toggleLike(annonceId);
                                    if (!sheetCtx.mounted) return;
                                    if (res.success) {
                                      final detailRes = await AnnonceService.getDetail(annonceId);
                                      setSheet(() {
                                        likedLocally = res.data?['liked'] == true;
                                        if (detailRes.success && detailRes.data != null) {
                                          final det = detailRes.data as Map<String, dynamic>;
                                          likesLocally = det['likes_count'] ?? likesLocally;
                                          likesList = List<Map<String, dynamic>>.from(det['likes'] ?? []);
                                        } else {
                                          likesLocally = likedLocally ? likesLocally + 1 : likesLocally - 1;
                                        }
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: likedLocally ? const Color(0xFFFFEEEE) : const Color(0xFFF5F7FA),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      likedLocally ? Icons.favorite : Icons.favorite_border,
                                      size: 20,
                                      color: likedLocally ? const Color(0xFFEF4444) : const Color(0xFFA0ABBE)
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: likesLocally > 0 ? () => _showLikesList(likesList) : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F7FA),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '$likesLocally likes',
                                      style: TextStyle(
                                        color: likedLocally ? const Color(0xFFEF4444) : const Color(0xFF6B7A99),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14
                                      )
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── TITRE & DESCRIPTION (Style aéré, police plus grande) ──
                        Text(
                          titre,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D1F3C),
                            height: 1.3
                          )
                        ),
                        const SizedBox(height: 12),

                        if (description.isNotEmpty) ...[
                          Text(
                            description,
                            style: const TextStyle(
                              color: Color(0xFF4A5568),
                              fontSize: 15,
                              height: 1.6,
                              fontWeight: FontWeight.w400
                            )
                          ),
                          const SizedBox(height: 24),
                        ],
                        Container(height: 1, color: const Color(0xFFE8EDF5), margin: const EdgeInsets.only(bottom: 20)),

                        // ── SECTION AVIS (Public) ──
                      if (isOffre) ...[
                        const Text('Avis des clients',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C), fontSize: 14)),
                        const SizedBox(height: 10),
                        if (avis.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text('Aucun avis pour le moment.',
                                style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 13)),
                          )
                        else
                          ...avis.map((a) => buildAvisTile(a)),
                        const SizedBox(height: 16),
                      ],

                        // Formulaire d'avis (pour non-propriétaires connectés)
                      if (_isLoggedIn && !showAsOwner && isOffre) ...[
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Laisser un avis',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D1F3C))),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('Votre note: ', style: TextStyle(fontSize: 12, color: Color(0xFF6B7A99))),
                                    const SizedBox(width: 4),
buildStars(selectedRating, size: 30, clickable: true),                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text('Votre avis détaillé:', style: TextStyle(fontSize: 12, color: Color(0xFF6B7A99))),
                                const SizedBox(height: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE8EDF5)),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: reviewCtrl,
                                          style: const TextStyle(fontSize: 13),
                                          maxLines: 2,
                                          minLines: 1,
                                          decoration: const InputDecoration(
                                            hintText: 'Écrivez votre commentaire ici...',
                                            hintStyle: TextStyle(color: Color(0xFFA0ABBE)),
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.send, color: Color(0xFF0D1F3C), size: 18),
                                        onPressed: sendReview,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── MESSAGES PRIVÉS (Commentaires) ──
                        if (!showAsOwner) ...[
                          const Text('Messages privés',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C), fontSize: 14)),
                          const SizedBox(height: 10),
                          if (detailLoading)
                            const Center(child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(color: Color(0xFF0D1F3C), strokeWidth: 2),
                            ))
                          else if (commentaires.isEmpty)
                            const Center(child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Aucun message privé.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 13)),
                            ))
                          else
                            ...commentaires.map((c) => buildCommentTile(c)),
                        ],

                        if (showAsOwner) ...[
                          const Text('Messages privés reçus',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C), fontSize: 14)),
                          const SizedBox(height: 4),
                          const Text('Seul vous pouvez voir ces messages pour contacter les intéressés.',
                              style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 12)),
                          const SizedBox(height: 10),
                          if (detailLoading)
                            const Center(child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: CircularProgressIndicator(color: Color(0xFF0D1F3C), strokeWidth: 2),
                            ))
                          else if (commentaires.isEmpty)
                            const Center(child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text('Aucun message privé reçu.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 13)),
                            ))
                          else
                            ...commentaires.map((c) => buildCommentTile(c, showContact: true)),
                        ],
                      ],
                    ),
                  ),

                  if (canComment)
                    Material(
                      color: Colors.white,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Color(0xFFE8EDF5))),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF0D1F3C).withValues(alpha: 0.08)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: TextField(
                                controller: commentCtrl,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.send,
                                onSubmitted: (_) => sendComment(),
                                style: const TextStyle(fontSize: 13, color: Color(0xFF0D1F3C)),
                                decoration: const InputDecoration(
                                    hintText: 'Écrire un message privé...',
                                    hintStyle: TextStyle(color: Color(0xFFA0ABBE)),
                                    border: InputBorder.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: sendingComment ? null : sendComment,
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF0D1F3C),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF6B7A99),
                            ),
                            icon: sendingComment
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.send, size: 18),
                          ),
                        ]),
                      ),
                    )
                  else if (!_isLoggedIn && !showAsOwner)
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF5F7FA),
                        border: Border(top: BorderSide(color: Color(0xFFE8EDF5))),
                      ),
                      child: const Text(
                        'Connectez-vous pour envoyer un commentaire.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 12),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    ).whenComplete(() => commentCtrl.dispose());
  }

  // ─────────────────── CONTACT OPTIONS ───────────────────────
  void _showContactOptions(String nomUser, String? tel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Contacter $nomUser',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (tel != null && tel.isNotEmpty)
              _contactTile(Icons.phone, 'Appeler $nomUser', tel, const Color(0xFF2D9B6F), ctx),
            _contactTile(Icons.message_outlined, 'Envoyer un message', null, const Color(0xFF0D1F3C), ctx),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _contactTile(IconData icon, String label, String? value, Color color, BuildContext ctx) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(value != null ? '$label : $value' : '$label (bientôt disponible)'),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
          ));
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
        ),
      ),
    );
  }

  // ─────────────────── BUILD ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    Widget bodyWidget;
    if (_currentIndex == 1) {
      bodyWidget = CreateListingScreen(
        onBack: () => setState(() => _currentIndex = 0),
        onSuccess: () {
          setState(() => _currentIndex = 0);
          _loadFeed(reset: true);
        },
      );
    } else if (_currentIndex == 2) {
      bodyWidget = ProfileScreen(
        key: _profileKey,
        onLogout: widget.onLogout,
        onAddService: () => setState(() => _currentIndex = 1),
        onAnnonceTap: (annonce) => _showOffreProposeeDetails(annonce, fromMineTab: true),
        onEditAnnonce: (annonce) => _showEditModal(annonce),
        onDeleteAnnonce: (id) => _deleteAnnonce(id),
      );
    } else {
      bodyWidget = _buildHomeTab();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: bodyWidget,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: const Color(0xFF0D1F3C),
        unselectedItemColor: const Color(0xFFA0ABBE),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home, color: Color(0xFF0D1F3C)), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), activeIcon: Icon(Icons.add_box, color: Color(0xFF0D1F3C)), label: 'Publier'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person, color: Color(0xFF0D1F3C)), label: 'Profil'),
        ],
      ),
    );
  }

  /* ─── HOME FEED ────────────────────────────────────────────── */
  Widget _buildHomeTab() {
    final filteredAnnonces = _annonces.where((a) {
      if (_searchQuery.isEmpty) return true;
      final titre = (a['titre'] ?? '').toString().toLowerCase();
      final user = (a['nom_user'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return titre.contains(q) || user.contains(q);
    }).toList();

    return Column(
      children: [
        // HEADER GRADIENT
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 56, bottom: 20, left: 20, right: 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1F3C), Color(0xFF1A3560)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qatar Services', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      SizedBox(height: 2),
                      Text('Trouvez des professionnels à Doha', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                  Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: const Text('🇶🇦', style: TextStyle(fontSize: 20))),
                ],
              ),
              const SizedBox(height: 20),
              // Barre de recherche
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Icon(Icons.search, color: Color(0xFF6B7A99), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
                      decoration: const InputDecoration(
                          hintText: 'Rechercher une offre...', hintStyle: TextStyle(color: Color(0xFFA0ABBE)),
                          border: InputBorder.none, isDense: true),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () { setState(() { _searchController.clear(); _searchQuery = ''; }); },
                      child: const Icon(Icons.clear, color: Color(0xFF6B7A99), size: 18),
                    ),
                ]),
              ),
            ],
          ),
        ),

        // FILTRES CATÉGORIES
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryPill('tous', 'Tous 🌟'),
                _buildCategoryPill('plomberie', 'Plomberie 🔧'),
                _buildCategoryPill('electricite', 'Électricité ⚡'),
                _buildCategoryPill('nettoyage', 'Nettoyage 🧹'),
                _buildCategoryPill('cours', 'Cours 📚'),
                _buildCategoryPill('peinture', 'Peinture 🎨'),
                _buildCategoryPill('livraison', 'Livraison 🚚'),
                _buildCategoryPill('renovation', 'Rénovation 🏗️'),
                _buildCategoryPill('autre', 'Autre 📦'),
              ],
            ),
          ),
        ),

        // LISTE
        Expanded(
          child: _feedLoading && _annonces.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D1F3C)))
              : _feedError != null && _annonces.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.wifi_off, size: 48, color: Color(0xFFA0ABBE)),
                      const SizedBox(height: 12),
                      Text(_feedError!, style: const TextStyle(color: Color(0xFF6B7A99))),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _loadFeed(reset: true),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D1F3C)),
                        child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                      ),
                    ]))
                  : filteredAnnonces.isEmpty
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.inbox_outlined, size: 56, color: Color(0xFFA0ABBE)),
                          const SizedBox(height: 12),
                          Text(_selectedFilter == 'mine' ? 'Vous n\'avez pas encore d\'offre' : 'Aucune offre disponible',
                              style: const TextStyle(color: Color(0xFF6B7A99), fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          if (_selectedFilter == 'mine')
                            ElevatedButton.icon(
                              onPressed: () => setState(() => _currentIndex = 1),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D1F3C)),
                              icon: const Icon(Icons.add, color: Colors.white, size: 16),
                              label: const Text('Publier une offre', style: TextStyle(color: Colors.white)),
                            )
                          else
                            ElevatedButton(
                              onPressed: () => _loadFeed(reset: true),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D1F3C)),
                              child: const Text('Actualiser', style: TextStyle(color: Colors.white)),
                            ),
                        ]))
                      : RefreshIndicator(
                          onRefresh: () => _loadFeed(reset: true),
                          color: const Color(0xFF0D1F3C),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: filteredAnnonces.length + (_feedLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == filteredAnnonces.length) {
                                return const Center(child: Padding(padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(color: Color(0xFF0D1F3C))));
                              }
                              final a = filteredAnnonces[index];
                              return _selectedFilter == 'mine'
                                  ? _buildMyOfferCard(a)
                                  : _buildProposedOfferCard(a);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  // ── CARTE "MES OFFRES" (avec boutons Edit + Delete) ─────────
  Widget _buildMyOfferCard(Map<String, dynamic> a) {
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
    final int nbAvis = a['nb_avis'] ?? 0;
    final bool isUrgent = _isUrgentActive(a);
final String typePublication = (a['type_publication'] ?? 'offre').toString().toLowerCase();

    return GestureDetector(
      onTap: () => _showOffreProposeeDetails(a, fromMineTab: true),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: const Color(0xFF0D1F3C).withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo / placeholder ──
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image ou fond dégradé catégorie
                  if (premierePhoto != null)
                    Image.network(premierePhoto, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: catGrad, begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                          alignment: Alignment.center,
                          child: Text(emoji, style: const TextStyle(fontSize: 60)),
                        ))
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: catGrad, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 60)),
                    ),
                  // Gradient overlay bas
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Badge type haut droite
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
 color: typePublication == 'offre' ? const Color(0xFF0D1F3C) : const Color(0xFF2D9B6F),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        typePublication == 'offre' ? '📢 OFFRE' : '🔍 DEMANDE',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Bas photo : avatar + nom + bouton CRUD hint
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
                              color: const Color(0xFFE8EDF5),
                            ),
                            child: const Icon(Icons.person, size: 16, color: Color(0xFF6B7A99)),
                          ),
                          const SizedBox(width: 8),
                          const Text('Mon annonce',
                              style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
                                  shadows: [Shadow(blurRadius: 4)])),
                        ]),
                        if (isUrgent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(12)),
                            child: const Text('⚡ URGENT',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Corps ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges catégorie
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$emoji $categorie',
                          style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Titre
                  Text(titre,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                // Localisation + date
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
                  // Prix + interactions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(prixLabel,
                          style: const TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold, fontSize: 15)),
                      Row(children: [
                        GestureDetector(
                          onTap: nbLikes > 0 ? () => _openLikesForAnnonce(int.tryParse(a['id'].toString()) ?? 0) : null,
                          child: Row(children: [
                            const Text('🤍', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 3),
                            Text('$nbLikes',
                                style: TextStyle(
                                    color: nbLikes > 0 ? const Color(0xFF0D1F3C) : const Color(0xFF9AAAC0),
                                    fontSize: 12, fontWeight: nbLikes > 0 ? FontWeight.w600 : FontWeight.normal)),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Row(children: [
                          const Text('💬', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 3),
                          Text('$nbCommentaires', style: const TextStyle(color: Color(0xFF9AAAC0), fontSize: 12)),
                        ]),
                        const SizedBox(width: 12),
                        Row(children: [
const Icon(Icons.star_rounded, size: 20, color: Color(0xFFC9A84C)),
                          const SizedBox(width: 3),
                          Text('$nbAvis',
                            style: TextStyle(
                              color: nbAvis > 0 ? const Color(0xFFC9A84C) : const Color(0xFF9AAAC0),
                              fontSize: 12,
                              fontWeight: nbAvis > 0 ? FontWeight.w600 : FontWeight.normal,
                            )),
                        ]),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Boutons CRUD
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditModal(a),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D1F3C),
                          side: const BorderSide(color: Color(0xFF0D1F3C), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 15),
                        label: const Text('Modifier', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteAnnonce(a['id']),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 15),
                        label: const Text('Supprimer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

  // ── CARTE "OFFRES PROPOSÉES" (nouveau design FeedCard) ─────
  Widget _buildProposedOfferCard(Map<String, dynamic> a) {
    final String titre = a['titre'] ?? '';
    final String nomUser = a['nom_user'] ?? 'Inconnu';
    final String? avatarUser = a['avatar_user'];
    final String? telUser = a['tel_user'];
    final String? premierePhoto = a['premiere_photo'];
    final String emoji = _categoryEmoji(a['categorie']);
    final String categorie = a['categorie'] ?? '';
    final Color catColor = _categoryColor(a['categorie']);
    final List<Color> catGrad = _categoryGradient(a['categorie']);
    final String ville = a['ville'] ?? '';
    final String prixLabel = _formatPrixLabel(a);
    final int nbLikes = a['nb_likes'] ?? 0;
    final int nbCommentaires = a['nb_commentaires'] ?? 0;
    final int nbAvis = a['nb_avis'] ?? 0;
    final bool isUrgent = _isUrgentActive(a);
final String typePublication = (a['type_publication'] ?? 'offre').toString().toLowerCase();
    final String? postedAt = a['created_at']?.toString();

    String _shortDate(String? raw) {
      if (raw == null) return '';
      try {
        final dt = DateTime.parse(raw).toLocal();
        final now = DateTime.now();
        final diff = now.difference(dt);
        if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
        if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
        if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
        return '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) { return ''; }
    }

    return GestureDetector(
      onTap: () => _showOffreProposeeDetails(a, fromMineTab: false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: const Color(0xFF0D1F3C).withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo / placeholder ──
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image ou fond dégradé
                  if (premierePhoto != null)
                    Image.network(premierePhoto, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: catGrad, begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                          alignment: Alignment.center,
                          child: Text(emoji, style: const TextStyle(fontSize: 60)),
                        ))
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: catGrad, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 60)),
                    ),
                  // Gradient overlay bas
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x99000000)],
                        stops: [0.5, 1.0],
                      ),
                    ),
                  ),
                  // Badge OFFRE / DEMANDE
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: typePublication == 'offre' ? const Color(0xFF0D1F3C) : const Color(0xFF2D9B6F),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        typePublication == 'offre' ? '📢 OFFRE' : '🔍 DEMANDE',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  // Avatar + Nom + bouton Contacter
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
                              child: avatarUser != null
                                  ? Image.network(avatarUser, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 16, color: Color(0xFF6B7A99)))
                                  : const Icon(Icons.person, size: 16, color: Color(0xFF6B7A99)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(nomUser,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
                                  shadows: [Shadow(blurRadius: 4)])),
                        ]),
                        GestureDetector(
                          onTap: () {
                            _showContactOptions(nomUser, telUser);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC9A84C),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('Contacter',
                                style: TextStyle(color: Color(0xFF0D1F3C), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Corps ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badges catégorie + URGENT
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('$emoji $categorie',
                          style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.w600)),
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
                            style: TextStyle(color: Color(0xFFE65100), fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  // Titre
                  Text(titre,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  // Localisation + date
               Row(children: [
                 if (ville.isNotEmpty) ...[
                   const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF9AAAC0)),
                   const SizedBox(width: 3),
                   Text(ville, style: const TextStyle(color: Color(0xFF9AAAC0), fontSize: 12)),
                   const SizedBox(width: 12),
                 ],
                 if (postedAt != null)
                   Text(_shortDate(postedAt), style: const TextStyle(color: Color(0xFF9AAAC0), fontSize: 12)),
               ]),
                  const SizedBox(height: 10),
                  // Prix + interactions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(prixLabel,
                          style: const TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold, fontSize: 15)),
                      Row(children: [
                        GestureDetector(
                          onTap: nbLikes > 0 ? () => _openLikesForAnnonce(int.tryParse(a['id'].toString()) ?? 0) : null,
                          child: Row(children: [
                            const Text('🤍', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 3),
                            Text('$nbLikes',
                                style: TextStyle(
                                    color: nbLikes > 0 ? const Color(0xFF0D1F3C) : const Color(0xFF9AAAC0),
                                    fontSize: 12, fontWeight: nbLikes > 0 ? FontWeight.w600 : FontWeight.normal)),
                          ]),
                        ),
                        const SizedBox(width: 12),
                        Row(children: [
                          const Text('💬', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 3),
                          Text('$nbCommentaires', style: const TextStyle(color: Color(0xFF9AAAC0), fontSize: 12)),
                        ]),
                        const SizedBox(width: 12),
                        Row(children: [
const Icon(Icons.star_rounded, size: 20, color: Color(0xFFC9A84C)),                          const SizedBox(width: 3),
                          Text('$nbAvis',
                            style: TextStyle(
                              color: nbAvis > 0 ? const Color(0xFFC9A84C) : const Color(0xFF9AAAC0),
                              fontSize: 12,
                              fontWeight: nbAvis > 0 ? FontWeight.w600 : FontWeight.normal,
                            )),
                        ]),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPill(String id, String label) {
    final isSelected = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onCategoryChanged(id),
        selectedColor: const Color(0xFFFFFBEB),
        backgroundColor: Colors.white,
        disabledColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? const Color(0xFFC9A84C) : const Color(0xFF6B7A99),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: isSelected ? const Color(0xFFC9A84C) : const Color(0xFF0D1F3C).withOpacity(0.08),
              width: 1.5),
        ),
        showCheckmark: false,
      ),
    );
  }
}
