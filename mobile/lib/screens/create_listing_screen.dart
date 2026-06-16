import 'package:flutter/material.dart';

class CreateListingScreen extends StatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onSuccess;

  const CreateListingScreen({
    super.key,
    required this.onBack,
    required this.onSuccess,
  });

  @override
  State<CreateListingScreen> createState() => _CreateListingScreenState();
}

class CategoryItem {
  final String id;
  final String label;
  final String emoji;
  const CategoryItem({required this.id, required this.label, required this.emoji});
}

const List<CategoryItem> categories = [
  CategoryItem(id: "plomberie", label: "Plomberie", emoji: "🔧"),
  CategoryItem(id: "electricite", label: "Électricité", emoji: "⚡"),
  CategoryItem(id: "cours", label: "Cours & Formation", emoji: "📚"),
  CategoryItem(id: "renovation", label: "Rénovation", emoji: "🏗️"),
  CategoryItem(id: "peinture", label: "Peinture", emoji: "🎨"),
  CategoryItem(id: "nettoyage", label: "Nettoyage", emoji: "🧹"),
  CategoryItem(id: "livraison", label: "Livraison", emoji: "🚚"),
  CategoryItem(id: "autre", label: "Autre", emoji: "📦"),
];

class PricingType {
  final String id;
  final String label;
  final String icon;
  const PricingType({required this.id, required this.label, required this.icon});
}

const List<PricingType> pricingTypes = [
  PricingType(id: "hourly", label: "Par heure", icon: "⏰"),
  PricingType(id: "fixed", label: "Prix fixe", icon: "💰"),
  PricingType(id: "quote", label: "Sur devis", icon: "📝"),
];

