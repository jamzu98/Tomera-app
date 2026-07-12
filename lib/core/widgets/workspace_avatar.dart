import 'package:flutter/material.dart';

import '../../data/db/database.dart';
import '../../features/workspaces/workspace_style.dart';

/// Rounded-square workspace identity avatar (the redesign's replacement for
/// CircleAvatar). Radius scales with size to match the mock's proportions.
class WorkspaceAvatar extends StatelessWidget {
  const WorkspaceAvatar({
    super.key,
    required this.color,
    this.icon,
    this.size = 48,
  });

  WorkspaceAvatar.fromWorkspace(Workspace workspace,
      {super.key, this.size = 48})
      : color = Color(workspace.color),
        icon = workspaceIcon(workspace.icon);

  final Color color;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 3),
      ),
      child: icon == null
          ? null
          : Icon(icon, size: size / 2, color: workspaceForeground(color)),
    );
  }
}

/// Small square colour dot used inline in metadata rows and chips.
class WorkspaceDot extends StatelessWidget {
  const WorkspaceDot({super.key, required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.38),
      ),
    );
  }
}
