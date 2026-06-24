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

  // Filtre onglet : "mine" ou "others"
  String _selectedFilter = 'mine';
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

  String _normalizePricingType(Map<String, dynamic> a) {
    final type = a['type_paiement']?.toString() ?? '';
    if (['hourly', 'fixed', 'quote'].contains(type)) return type;
    return a['prix'] == null ? 'quote' : 'fixed';
  }

  String _formatPrixLabel(Map<String, dynamic> a) {
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

    final detailRes = await AnnonceService.getDetail(annonceId);
    if (detailRes.success && detailRes.data != null) {
      final det = detailRes.data as Map<String, dynamic>;
      existingPhotos = List<Map<String, dynamic>>.from(det['photos'] ?? []);
      selectedPricingType = _normalizePricingType(det);
      urgent = _isUrgentActive(det);
      if (det['prix'] != null) {
        prixCtrl.text = det['prix'].toString();
      }
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Modifier l\'offre',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C))),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Color(0xFF6B7A99))),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Photos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D1F3C))),
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
                            border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.5), width: 2),
                          ),
                          child: const Icon(Icons.add_a_photo_outlined, color: Color(0xFFC9A84C), size: 22),
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
                              child: Image.network(p['url'], width: 72, height: 72, fit: BoxFit.cover),
                            ),
                            Positioned(
                              right: -6,
                              top: -6,
                              child: GestureDetector(
                                onTap: () async {
                                  if (photoId == 0) return;
                                  final delRes = await AnnonceService.deletePhoto(annonceId, photoId);
                                  if (!mounted) return;
                                  if (delRes.success) {
                                    setSheet(() => existingPhotos.removeWhere((e) => e['id'] == p['id']));
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                                  child: const Icon(Icons.close, color: Colors.white, size: 12),
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
                _editField('Titre', titreCtrl),
                const SizedBox(height: 10),
                _editField('Description', descCtrl, maxLines: 3),
                const SizedBox(height: 10),
                const Text('Type de tarification',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0D1F3C))),
                const SizedBox(height: 6),
                Row(
                  children: pricingTypes.map((pt) {
                    final isSelected = selectedPricingType == pt.id;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: pt.id != 'quote' ? 6.0 : 0.0),
                        child: InkWell(
                          onTap: () => setSheet(() => selectedPricingType = pt.id),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFFFFBEB) : const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFC9A84C) : const Color(0xFFE8EDF5),
                              ),
                            ),
                            child: Text(pt.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? const Color(0xFFC9A84C) : const Color(0xFF6B7A99),
                                )),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (selectedPricingType != 'quote') ...[
                  const SizedBox(height: 10),
                  _editField('Prix (QAR)', prixCtrl, keyboardType: TextInputType.number),
                ],
                const SizedBox(height: 10),
                _editField('Ville', villeCtrl),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Annonce urgente',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C), fontSize: 13)),
                          Text('Mise en avant 3 jours',
                              style: TextStyle(color: Color(0xFF6B7A99), fontSize: 11)),
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
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    setSheet(() => saving = true);
                    final fields = <String, dynamic>{
                      if (titreCtrl.text.trim().isNotEmpty) 'titre': titreCtrl.text.trim(),
                      if (descCtrl.text.trim().isNotEmpty) 'description': descCtrl.text.trim(),
                      'type_paiement': selectedPricingType,
                      'urgent': urgent,
                      if (villeCtrl.text.trim().isNotEmpty) 'ville': villeCtrl.text.trim(),
                    };
                    if (selectedPricingType != 'quote') {
                      fields['prix'] = double.tryParse(prixCtrl.text);
                    }
                    final res = await AnnonceService.updateAnnonce(annonceId, fields);
                    setSheet(() => saving = false);
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    if (res.success) {
                      _loadFeed(reset: true);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Offre modifiée avec succès'),
                        backgroundColor: Color(0xFF2D9B6F),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: saving
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final int annonceId = int.tryParse(annonce['id'].toString()) ?? 0;
    bool likedLocally = false;
    int likesLocally = annonce['nb_likes'] ?? 0;
    bool sendingComment = false;
    bool isOwner = fromMineTab;
    bool detailLoading = true;
    bool detailLoaded = false;
    List<Map<String, dynamic>> commentaires = [];
    List<Map<String, dynamic>> likesList = [];
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

            Future<void> sendComment() async {
              final txt = commentCtrl.text.trim();
              if (txt.isEmpty || sendingComment) return;
              if (annonceId == 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Erreur : offre introuvable.'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFFEF4444),
                ));
                return;
              }
              setSheet(() => sendingComment = true);
              try {
                final res = await AnnonceService.addCommentaire(annonceId, txt, 'commentaire');
                if (!mounted) return;
                if (res.success) {
                  commentCtrl.clear();
                  if (res.data != null) {
                    setSheet(() {
                      commentaires.insert(0, Map<String, dynamic>.from(res.data as Map));
                    });
                  }
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
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(res.message ?? 'Erreur lors de l\'envoi.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFFEF4444),
                  ));
                }
              } finally {
                if (mounted) setSheet(() => sendingComment = false);
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
                              child: Text(c['nom_user'] ?? 'Utilisateur',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C), fontSize: 13)),
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

                        _buildPhotoCarousel(
                          urls: photoUrls,
                          emoji: emoji,
                          currentIndex: photoIndex,
                          onIndexChanged: (i) => setSheet(() => photoIndex = i),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Text(titre,
                                  style: const TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C))),
                            ),
                            if (isUrgent) ...[
                              const SizedBox(width: 8),
                              _buildUrgentBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(children: [
                          CircleAvatar(radius: 12, backgroundColor: const Color(0xFFE8EDF5),
                              backgroundImage: avatarUser != null ? NetworkImage(avatarUser) : null,
                              child: avatarUser == null ? const Icon(Icons.person, size: 14, color: Color(0xFF6B7A99)) : null),
                          const SizedBox(width: 8),
                          Text('Par $nomUser', style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 13)),
                          if (ville.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFFA0ABBE)),
                            Text(ville, style: const TextStyle(color: Color(0xFFA0ABBE), fontSize: 12)),
                          ],
                        ]),
                        const SizedBox(height: 16),
                        Container(height: 1, color: const Color(0xFFE8EDF5)),
                        const SizedBox(height: 14),

                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFC9A84C).withOpacity(0.4)),
                            ),
                            child: Row(children: [
                              const Icon(Icons.monetization_on_outlined, size: 16, color: Color(0xFFC9A84C)),
                              const SizedBox(width: 6),
                              Text(prixLabel,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC9A84C), fontSize: 15)),
                            ]),
                          ),
                          const Spacer(),
                          Row(children: [
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: likedLocally ? const Color(0xFFFFEEEE) : const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(likedLocally ? Icons.favorite : Icons.favorite_border,
                                    size: 18,
                                    color: likedLocally ? const Color(0xFFEF4444) : const Color(0xFFA0ABBE)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: likesLocally > 0 ? () => _showLikesList(likesList) : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F7FA),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('$likesLocally',
                                    style: TextStyle(
                                        color: likedLocally ? const Color(0xFFEF4444) : const Color(0xFF6B7A99),
                                        fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ]),
                        ]),
                        const SizedBox(height: 16),

                        if (description.isNotEmpty) ...[
                          const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C), fontSize: 14)),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(12)),
                            child: Text(description, style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 13, height: 1.6)),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (!showAsOwner) ...[
                          const Text('Commentaires',
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
                              child: Text('Aucun commentaire pour le moment.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 13)),
                            ))
                          else
                            ...commentaires.map((c) => buildCommentTile(c)),
                        ],

                        if (showAsOwner) ...[
                          const Text('Commentaires reçus',
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
                              child: Text('Aucun commentaire pour le moment.',
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
                                border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.08)),
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
                                    hintText: 'Écrire un commentaire...',
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
        onLogout: widget.onLogout,
        onAddService: () => setState(() => _currentIndex = 1),
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

        // ONGLETS FILTRE
        if (_isLoggedIn)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EDF5).withOpacity(0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(children: [
                Expanded(child: _buildFilterTab('mine', '📋 Mes offres')),
                Expanded(child: _buildFilterTab('others', '🌐 Offres disponibles')),
              ]),
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
    final String description = a['description'] ?? '';
    final String prixLabel = _formatPrixLabel(a);
    final int nbLikes = a['nb_likes'] ?? 0;
    final int nbCommentaires = a['nb_commentaires'] ?? 0;
    final bool isUrgent = _isUrgentActive(a);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _showOffreProposeeDetails(a, fromMineTab: true),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          if (premierePhoto != null)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(premierePhoto, height: 150, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 70, color: const Color(0xFFF5F7FA),
                          alignment: Alignment.center, child: Text(emoji, style: const TextStyle(fontSize: 36)))),
                ),
                if (isUrgent)
                  Positioned(top: 10, right: 10, child: _buildUrgentBadge()),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (premierePhoto == null)
                    Container(width: 42, height: 42,
                        decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Text(emoji, style: const TextStyle(fontSize: 22))),
                  if (premierePhoto == null) const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                        overflow: TextOverflow.ellipsis),
                    if (description.isNotEmpty)
                      Text(description, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 12, height: 1.4)),
                  ])),
                ]),
                const SizedBox(height: 10),
                Container(height: 1, color: const Color(0xFFF5F7FA)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(prixLabel, style: const TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold, fontSize: 15)),
                    Row(children: [
                      const Icon(Icons.favorite_border, size: 14, color: Color(0xFFA0ABBE)),
                      const SizedBox(width: 3),
                      GestureDetector(
                        onTap: nbLikes > 0
                            ? () {
                                final id = int.tryParse(a['id'].toString()) ?? 0;
                                _openLikesForAnnonce(id);
                              }
                            : null,
                        child: Text('$nbLikes',
                            style: TextStyle(
                                color: nbLikes > 0 ? const Color(0xFF0D1F3C) : const Color(0xFF6B7A99),
                                fontSize: 12,
                                fontWeight: nbLikes > 0 ? FontWeight.w600 : FontWeight.normal)),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFFA0ABBE)),
                      const SizedBox(width: 3),
                      Text('$nbCommentaires', style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 12)),
                    ]),
                  ],
                ),
                const SizedBox(height: 12),
                // Boutons actions CRUD
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

  // ── CARTE "OFFRES PROPOSÉES" (avec Like + Tap pour détails) ─
  Widget _buildProposedOfferCard(Map<String, dynamic> a) {
    final String titre = a['titre'] ?? '';
    final String nomUser = a['nom_user'] ?? 'Inconnu';
    final String? avatarUser = a['avatar_user'];
    final String? premierePhoto = a['premiere_photo'];
    final String emoji = _categoryEmoji(a['categorie']);
    final String description = a['description'] ?? '';
    final String ville = a['ville'] ?? '';
    final String prixLabel = _formatPrixLabel(a);
    final int nbLikes = a['nb_likes'] ?? 0;
    final bool isUrgent = _isUrgentActive(a);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => _showOffreProposeeDetails(a, fromMineTab: false),
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (premierePhoto != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(premierePhoto, height: 150, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(height: 70, color: const Color(0xFFF5F7FA),
                            alignment: Alignment.center, child: Text(emoji, style: const TextStyle(fontSize: 36)))),
                  ),
                  if (isUrgent)
                    Positioned(top: 10, right: 10, child: _buildUrgentBadge()),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (premierePhoto == null)
                      Container(width: 42, height: 42,
                          decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: Text(emoji, style: const TextStyle(fontSize: 22))),
                    if (premierePhoto == null) const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      if (description.isNotEmpty)
                        Text(description, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 12, height: 1.4)),
                      const SizedBox(height: 4),
                      Row(children: [
                        CircleAvatar(radius: 9, backgroundColor: const Color(0xFFE8EDF5),
                            backgroundImage: avatarUser != null ? NetworkImage(avatarUser) : null,
                            child: avatarUser == null ? const Icon(Icons.person, size: 11, color: Color(0xFF6B7A99)) : null),
                        const SizedBox(width: 5),
                        Text(nomUser, style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 11)),
                        if (ville.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.location_on_outlined, color: Color(0xFFA0ABBE), size: 11),
                          Expanded(child: Text(ville, style: const TextStyle(color: Color(0xFFA0ABBE), fontSize: 10),
                              overflow: TextOverflow.ellipsis)),
                        ],
                      ]),
                    ])),
                  ]),
                  const SizedBox(height: 10),
                  Container(height: 1, color: const Color(0xFFF5F7FA)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(prixLabel, style: const TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold, fontSize: 15)),
                      Row(children: [
                        const Icon(Icons.favorite_border, size: 14, color: Color(0xFFA0ABBE)),
                        const SizedBox(width: 3),
                        GestureDetector(
                          onTap: nbLikes > 0
                              ? () {
                                  final id = int.tryParse(a['id'].toString()) ?? 0;
                                  _openLikesForAnnonce(id);
                                }
                              : null,
                          child: Text('$nbLikes',
                              style: TextStyle(
                                  color: nbLikes > 0 ? const Color(0xFF0D1F3C) : const Color(0xFF6B7A99),
                                  fontSize: 12,
                                  fontWeight: nbLikes > 0 ? FontWeight.w600 : FontWeight.normal)),
                        ),
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

  Widget _buildFilterTab(String id, String label) {
    final isSelected = _selectedFilter == id;
    return GestureDetector(
      onTap: () => _onFilterChanged(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0D1F3C) : const Color(0xFF6B7A99),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
