import 'package:flutter/material.dart';

class TagMarketPreset {
  const TagMarketPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.content,
    required this.category,
    required this.type,
    required this.icon,
  });
  final String id, name, description, content, category, type;
  final IconData icon;
}
