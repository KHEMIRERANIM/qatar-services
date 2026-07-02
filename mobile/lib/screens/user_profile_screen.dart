import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/user_avatar.dart';
import '../widgets/annonce_feed_card.dart';
import '../utils/profile_navigation.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;
  final void Function(Map<String, dynamic> annonce)? onAnnonceTap;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.onAnnonceTap,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;
  double? _noteGlobale;
  int _nbAvis = 0;
  List<Map<String, dynamic>> _parCategorie = [];
  List<Map<String, dynamic>> _avisRecents = [];
  List<Map<String, dynamic>> _annonces = [];
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final profileRes = await AuthService.getProfile();
    if (profileRes.success && profileRes.data != null) {
      final userData = profileRes.data!['user'] ?? profileRes.data!;
      _currentUserId = int.tryParse(userData['id']?.toString() ?? '');
    }

    final result = await AuthService.getPublicProfile(widget.userId);
    if (!mounted) return;

    if (result.success && result.data != null) {
      final data = result.data!;
      setState(() {
        _loading = false;
        _user = Map<String, dynamic>.from(data['user'] ?? {});
        _noteGlobale = double.tryParse(data['note_globale']?.toString() ?? '');
        _nbAvis = int.tryParse(data['nb_avis_total']?.toString() ?? '0') ?? 0;
        _parCategorie = List<Map<String, dynamic>>.from(data['par_categorie'] ?? []);
        _avisRecents = List<Map<String, dynamic>>.from(data['avis_recents'] ?? []);
        _annonces = List<Map<String, dynamic>>.from(data['annonces'] ?? []);
      });
    } else {
      setState(() {
        _loading = false;
        _error = result.message ?? 'Profil introuvable';
      });
    }
  }

  String get _fullName {
    if (_user == null) return 'Utilisateur';
    final name = '${_user!['prenom'] ?? ''} ${_user!['nom'] ?? ''}'.trim();
    return name.isNotEmpty ? name : 'Utilisateur';
  }

  String get _ratingText {
    if (_nbAvis == 0) return '— (0 avis)';
    return '${_noteGlobale?.toStringAsFixed(1) ?? '—'}★ ($_nbAvis avis)';
  }

  String _formatRelativeDate(dynamic raw) {
    if (raw == null) return '';
    final date = DateTime.tryParse(raw.toString());
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return "Aujourd'hui";
    if (diff.inDays == 1) return 'Il y a 1 jour';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    if (diff.inDays < 30) return 'Il y a ${(diff.inDays / 7).floor()} sem.';
    if (diff.inDays < 365) return 'Il y a ${(diff.inDays / 30).floor()} mois';
    return 'Il y a ${(diff.inDays / 365).floor()} an';
  }

  String _categoryEmoji(String? cat) {
    const map = {
      'plomberie': '🔧',
      'electricite': '⚡',
      'menage': '🧹',
      'jardinage': '🌿',
      'peinture': '🎨',
      'climatisation': '❄️',
      'demenagement': '📦',
      'reparation': '🛠️',
    };
    return map[cat?.toLowerCase()] ?? '📋';
  }

  void _showContactOptions() {
    final tel = _user?['telephone']?.toString();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Contacter $_fullName',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D1F3C),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (tel != null && tel.isNotEmpty)
              _contactTile(Icons.phone, 'Appeler', tel, const Color(0xFF2D9B6F), ctx),
            _contactTile(Icons.message_outlined, 'Envoyer un message', null, const Color(0xFF0D1F3C), ctx),
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
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC9A84C), strokeWidth: 2.5))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0D1F3C)),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_off_outlined, size: 48, color: Color(0xFFA0ABBE)),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7A99))),
                    const SizedBox(height: 20),
                    TextButton(onPressed: _load, child: const Text('Réessayer')),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final isPro = _user?['isPro'] == true;
    final photo = _user?['photo']?.toString();
    final ville = _user?['ville']?.toString() ?? '';
    final badgeVerifie = _user?['badge_verifie'] == true;
    final badgeTop = _user?['badge_top_prestataire'] == true;
    final badgePro = _user?['pro_abonnement_actif'] == true;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(photo, ville, isPro, badgeVerifie)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatsBar(),
                const SizedBox(height: 16),
                if (badgeVerifie || badgeTop || badgePro) ...[
                  _buildBadges(badgeVerifie, badgeTop, badgePro),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showContactOptions,
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Contacter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC9A84C),
                      foregroundColor: const Color(0xFF0D1F3C),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_parCategorie.isNotEmpty) ...[
                  _sectionCard(
                    title: 'Notes par catégorie',
                    trailing: Text(_ratingText,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC9A84C))),
                    child: Column(
                      children: _parCategorie.map((item) {
                        final cat = item['categorie']?.toString() ?? '';
                        final note = double.tryParse(item['note']?.toString() ?? '') ?? 0;
                        final nb = int.tryParse(item['nb_avis']?.toString() ?? '0') ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${_categoryEmoji(cat)} ${cat[0].toUpperCase()}${cat.substring(1)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0D1F3C)),
                                ),
                              ),
                              const Icon(Icons.star, color: Color(0xFFC9A84C), size: 16),
                              const SizedBox(width: 4),
                              Text(note.toStringAsFixed(1),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D1F3C))),
                              Text(' ($nb)', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A99))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
                if (_avisRecents.isNotEmpty)
                  _sectionCard(
                    title: 'Avis clients',
                    trailing: Text(_ratingText,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC9A84C))),
                    child: Column(
                      children: List.generate(_avisRecents.length, (i) {
                        final r = _avisRecents[i];
                        final reviewerId = int.tryParse(r['user_id']?.toString() ?? '');
                        return Padding(
                          padding: EdgeInsets.only(bottom: i == _avisRecents.length - 1 ? 0 : 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              UserAvatar(
                                radius: 18,
                                imageUrl: r['avatar_user']?.toString(),
                                name: r['nom_user']?.toString(),
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
                                          child: Text(r['nom_user']?.toString() ?? 'Client',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0D1F3C))),
                                        ),
                                        Text(_formatRelativeDate(r['created_at']),
                                            style: const TextStyle(fontSize: 10, color: Color(0xFF9AAAC0))),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: List.generate(
                                        5,
                                        (j) => Icon(
                                          j < (int.tryParse(r['note']?.toString() ?? '5') ?? 5)
                                              ? Icons.star
                                              : Icons.star_border,
                                          size: 12,
                                          color: const Color(0xFFC9A84C),
                                        ),
                                      ),
                                    ),
                                    if ((r['contenu']?.toString() ?? '').isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(r['contenu'].toString(),
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7A99), height: 1.4)),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  isPro ? 'Services proposés' : 'Annonces',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0D1F3C)),
                ),
                const SizedBox(height: 12),
                if (_annonces.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Aucune annonce active.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9AAAC0))),
                  )
                else
                  ..._annonces.map((a) => AnnonceFeedCard(
                        annonce: a,
                        nomUser: _fullName,
                        avatarUser: _user?['photo']?.toString(),
                        onTap: widget.onAnnonceTap != null ? () => widget.onAnnonceTap!(a) : null,
                        onContactTap: _showContactOptions,
                        showContactButton: true,
                      )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(String? photo, String ville, bool isPro, bool badgeVerifie) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 32,
        left: 20,
        right: 20,
      ),
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                  child: (photo != null && photo.isNotEmpty)
                      ? Image.network(photo, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, color: Colors.white54, size: 36))
                      : const Icon(Icons.person, color: Colors.white54, size: 36),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullName,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (ville.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFFC9A84C)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(ville,
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 12, color: Color(0xFFC9A84C)),
                        const SizedBox(width: 5),
                        Text(_ratingText, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isPro && badgeVerifie)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFC9A84C), Color(0xFFA8893B)]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Colors.white, size: 10),
                            SizedBox(width: 4),
                            Text('Professionnel vérifié',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Client',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        children: [
          _statItem('${_annonces.length}', 'Annonces'),
          _statDivider(),
          _statItem(_nbAvis == 0 ? '—' : '${_noteGlobale?.toStringAsFixed(1) ?? '—'}★', 'Note', highlighted: true),
          _statDivider(),
          _statItem('$_nbAvis', 'Avis'),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, {bool highlighted = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: highlighted ? 18 : 16,
                color: highlighted ? const Color(0xFFC9A84C) : const Color(0xFF0D1F3C),
              )),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9AAAC0))),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(width: 1, height: 32, color: const Color(0xFFF0F2F5));

  Widget _buildBadges(bool verifie, bool top, bool pro) {
    return _sectionCard(
      title: 'Badges',
      child: Column(
        children: [
          if (verifie) _badgeRow(Icons.verified, 'Vérifié', 'Identité confirmée', const Color(0xFF2D9B6F)),
          if (top) ...[
            if (verifie) const Divider(height: 1, color: Color(0xFFF0F2F5)),
            _badgeRow(Icons.workspace_premium, 'Top prestataire', 'Excellence reconnue', const Color(0xFFC9A84C)),
          ],
          if (pro) ...[
            if (verifie || top) const Divider(height: 1, color: Color(0xFFF0F2F5)),
            _badgeRow(Icons.diamond_outlined, 'Pro', 'Abonnement actif', const Color(0xFF6366F1)),
          ],
        ],
      ),
    );
  }

  Widget _badgeRow(IconData icon, String label, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D1F3C))),
                Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF9AAAC0))),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2D9B6F).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Obtenu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2D9B6F))),
          ),
        ],
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
}
