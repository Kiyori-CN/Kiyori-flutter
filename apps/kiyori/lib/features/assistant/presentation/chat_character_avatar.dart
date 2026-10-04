import 'package:flutter/material.dart';

/// 默认角色复用原品牌头像；其它角色保留未设置头像时的语义占位。
class ChatCharacterAvatar extends StatelessWidget {
  const ChatCharacterAvatar({
    required this.characterId,
    required this.size,
    this.background,
    this.foreground,
    super.key,
  });

  final String? characterId;
  final double size;
  final Color? background, foreground;

  @override
  Widget build(BuildContext context) {
    if (characterId == 'default_character') {
      return ClipOval(
        child: Image.asset(
          'assets/branding/kiyori-app-icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: 'Character Avatar',
        ),
      );
    }
    final c = Theme.of(context).colorScheme;
    final dark = c.brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? Color(dark ? 0xFF293729 : 0xFFEDF6EF),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_rounded,
        semanticLabel: 'Character Avatar',
        size: size == 24 ? 16 : 18,
        color: foreground ?? Color(dark ? 0xFF8BDC87 : 0xFF34974E),
      ),
    );
  }
}
