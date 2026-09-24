import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';

/// Owner decision (2026-09-24): the sign-in screens stay exactly as they are.
/// They were built on the shared Workspace theme, so they keep rendering
/// inside it while the rest of the seller app uses its own design system.
class LegacyAuthTheme extends StatelessWidget {
  const LegacyAuthTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: WorkspaceTheme.build(WorkspaceBrand.seller, Theme.of(context).brightness),
      child: child,
    );
  }
}

/// TRANSITIONAL — removed when the last seller screen is off the Workspace
/// kit: carries the Workspace tokens inside the seller theme so screens not
/// yet migrated keep working. Seller design-system widgets never read them.
ThemeData withLegacyWorkspaceTokens(ThemeData seller) {
  final legacy = WorkspaceTheme.build(WorkspaceBrand.seller, seller.brightness).extension<WorkspaceTokens>()!;
  return seller.copyWith(extensions: [...seller.extensions.values, legacy]);
}
