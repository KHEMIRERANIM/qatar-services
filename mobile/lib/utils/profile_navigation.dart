import 'package:flutter/material.dart';
import '../screens/user_profile_screen.dart';

class ProfileNavigation {
  static void open(
    BuildContext context, {
    required int? userId,
    int? currentUserId,
    VoidCallback? onOwnProfile,
    void Function(Map<String, dynamic> annonce)? onAnnonceTap,
  }) {
    if (userId == null) return;

    if (currentUserId != null && userId == currentUserId) {
      onOwnProfile?.call();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: userId,
          onAnnonceTap: onAnnonceTap,
        ),
      ),
    );
  }
}
