import 'package:flutter/material.dart';
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

  // Filtre catégorie
  String _selectedCategory = "tous";
  String _selectedFilter = "all"; // "all", "mine", "others"
  bool _isLoggedIn = false;

  // Recherche locale
  final _searchController = TextEditingController();
  String _searchQuery = "";

  // Données réelles du feed
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
      filter: _selectedFilter == 'all' ? null : _selectedFilter,
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

  // ─── Emoji par catégorie ────────────────────────────────────────
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

  // ─── Afficher les détails d'une annonce réelle ──────────────────
  void _showAnnonceDetails(Map<String, dynamic> annonce) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final String titre = annonce['titre'] ?? '';
        final String nomUser = annonce['nom_user'] ?? 'Inconnu';
        final String prix = annonce['prix'] != null ? '${annonce['prix']} QAR' : 'Sur devis';
        final String ville = annonce['ville'] ?? '';
        final int nbLikes = annonce['nb_likes'] ?? 0;
        final int nbCommentaires = annonce['nb_commentaires'] ?? 0;
        final String? premierePhoto = annonce['premiere_photo'];
        final String emoji = _categoryEmoji(annonce['categorie']);

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          builder: (_, controller) => SingleChildScrollView(
            controller: controller,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EDF5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Photo ou emoji
                  if (premierePhoto != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        premierePhoto,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 180,
                          color: const Color(0xFFF5F7FA),
                          alignment: Alignment.center,
                          child: Text(emoji, style: const TextStyle(fontSize: 60)),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 60)),
                    ),
                  const SizedBox(height: 16),
                  Text(titre,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                  ),
                  const SizedBox(height: 4),
                  Text('Proposé par $nomUser',
                    style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: const Color(0xFFE8EDF5)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildDetailMeta(Icons.monetization_on_outlined, 'Tarif', prix),
                      if (ville.isNotEmpty)
                        _buildDetailMeta(Icons.location_on_outlined, 'Ville', ville),
                      _buildDetailMeta(Icons.favorite_border, 'Likes', nbLikes.toString()),
                      _buildDetailMeta(Icons.chat_bubble_outline, 'Avis', nbCommentaires.toString()),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Bouton Contacter
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D1F3C), Color(0xFF1A3560)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Messagerie avec $nomUser (bientôt disponible)'),
                            backgroundColor: const Color(0xFF2D9B6F),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text('Contacter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Ancien _showServiceDetails conservé pour compatibilité (non utilisé)
  void _showServiceDetails(Map<String, dynamic> service) => _showAnnonceDetails(service);

  Widget _buildDetailMeta(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFFC9A84C), size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Color(0xFFA0ABBE), fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C), fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Current layout based on Navigation Tab index
    Widget bodyWidget;

    if (_currentIndex == 1) {
      // Create listing screen shortcut
      bodyWidget = CreateListingScreen(
        onBack: () {
          setState(() {
            _currentIndex = 0; // go back to home tab
          });
        },
        onSuccess: () {
          setState(() {
            _currentIndex = 0; // go back to home tab
          });
          _loadFeed(reset: true);
        },
      );
    } else if (_currentIndex == 2) {
      // Profile screen
      bodyWidget = ProfileScreen(
        onLogout: widget.onLogout,
        onAddService: () {
          setState(() {
            _currentIndex = 1; // redirect to Publish tab
          });
        },
      );
    } else {
      // Home tab view
      bodyWidget = _buildHomeTab();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: bodyWidget,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF0D1F3C),
        unselectedItemColor: const Color(0xFFA0ABBE),
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        backgroundColor: Colors.white,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home, color: Color(0xFF0D1F3C)),
            label: "Accueil",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            activeIcon: Icon(Icons.add_box, color: Color(0xFF0D1F3C)),
            label: "Publier",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person, color: Color(0xFF0D1F3C)),
            label: "Profil",
          ),
        ],
      ),
    );
  }

  /* ─── HOME FEED TAB VIEW ─────────────────────────────────── */
  Widget _buildHomeTab() {
    // Filtrage local par recherche textuelle sur les données déjà chargées
    final filteredAnnonces = _annonces.where((a) {
      if (_searchQuery.isEmpty) return true;
      final titre = (a['titre'] ?? '').toString().toLowerCase();
      final user = (a['nom_user'] ?? '').toString().toLowerCase();
      final ville = (a['ville'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return titre.contains(q) || user.contains(q) || ville.contains(q);
    }).toList();

    return Column(
      children: [
        // Premium Header
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Qatar Services",
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Playfair Display',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Trouvez des professionnels de confiance à Doha",
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text("🇶🇦", style: TextStyle(fontSize: 20)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Search Input Box
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF6B7A99), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        style: const TextStyle(fontSize: 14, color: Color(0xFF0D1F3C)),
                        decoration: const InputDecoration(
                          hintText: "Rechercher un plombier, cours...",
                          hintStyle: TextStyle(color: Color(0xFFA0ABBE)),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = "";
                          });
                        },
                        child: const Icon(Icons.clear, color: Color(0xFF6B7A99), size: 18),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (_isLoggedIn)
          Padding(
            padding: const EdgeInsets.only(top: 14, left: 16, right: 16),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EDF5).withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(child: _buildFilterTab("all", "Toutes")),
                  Expanded(child: _buildFilterTab("mine", "Mes offres")),
                  Expanded(child: _buildFilterTab("others", "Autres offres")),
                ],
              ),
            ),
          ),

        // Filtres catégories horizontaux
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryPill("tous", "Tous 🌟"),
                _buildCategoryPill("plomberie", "Plomberie 🔧"),
                _buildCategoryPill("electricite", "Électricité ⚡"),
                _buildCategoryPill("nettoyage", "Nettoyage 🧹"),
                _buildCategoryPill("cours", "Cours 📚"),
                _buildCategoryPill("peinture", "Peinture 🎨"),
                _buildCategoryPill("livraison", "Livraison 🚚"),
                _buildCategoryPill("renovation", "Rénovation 🏗️"),
                _buildCategoryPill("autre", "Autre 📦"),
              ],
            ),
          ),
        ),

        // Liste des annonces réelles
        Expanded(
          child: _feedLoading && _annonces.isEmpty
              // Chargement initial
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0D1F3C)))
              : _feedError != null && _annonces.isEmpty
                  // Erreur réseau
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.wifi_off, size: 48, color: Color(0xFFA0ABBE)),
                          const SizedBox(height: 12),
                          Text(_feedError!, style: const TextStyle(color: Color(0xFF6B7A99))),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadFeed(reset: true),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D1F3C)),
                            child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : filteredAnnonces.isEmpty
                      // Aucun résultat
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inbox_outlined, size: 56, color: Color(0xFFA0ABBE)),
                              const SizedBox(height: 12),
                              const Text('Aucune annonce disponible',
                                  style: TextStyle(color: Color(0xFF6B7A99), fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              const Text('Soyez le premier à publier !',
                                  style: TextStyle(color: Color(0xFFA0ABBE), fontSize: 13)),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _loadFeed(reset: true),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D1F3C)),
                                child: const Text('Actualiser', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        )
                      // Liste des annonces
                      : RefreshIndicator(
                          onRefresh: () => _loadFeed(reset: true),
                          color: const Color(0xFF0D1F3C),
                          child: ListView.builder(
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 24),
                            itemCount: filteredAnnonces.length + (_feedLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              // Indicateur de chargement en bas de liste
                              if (index == filteredAnnonces.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(color: Color(0xFF0D1F3C)),
                                  ),
                                );
                              }

                              final a = filteredAnnonces[index];
                              final String titre = a['titre'] ?? '';
                              final String nomUser = a['nom_user'] ?? 'Inconnu';
                              final String? avatarUser = a['avatar_user'];
                              final String prix = a['prix'] != null ? '${a['prix']} QAR' : 'Sur devis';
                              final String ville = a['ville'] ?? '';
                              final int nbLikes = a['nb_likes'] ?? 0;
                              final int nbCommentaires = a['nb_commentaires'] ?? 0;
                              final String? premierePhoto = a['premiere_photo'];
                              final String emoji = _categoryEmoji(a['categorie']);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 14),
                                color: Colors.white,
                                surfaceTintColor: Colors.white,
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                child: InkWell(
                                  onTap: () => _showAnnonceDetails(a),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Photo principale si disponible
                                      if (premierePhoto != null)
                                        ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                          child: Image.network(
                                            premierePhoto,
                                            height: 160,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              height: 80,
                                              color: const Color(0xFFF5F7FA),
                                              alignment: Alignment.center,
                                              child: Text(emoji, style: const TextStyle(fontSize: 40)),
                                            ),
                                          ),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Emoji catégorie (si pas de photo)
                                                if (premierePhoto == null)
                                                  Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF5F7FA),
                                                      borderRadius: BorderRadius.circular(14),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                                                  ),
                                                if (premierePhoto == null) const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(titre,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF0D1F3C),
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          // Avatar utilisateur
                                                          CircleAvatar(
                                                            radius: 10,
                                                            backgroundColor: const Color(0xFFE8EDF5),
                                                            backgroundImage: avatarUser != null
                                                                ? NetworkImage(avatarUser)
                                                                : null,
                                                            child: avatarUser == null
                                                                ? const Icon(Icons.person, size: 12, color: Color(0xFF6B7A99))
                                                                : null,
                                                          ),
                                                          const SizedBox(width: 6),
                                                          Text(nomUser,
                                                            style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 12),
                                                          ),
                                                          if (ville.isNotEmpty) ...[
                                                            const SizedBox(width: 8),
                                                            const Icon(Icons.location_on_outlined, color: Color(0xFFA0ABBE), size: 12),
                                                            const SizedBox(width: 2),
                                                            Expanded(
                                                              child: Text(ville,
                                                                style: const TextStyle(color: Color(0xFFA0ABBE), fontSize: 11),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Container(height: 1, color: const Color(0xFFF5F7FA)),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(prix,
                                                  style: const TextStyle(
                                                    color: Color(0xFFC9A84C),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.favorite_border, size: 14, color: Color(0xFFA0ABBE)),
                                                    const SizedBox(width: 4),
                                                    Text('$nbLikes', style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 12)),
                                                    const SizedBox(width: 12),
                                                    const Icon(Icons.chat_bubble_outline, size: 14, color: Color(0xFFA0ABBE)),
                                                    const SizedBox(width: 4),
                                                    Text('$nbCommentaires', style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 12)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildCategoryPill(String id, String label) {
    final isSelected = _selectedCategory == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) => _onCategoryChanged(id),
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
            width: 1.5,
          ),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildFilterTab(String id, String label) {
    final isSelected = _selectedFilter == id;
    return GestureDetector(
      onTap: () {
        if (_selectedFilter != id) {
          setState(() {
            _selectedFilter = id;
          });
          _loadFeed(reset: true);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
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

// Extension utility helper to enable style customization for ElevatedButton in the details modal sheet
extension ElevatedButtonHelper on ButtonStyle {
  Widget child(Widget childWidget) {
    return ElevatedButton(
      onPressed: () {},
      style: this,
      child: childWidget,
    );
  }
}
