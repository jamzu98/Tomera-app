import 'package:flutter/material.dart';

/// Curated Material icons a workspace can use. The database stores the map
/// key (spec §4), so entries must never be renamed — only added.
const workspaceIcons = <String, IconData>{
  'work': Icons.work_outline,
  'school': Icons.school_outlined,
  'code': Icons.code,
  'build': Icons.build_outlined,
  'home': Icons.home_outlined,
  'book': Icons.menu_book_outlined,
  'brush': Icons.brush_outlined,
  'business': Icons.business_outlined,
  'computer': Icons.computer_outlined,
  'event': Icons.event_outlined,
  'fitness': Icons.fitness_center_outlined,
  'music': Icons.music_note_outlined,
  'pets': Icons.pets_outlined,
  'restaurant': Icons.restaurant_outlined,
  'shopping': Icons.shopping_cart_outlined,
  'sports': Icons.sports_soccer_outlined,
  'terminal': Icons.terminal_outlined,
  'translate': Icons.translate_outlined,
  'science': Icons.science_outlined,
  'savings': Icons.savings_outlined,
};

IconData workspaceIcon(String name) => workspaceIcons[name] ?? Icons.folder_outlined;

/// Preset ARGB palette for workspace colors.
const workspaceColors = <int>[
  0xFF00696B, // teal
  0xFF1565C0, // blue
  0xFF3949AB, // indigo
  0xFF6A1B9A, // purple
  0xFFAD1457, // pink
  0xFFC62828, // red
  0xFFE65100, // orange
  0xFF795548, // brown
  0xFF2E7D32, // green
  0xFF546E7A, // blue grey
];