class _CreateListingScreenState extends State<CreateListingScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();

  String? _selectedCategory;
  String _selectedPricingType = "hourly";
  bool _urgent = false;

  bool _showCatPicker = false;
  bool _submitted = false;

  // List of uploaded mock photos
  final List<Map<String, dynamic>> _photos = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez entrer un titre pour l'annonce."),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez choisir une catégorie."),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez rédiger une description de votre service."),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _submitted = true;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        widget.onSuccess();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
              builder: (context, val, child) {
                return Transform.scale(
                  scale: val,
                  child: child,
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      color: Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.check,
                      size: 44,
                      color: Color(0xFF2D9B6F),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Annonce publiée !",
                    style: TextStyle(
                      color: Color(0xFF0D1F3C),
                      fontFamily: 'Playfair Display',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Votre annonce est maintenant visible par les clients autour de vous.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7A99),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final selectedCat = categories.firstWhere(
      (c) => c.id == _selectedCategory,
      orElse: () => const CategoryItem(id: "", label: "", emoji: ""),
    );

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
                    onPressed: widget.onBack,
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
                    "Créer une annonce",
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Playfair Display',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Proposez votre service à des milliers de clients",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Photos Section
                    _buildSectionLabel("Photos du service"),
                    Row(
                      children: [
                        // Ajouter photo button (displays if user has selected less than 3 photos)
                        if (_photos.length < 3)
                          InkWell(
                            onTap: () {
                              setState(() {
                                final emojis = ['🛠️', '🔌', '🧹', '🚚', '📦'];
                                final selectedEmoji = emojis[_photos.length % emojis.length];
                                _photos.add({
                                  'id': DateTime.now().toString(),
                                  'emoji': selectedEmoji,
                                  'label': 'Photo ${_photos.length + 1}'
                                });
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC9A84C).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFC9A84C).withOpacity(0.5),
                                  width: 2,
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_outlined, color: Color(0xFFC9A84C), size: 22),
                                  SizedBox(height: 4),
                                  Text(
                                    "Ajouter",
                                    style: TextStyle(
                                      color: Color(0xFFC9A84C),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Render uploaded photos
                        ..._photos.map((photo) {
                          return Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: const Color(0xFF0D1F3C).withOpacity(0.1)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(photo['emoji'], style: const TextStyle(fontSize: 24)),
                                      const SizedBox(height: 4),
                                      Text(
                                        photo['label'],
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF6B7A99),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: -6,
                                  top: -6,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _photos.removeWhere((item) => item['id'] == photo['id']);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),

                        // Placeholders to fill the row to 3 items
                        for (int i = 0; i < (3 - _photos.length - (_photos.length < 3 ? 1 : 0)); i++)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8EDF5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.add, color: Color(0xFFA0ABBE), size: 20),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Title
                    _buildSectionLabel("Titre de l'annonce *"),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF0D1F3C).withOpacity(0.12),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _titleController,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF0D1F3C),
                        ),
                        decoration: const InputDecoration(
                          hintText: "Ex: Plombier disponible à Doha",
                          hintStyle: TextStyle(color: Color(0xFFA0ABBE)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category
                    _buildSectionLabel("Catégorie *"),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _showCatPicker = !_showCatPicker;
                        });
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _showCatPicker
                                ? const Color(0xFFC9A84C)
                                : const Color(0xFF0D1F3C).withOpacity(0.12),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedCategory != null
                                  ? "${selectedCat.emoji} ${selectedCat.label}"
                                  : "Choisir une catégorie",
                              style: TextStyle(
                                fontSize: 15,
                                color: _selectedCategory != null
                                    ? const Color(0xFF0D1F3C)
                                    : const Color(0xFFA0ABBE),
                              ),
                            ),
                            AnimatedRotation(
                              turns: _showCatPicker ? 0.5 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Color(0xFF6B7A99),
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showCatPicker) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0D1F3C).withOpacity(0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: categories.length,
                          separatorBuilder: (context, index) => Container(
                            height: 1,
                            color: const Color(0xFFF5F7FA),
                          ),
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = _selectedCategory == cat.id;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedCategory = cat.id;
                                  _showCatPicker = false;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    Text(
                                      cat.emoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      cat.label,
                                      style: TextStyle(
                                        color: const Color(0xFF0D1F3C),
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const Spacer(),
                                      const Icon(
                                        Icons.check,
                                        color: Color(0xFFC9A84C),
                                        size: 16,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Description
                    _buildSectionLabel("Description *"),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF0D1F3C).withOpacity(0.12),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _descriptionController,
                            maxLines: 4,
                            onChanged: (val) => setState(() {}),
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF0D1F3C),
                            ),
                            decoration: const InputDecoration(
                              hintText: "Décrivez votre service en détail : expérience, équipements, délais, etc.",
                              hintStyle: TextStyle(color: Color(0xFFA0ABBE)),
                              border: InputBorder.none,
                            ),
                          ),
                          Text(
                            "${_descriptionController.text.length}/500",
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Color(0xFFA0ABBE),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pricing Type
                    _buildSectionLabel("Type de tarification"),
                    Row(
                      children: pricingTypes.map((pt) {
                        final isSelected = _selectedPricingType == pt.id;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: pt.id != "quote" ? 8.0 : 0.0,
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedPricingType = pt.id;
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFC9A84C)
                                        : const Color(0xFF0D1F3C).withOpacity(0.1),
                                    width: 2,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      pt.icon,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      pt.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? const Color(0xFFC9A84C)
                                            : const Color(0xFF6B7A99),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Price
                    if (_selectedPricingType != "quote") ...[
                      _buildSectionLabel("Prix (QAR)"),
                      Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF0D1F3C).withOpacity(0.12),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Text(
                              "QAR",
                              style: TextStyle(
                                color: Color(0xFFC9A84C),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF0D1F3C),
                                ),
                                decoration: InputDecoration(
                                  hintText: _selectedPricingType == "hourly" ? "100" : "500",
                                  hintStyle: const TextStyle(color: Color(0xFFA0ABBE)),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            if (_selectedPricingType == "hourly") ...[
                              const Text(
                                "/heure",
                                style: TextStyle(
                                  color: Color(0xFFA0ABBE),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Location
                    _buildSectionLabel("Zone d'intervention"),
                    Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF0D1F3C).withOpacity(0.12),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _locationController,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF0D1F3C),
                        ),
                        decoration: const InputDecoration(
                          hintText: "Ex: Al Sadd, West Bay, Lusail…",
                          hintStyle: TextStyle(color: Color(0xFFA0ABBE)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Urgent card switch
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF0D1F3C).withOpacity(0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Annonce urgente",
                                style: TextStyle(
                                  color: Color(0xFF0D1F3C),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                "Mise en avant pour 3 jours",
                                style: TextStyle(
                                  color: Color(0xFF6B7A99),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _urgent = !_urgent;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              height: 24,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: _urgent ? const Color(0xFFC9A84C) : const Color(0xFFE8EDF5),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              alignment: _urgent ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 2,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

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
                        onPressed: _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Publier l'annonce",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0D1F3C),
        ),
      ),
    );
  }
}
