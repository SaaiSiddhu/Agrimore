// PROFILE-12: the canonical sticky photo header — a real
// SliverAppBar(pinned: true) + FlexibleSpaceBar, not a scroll-listener
// look-alike. Extracted after profile_screen.dart and edit_profile_screen
// .dart (apps/marketplace) each hand-rolled an identical copy of the same
// three pieces: the translucent circular back button, the ScrollController
// + collapse-fraction listener, and the pinned-title-fades-in-as-you-scroll
// SliverAppBar itself. Any screen with a photo hero that should collapse
// into a plain title bar on scroll belongs on this, not a fresh copy.
//
// Usage (three pieces, used together):
//   class _MyScreenState extends State<MyScreen>
//       with StickyHeaderCollapseMixin<MyScreen> {
//     ...
//     CustomScrollView(
//       controller: stickyHeaderScrollController,
//       physics: const ClampingScrollPhysics(),
//       slivers: [
//         StickyPhotoHeaderSliver(
//           collapse: headerCollapse,
//           collapsedTitle: 'My Screen',
//           collapsedSubtitle: 'Optional second line', // omit for one line
//           backgroundImage: 'assets/images/Profile/profile_bg.png',
//           isDark: isDark,
//           onBack: () => Navigator.pop(context),
//           heroContent: ... // the expanded-state widget: whatever this
//                            // screen wants visible over the photo before
//                            // the user scrolls (a title, an avatar row).
//         ),
//         ...
//       ],
//     )
//   }

import 'package:flutter/material.dart';

/// The 36dp translucent-white circular back button used in every sticky
/// photo header. Usable on its own (e.g. as a second action button) or via
/// [StickyPhotoHeaderSliver]'s own `leading`.
class StickyHeaderBackButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;

  const StickyHeaderBackButton({
    super.key,
    this.onTap,
    this.icon = Icons.arrow_back_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.92),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}

/// Owns the scroll-driven collapse fraction a [StickyPhotoHeaderSliver]
/// needs: mix this into a screen's `State` and drive its `CustomScrollView`
/// with [stickyHeaderScrollController]; read [headerCollapse] (0 at the top
/// of the scroll, 1 once collapsed) to pass into the sliver's `collapse`.
/// Handles listener registration and disposal — no screen needs to write
/// that boilerplate again.
mixin StickyHeaderCollapseMixin<T extends StatefulWidget> on State<T> {
  final ScrollController stickyHeaderScrollController = ScrollController();
  double headerCollapse = 0.0;

  /// Scroll distance (logical pixels) over which the header fully
  /// collapses. Both current screens collapse over 150px; override only if
  /// a screen's hero is a genuinely different height.
  double get stickyHeaderCollapseDistance => 150.0;

  @override
  void initState() {
    super.initState();
    stickyHeaderScrollController.addListener(_onStickyHeaderScroll);
  }

  void _onStickyHeaderScroll() {
    // PROFILE-19: a proportional fade over `stickyHeaderCollapseDistance`
    // only reads as an intentional animation when there's enough room for
    // the user's scroll gesture to feel deliberate. When the actual
    // scrollable range is smaller than that distance (short content on a
    // tall device), PROFILE-18 tried clamping the divisor to the smaller
    // range — but that made a tiny accidental scroll produce an even
    // LARGER collapse fraction than before (a fixed offset over a smaller
    // divisor), so the hero title and the pinned title still ended up both
    // partially visible at once, worse than the original bug. The actual
    // fix: don't fade at all over an insufficient range — snap cleanly to
    // fully expanded at rest and fully collapsed the moment any scrolling
    // happens, so there is never a position that renders both titles at
    // once. Screens with the normal 150px+ of room (Profile screen; Edit
    // Profile itself on a taller device) are unaffected — the condition
    // only changes anything when maxScrollExtent is actually smaller.
    final maxExtent = stickyHeaderScrollController.position.maxScrollExtent;
    final offset = stickyHeaderScrollController.offset;
    final progress = maxExtent < stickyHeaderCollapseDistance
        ? (offset > 0 ? 1.0 : 0.0)
        : (offset / stickyHeaderCollapseDistance).clamp(0.0, 1.0);
    if (progress != headerCollapse) {
      setState(() => headerCollapse = progress);
    }
  }

  @override
  void dispose() {
    stickyHeaderScrollController.removeListener(_onStickyHeaderScroll);
    stickyHeaderScrollController.dispose();
    super.dispose();
  }
}

/// The pinned photo header itself. [heroContent] is whatever the screen
/// wants visible over the photo before the user scrolls (Profile's
/// avatar/name row, Edit Profile's title/subtitle column) — left as a
/// caller-supplied widget rather than over-parameterised into named slots,
/// since the two known call sites already want visibly different content.
/// [extraStackChildren] lets a screen add more Stack layers over the photo
/// (Profile's overlapping quick-action cards); leave it empty otherwise.
class StickyPhotoHeaderSliver extends StatelessWidget {
  final double collapse;
  final String collapsedTitle;
  // PROFILE-14: optional second line under the pinned title (Edit
  // Profile's "Keep your information up to date"). Profile screen passes
  // none and keeps its own established single-line "Profile" behaviour —
  // this is additive, not a change to any existing call site.
  final String? collapsedSubtitle;
  final String backgroundImage;
  final Widget heroContent;
  final bool isDark;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final double expandedHeight;
  final List<Widget> extraStackChildren;

  const StickyPhotoHeaderSliver({
    super.key,
    required this.collapse,
    required this.collapsedTitle,
    this.collapsedSubtitle,
    required this.backgroundImage,
    required this.heroContent,
    required this.isDark,
    this.onBack,
    this.actions = const [],
    this.expandedHeight = 180,
    this.extraStackChildren = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      expandedHeight: expandedHeight,
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: StickyHeaderBackButton(onTap: onBack),
      ),
      actions: actions,
      centerTitle: false,
      titleSpacing: 4,
      // Only the collapsed toolbar strip is ever visible here (heroContent
      // lives in flexibleSpace's background) — opacity is driven by scroll
      // offset so it's invisible while the hero shows and fades in once
      // the user has scrolled past it. A small upward slide rides along
      // with the fade (settling into place as it appears) rather than a
      // flat linear dissolve.
      title: Opacity(
        opacity: collapse,
        child: Transform.translate(
          offset: Offset(0, (1 - collapse) * 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                collapsedTitle,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (collapsedSubtitle != null)
                Text(
                  collapsedSubtitle!,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(backgroundImage, fit: BoxFit.cover),
            if (isDark) Container(color: Colors.black.withValues(alpha: 0.55)),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, kToolbarHeight - 4, 16, 12),
                  child: heroContent,
                ),
              ),
            ),
            ...extraStackChildren,
          ],
        ),
      ),
    );
  }
}
