import 'package:flutter/material.dart';
import 'user_avatar.dart';

String annonceCategoryEmoji(String? cat) {
  switch (cat) {
    case 'plomberie':
      return '🔧';
    case 'electricite':
      return '⚡';
    case 'nettoyage':
      return '🧹';
    case 'cours':
      return '📚';
    case 'peinture':
      return '🎨';
    case 'livraison':
      return '🚚';
    case 'renovation':
      return '🏗️';
    default:
      return '📦';
  }
}

Color annonceCategoryColor(String? cat) {
  switch (cat) {
    case 'plomberie':
      return const Color(0xFF1565C0);
    case 'electricite':
      return const Color(0xFFF57F17);
    case 'nettoyage':
      return const Color(0xFF2E7D32);
    case 'cours':
      return const Color(0xFF6A1B9A);
    case 'peinture':
      return const Color(0xFFAD1457);
    case 'livraison':
      return const Color(0xFF558B2F);
    case 'renovation':
      return const Color(0xFF00838F);
    default:
      return const Color(0xFF0D1F3C);
  }
}

List<Color> annonceCategoryGradient(String? cat) {
  switch (cat) {
    case 'plomberie':
      return [const Color(0xFF1565C0), const Color(0xFF1E88E5)];
    case 'electricite':
      return [const Color(0xFFF57F17), const Color(0xFFFFA726)];
    case 'nettoyage':
      return [const Color(0xFF2E7D32), const Color(0xFF43A047)];
    case 'cours':
      return [const Color(0xFF6A1B9A), const Color(0xFF8E24AA)];
    case 'peinture':
      return [const Color(0xFFAD1457), const Color(0xFFE91E63)];
    case 'livraison':
      return [const Color(0xFF558B2F), const Color(0xFF7CB342)];
    case 'renovation':
      return [const Color(0xFF00838F), const Color(0xFF00ACC1)];
    default:
      return [const Color(0xFF0D1F3C), const Color(0xFF1A3560)];
  }
}

String annonceFormatPrixLabel(Map<String, dynamic> a) {
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

bool annonceIsUrgentActive(Map<String, dynamic> a) {
  if (a['urgent'] != 1 && a['urgent'] != true) return false;
  final until = a['urgent_until'];
  if (until == null) return true;
  try {
    return DateTime.parse(until.toString()).isAfter(DateTime.now());
  } catch (_) {
    return true;
  }
}

String annonceShortDate(String? raw) {
  if (raw == null) return '';
  try {
    final dt = DateTime.parse(raw).toLocal();
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

class AnnonceFeedCard extends StatelessWidget {
  final Map<String, dynamic> annonce;
  final String nomUser;
  final String? avatarUser;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onContactTap;
  final VoidCallback? onLikesTap;
  final bool showContactButton;

  const AnnonceFeedCard({
    super.key,
    required this.annonce,
    required this.nomUser,
    this.avatarUser,
    this.onTap,
    this.onAvatarTap,
    this.onContactTap,
    this.onLikesTap,
    this.showContactButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final String titre = annonce['titre']?.toString() ?? '';
    final String? premierePhoto = annonce['premiere_photo']?.toString();
    final String emoji = annonceCategoryEmoji(annonce['categorie']?.toString());
    final String categorie = annonce['categorie']?.toString() ?? '';
    final Color catColor = annonceCategoryColor(annonce['categorie']?.toString());
    final List<Color> catGrad = annonceCategoryGradient(annonce['categorie']?.toString());
    final String ville = annonce['ville']?.toString() ?? '';
    final String prixLabel = annonceFormatPrixLabel(annonce);
    final int nbLikes = int.tryParse(annonce['nb_likes']?.toString() ?? '0') ?? 0;
    final int nbCommentaires = int.tryParse(annonce['nb_commentaires']?.toString() ?? '0') ?? 0;
    final int nbAvis = int.tryParse(annonce['nb_avis']?.toString() ?? '0') ?? 0;
    final bool isUrgent = annonceIsUrgentActive(annonce);
    final String typePublication = (annonce['type_publication'] ?? 'offre').toString().toLowerCase();
    final String? postedAt = annonce['created_at']?.toString();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D1F3C).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 2),
            ),
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
                  if (premierePhoto != null && premierePhoto.isNotEmpty)
                    Image.network(
                      premierePhoto,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(catGrad, emoji),
                    )
                  else
                    _placeholder(catGrad, emoji),
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
                    top: 12,
                    right: 12,
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
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            UserAvatar(
                              size: 30,
                              bordered: true,
                              imageUrl: avatarUser,
                              name: nomUser,
                              onTap: onAvatarTap,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              nomUser,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                shadows: [Shadow(blurRadius: 4)],
                              ),
                            ),
                          ],
                        ),
                        if (showContactButton && onContactTap != null)
                          GestureDetector(
                            onTap: onContactTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC9A84C),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Contacter',
                                style: TextStyle(
                                  color: Color(0xFF0D1F3C),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$emoji $categorie',
                          style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (isUrgent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '⚡ URGENT',
                            style: TextStyle(color: Color(0xFFE65100), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    titre,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0D1F3C)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (ville.isNotEmpty) ...[
                        const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF9AAAC0)),
                        const SizedBox(width: 3),
                        Text(ville, style: const TextStyle(color: Color(0xFF9AAAC0), fontSize: 12)),
                        const SizedBox(width: 12),
                      ],
                      if (postedAt != null)
                        Text(annonceShortDate(postedAt), style: const TextStyle(color: Color(0xFF9AAAC0), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        prixLabel,
                        style: const TextStyle(color: Color(0xFFC9A84C), fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: nbLikes > 0 ? onLikesTap : null,
                            child: Row(
                              children: [
                                const Text('🤍', style: TextStyle(fontSize: 14)),
                                const SizedBox(width: 3),
                                Text(
                                  '$nbLikes',
                                  style: TextStyle(
                                    color: nbLikes > 0 ? const Color(0xFF0D1F3C) : const Color(0xFF9AAAC0),
                                    fontSize: 12,
                                    fontWeight: nbLikes > 0 ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              const Text('💬', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 3),
                              Text('$nbCommentaires', style: const TextStyle(color: Color(0xFF9AAAC0), fontSize: 12)),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 20, color: Color(0xFFC9A84C)),
                              const SizedBox(width: 3),
                              Text(
                                '$nbAvis',
                                style: TextStyle(
                                  color: nbAvis > 0 ? const Color(0xFFC9A84C) : const Color(0xFF9AAAC0),
                                  fontSize: 12,
                                  fontWeight: nbAvis > 0 ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
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
  }

  Widget _placeholder(List<Color> catGrad, String emoji) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: catGrad, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      alignment: Alignment.center,
      child: Text(emoji, style: const TextStyle(fontSize: 60)),
    );
  }
}
