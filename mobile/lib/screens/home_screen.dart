import 'package:flutter/material.dart';
import 'profile_screen.dart';
import 'create_listing_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const HomeScreen({super.key, required this.onLogout});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // Active Category filter for Home Tab
  String _selectedCategory = "tous";

  // Search filter
  final _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // List of mock services to display
  final List<Map<String, dynamic>> _mockServices = [
    {
      "id": 1,
      "title": "Plombier Express Doha",
      "category": "plomberie",
      "rating": "4.8",
      "reviews": "14",
      "price": "90 QAR/h",
      "location": "Al Sadd, Doha",
      "provider": "Ahmed Mansour",
      "emoji": "🔧",
      "isUrgent": true,
    },
    {
      "id": 2,
      "title": "Électricien Résidentiel",
      "category": "electricite",
      "rating": "4.9",
      "reviews": "28",
      "price": "100 QAR/h",
      "location": "West Bay, Doha",
      "provider": "Khalid Al-Thani",
      "emoji": "⚡",
      "isUrgent": false,
    },
    {
      "id": 3,
      "title": "Nettoyage Villa Complet",
      "category": "nettoyage",
      "rating": "4.7",
      "reviews": "9",
      "price": "350 QAR",
      "location": "The Pearl, Doha",
      "provider": "Fatima Cleaners",
      "emoji": "🧹",
      "isUrgent": true,
    },
    {
      "id": 4,
      "title": "Cours d'Arabe & Coran",
      "category": "cours",
      "rating": "5.0",
      "reviews": "19",
      "price": "120 QAR/h",
      "location": "Lusail, Doha",
      "provider": "Youssef Ibrahim",
      "emoji": "📚",
      "isUrgent": false,
    },
    {
      "id": 5,
      "title": "Peinture & Décoration",
      "category": "peinture",
      "rating": "4.6",
      "reviews": "7",
      "price": "400 QAR",
      "location": "Al Rayyan, Doha",
      "provider": "Bilal Art",
      "emoji": "🎨",
      "isUrgent": false,
    },
    {
      "id": 6,
      "title": "Livraison Rapide Colis",
      "category": "livraison",
      "rating": "4.8",
      "reviews": "42",
      "price": "30 QAR",
      "location": "Doha City",
      "provider": "Qatar Delivery",
      "emoji": "🚚",
      "isUrgent": false,
    },
  ];

  // Open Service details and Contact Dialog
  void _showServiceDetails(Map<String, dynamic> service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF6B7A99)),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Text(service["emoji"], style: const TextStyle(fontSize: 28)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service["title"],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D1F3C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Proposé par ${service["provider"]}",
                          style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(height: 1, color: const Color(0xFFE8EDF5)),
              const SizedBox(height: 16),
              // Price and Location
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailMeta(Icons.monetization_on_outlined, "Tarif", service["price"]),
                  _buildDetailMeta(Icons.location_on_outlined, "Zone", service["location"]),
                  _buildDetailMeta(Icons.star, "Note", "${service["rating"]} (${service["reviews"]})"),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                "Description du Service",
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C), fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                "Prestataire professionnel certifié disponible pour intervenir rapidement à Doha. Équipements de pointe, travail soigné et respect des délais garantis.",
                style: TextStyle(color: Color(0xFF6B7A99), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFFBEB),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFFC9A84C)),
                      ),
                    ).child(
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Appel de ${service["provider"]} simulé !"),
                              backgroundColor: const Color(0xFF2D9B6F),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.phone, color: Color(0xFFC9A84C), size: 18),
                            SizedBox(width: 8),
                            Text("Appeler", style: TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Message de contact envoyé à ${service["provider"]} !"),
                            backgroundColor: const Color(0xFF2D9B6F),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D1F3C),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text("Contacter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

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
    // Filter services list
    final filteredServices = _mockServices.where((s) {
      final matchesCat = _selectedCategory == "tous" || s["category"] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          s["title"].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s["provider"].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
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

        // Horizonal Category pickers
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
              ],
            ),
          ),
        ),

        // Services list
        Expanded(
          child: filteredServices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, size: 48, color: Color(0xFFA0ABBE)),
                      const SizedBox(height: 12),
                      const Text(
                        "Aucun service correspondant",
                        style: TextStyle(color: Color(0xFF6B7A99), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 24),
                  itemCount: filteredServices.length,
                  itemBuilder: (context, index) {
                    final s = filteredServices[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      color: Colors.white,
                      surfaceTintColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: InkWell(
                        onTap: () => _showServiceDetails(s),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F7FA),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(s["emoji"], style: const TextStyle(fontSize: 22)),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                s["title"],
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0D1F3C),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (s["isUrgent"]) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEE2E2),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  "URGENT",
                                                  style: TextStyle(
                                                    color: Color(0xFFEF4444),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 8,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          s["provider"],
                                          style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 12),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Color(0xFFC9A84C), size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${s["rating"]} (${s["reviews"]} avis)",
                                              style: const TextStyle(
                                                color: Color(0xFF0D1F3C),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            const Icon(Icons.location_on_outlined, color: Color(0xFFA0ABBE), size: 14),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                s["location"],
                                                style: const TextStyle(
                                                  color: Color(0xFF6B7A99),
                                                  fontSize: 11,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
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
                                  Text(
                                    s["price"],
                                    style: const TextStyle(
                                      color: Color(0xFFC9A84C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Text(
                                    "Consulter →",
                                    style: TextStyle(
                                      color: Color(0xFF0D1F3C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
        onSelected: (val) {
          setState(() {
            _selectedCategory = id;
          });
        },
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
