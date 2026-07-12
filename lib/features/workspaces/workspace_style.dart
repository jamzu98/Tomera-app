import 'package:flutter/material.dart';

/// Curated Material icons a workspace can use. The database stores the map
/// key (spec §4), so entries must never be renamed — only added.
///
/// Rounded (filled) variants approximate the Material Symbols Rounded set
/// used by the warm redesign.
const workspaceIcons = <String, IconData>{
  'work': Icons.work_rounded,
  'school': Icons.school_rounded,
  'code': Icons.code_rounded,
  'build': Icons.build_rounded,
  'home': Icons.home_rounded,
  'book': Icons.menu_book_rounded,
  'brush': Icons.brush_rounded,
  'business': Icons.business_rounded,
  'computer': Icons.computer_rounded,
  'event': Icons.event_rounded,
  'fitness': Icons.fitness_center_rounded,
  'music': Icons.music_note_rounded,
  'pets': Icons.pets_rounded,
  'restaurant': Icons.restaurant_rounded,
  'shopping': Icons.shopping_cart_rounded,
  'sports': Icons.sports_soccer_rounded,
  'terminal': Icons.terminal_rounded,
  'translate': Icons.translate_rounded,
  'science': Icons.science_rounded,
  'savings': Icons.savings_rounded,
};

IconData workspaceIcon(String name) =>
    workspaceIcons[name] ?? Icons.folder_rounded;

/// Preset ARGB palette for workspace colors (warm redesign accents).
const workspaceColors = <int>[
  0xFF7C7FF2, // indigo
  0xFFE4AB3C, // amber
  0xFF23A896, // teal
  0xFFC169B4, // plum
  0xFFEE6A4E, // coral
  0xFF5B9BD6, // sky
  0xFF7BB03A, // green
  0xFFD46BB0, // pink
  0xFFB7AD9C, // stone
  0xFFF1EBE1, // bone
];

/// Foreground with enough contrast to sit on a workspace accent color.
/// Light accents (amber, stone, bone) take dark ink; the rest take white.
Color workspaceForeground(Color background) =>
    background.computeLuminance() > 0.45
        ? const Color(0xFF241F18)
        : Colors.white;
