import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final double? size;
  final bool bordered;
  final VoidCallback? onTap;

  const UserAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 18,
    this.size,
    this.bordered = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    final initial = (name != null && name!.isNotEmpty) ? name![0].toUpperCase() : '?';

    Widget avatar;
    if (bordered && size != null) {
      avatar = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFC9A84C), width: 2),
        ),
        child: ClipOval(
          child: hasImage
              ? Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _fallbackIcon(size! * 0.5),
                )
              : _fallbackIcon(size! * 0.5),
        ),
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFFE8EDF5),
        backgroundImage: hasImage ? NetworkImage(imageUrl!) : null,
        child: hasImage
            ? null
            : (name != null && name!.isNotEmpty)
                ? Text(
                    initial,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: radius * 0.7,
                      color: const Color(0xFF0D1F3C),
                    ),
                  )
                : Icon(Icons.person, size: radius, color: const Color(0xFF6B7A99)),
      );
    }

    if (onTap == null) return avatar;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: avatar,
      ),
    );
  }

  Widget _fallbackIcon(double iconSize) {
    return Container(
      color: const Color(0xFFE8EDF5),
      alignment: Alignment.center,
      child: Icon(Icons.person, size: iconSize, color: const Color(0xFF6B7A99)),
    );
  }
}
