import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:agrimore_core/agrimore_core.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../app/themes/admin_colors.dart';  // ✅ Added for AdminColors

/// Enhanced Category Management Screen with hierarchical tree view
class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({Key? key}) : super(key: key);

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  CategoryModel? _selectedCategory;
  final Set<String> _expandedCategories = {};
  bool _isLoading = false;
  // Set only while a reparent drag (the new Icons.open_with_rounded handle)
  // is in flight -- lets the tree header show a "drop here for top level"
  // hint without needing the header itself to be the active drop target.
  CategoryModel? _draggingCategory;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final adminProvider = Provider.of<AdminProvider>(context, listen: false);
      adminProvider.loadCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AdminColors.primaryLight : AdminColors.primary;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: isDark ? AdminColors.backgroundDark : AdminColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AdminColors.cardBackgroundDark : Colors.white,
        elevation: 0,
        leading: isMobile && _selectedCategory != null
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
                onPressed: () => setState(() => _selectedCategory = null),
              )
            : null,
        title: Text(
          isMobile && _selectedCategory != null
              ? _selectedCategory!.name
              : 'Category Management',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!isMobile || _selectedCategory == null)
            TextButton.icon(
              onPressed: () => _showCategoryDialog(),
              icon: Icon(Icons.add_rounded, color: accentColor, size: isMobile ? 20 : 24),
              label: Text(
                isMobile ? 'Add' : 'Add Main Category',
                style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: isMobile ? 12 : 14),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<AdminProvider>(
        builder: (context, adminProvider, child) {
          if (adminProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final categories = adminProvider.categories;
          final mainCategories = categories.where((c) => c.isMainCategory).toList()
            ..sort(_compareSiblings);

          if (categories.isEmpty) {
            return _buildEmptyState(isDark, accentColor);
          }

          // ✅ RESPONSIVE LAYOUT
          if (isMobile) {
            // Mobile: Single panel - show tree or details
            return _selectedCategory != null
                ? _buildCategoryDetails(_selectedCategory!, isDark, accentColor, categories)
                : _buildMobileTreeView(mainCategories, categories, isDark, accentColor);
          } else {
            // Desktop: Side by side
            return Row(
              children: [
                // Left Panel - Category Tree
                Container(
                  width: screenWidth < 1024 ? 280 : 320,
                  decoration: BoxDecoration(
                    color: isDark ? AdminColors.cardBackgroundDark : Colors.white,
                    border: Border(
                      right: BorderSide(
                        color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTreeHeader(isDark, accentColor, categories),
                      Expanded(
                        child: ReorderableListView.builder(
                          padding: const EdgeInsets.all(8),
                          buildDefaultDragHandles: false,
                          itemCount: mainCategories.length,
                          onReorderItem: (oldIndex, newIndex) =>
                              _onReorderCategories(mainCategories, oldIndex, newIndex),
                          itemBuilder: (context, index) {
                            return _buildCategoryTreeItem(
                              mainCategories[index],
                              categories,
                              isDark,
                              accentColor,
                              0,
                              index,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Right Panel - Category Details
                Expanded(
                  child: _selectedCategory != null
                      ? _buildCategoryDetails(_selectedCategory!, isDark, accentColor, categories)
                      : _buildSelectCategoryPrompt(isDark),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  // ✅ NEW: Mobile tree view with full width
  Widget _buildMobileTreeView(
    List<CategoryModel> mainCategories,
    List<CategoryModel> allCategories,
    bool isDark,
    Color accentColor,
  ) {
    return Column(
      children: [
        _buildTreeHeader(isDark, accentColor, allCategories),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.all(12),
            buildDefaultDragHandles: false,
            itemCount: mainCategories.length,
            onReorderItem: (oldIndex, newIndex) =>
                _onReorderCategories(mainCategories, oldIndex, newIndex),
            itemBuilder: (context, index) {
              return _buildCategoryTreeItem(
                mainCategories[index],
                allCategories,
                isDark,
                accentColor,
                0,
                index,
              );
            },
          ),
        ),
      ],
    );
  }

  // Doubles as the top-level drop target for the reparent-drag handle: any
  // category dropped here moves to parentId: null / level: 0. The header's
  // own title text hints "drop here" for the whole duration of a reparent
  // drag (_draggingCategory, set/cleared by the row's LongPressDraggable),
  // while the border/background only highlight while actually hovering.
  Widget _buildTreeHeader(bool isDark, Color accentColor, List<CategoryModel> allCategories) {
    return DragTarget<CategoryModel>(
      onWillAcceptWithDetails: (details) {
        if (_isNoOpReparent(details.data, null)) return false;
        final adminProvider = Provider.of<AdminProvider>(context, listen: false);
        return _reparentRejectionReason(details.data, null, allCategories, adminProvider) == null;
      },
      onAcceptWithDetails: (details) => _reparentCategory(details.data, null, allCategories),
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDropTarget ? accentColor.withOpacity(0.12) : null,
            border: Border(
              bottom: BorderSide(
                color: isDropTarget ? accentColor : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
                width: isDropTarget ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.account_tree_rounded, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Text(
                _draggingCategory != null ? 'Drop here to move to top level' : 'Category Tree',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                icon:
                    Icon(Icons.refresh_rounded, color: isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
                onPressed: _loadCategories,
                tooltip: 'Refresh',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryTreeItem(
    CategoryModel category,
    List<CategoryModel> allCategories,
    bool isDark,
    Color accentColor,
    int depth,
    int siblingIndex,
  ) {
    final children = allCategories.where((c) => c.parentId == category.id).toList()
      ..sort(_compareSiblings);
    final hasChildren = children.isNotEmpty;
    final isExpanded = _expandedCategories.contains(category.id);
    final isSelected = _selectedCategory?.id == category.id;

    return Column(
      key: ValueKey(category.id),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DragTarget<CategoryModel>(
          onWillAcceptWithDetails: (details) {
            if (_isNoOpReparent(details.data, category.id)) return false;
            final adminProvider = Provider.of<AdminProvider>(context, listen: false);
            return _reparentRejectionReason(details.data, category.id, allCategories, adminProvider) ==
                null;
          },
          onAcceptWithDetails: (details) =>
              _reparentCategory(details.data, category.id, allCategories),
          builder: (context, candidateData, rejectedData) {
            final isDropTarget = candidateData.isNotEmpty;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = category),
              child: Container(
                margin: EdgeInsets.only(left: depth * 16.0, bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDropTarget
                      ? accentColor.withOpacity(0.25)
                      : (isSelected
                          ? accentColor.withOpacity(0.15)
                          : (isDark ? Colors.grey[850] : Colors.grey[50])),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDropTarget ? accentColor : (isSelected ? accentColor : Colors.transparent),
                    width: isDropTarget ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Expand/Collapse Icon
                    if (hasChildren)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedCategories.remove(category.id);
                            } else {
                              _expandedCategories.add(category.id);
                            }
                          });
                        },
                        child: Icon(
                          isExpanded ? Icons.expand_more : Icons.chevron_right,
                          size: 20,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      )
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    // Category Icon
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _getLevelColor(category.level).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: category.iconUrl != null && category.iconUrl!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedNetworkImage(
                                imageUrl: category.iconUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Icon(
                                  _getLevelIcon(category.level),
                                  size: 16,
                                  color: _getLevelColor(category.level),
                                ),
                              ),
                            )
                          : Icon(
                              _getLevelIcon(category.level),
                              size: 16,
                              color: _getLevelColor(category.level),
                            ),
                    ),
                    const SizedBox(width: 10),
                    // Category Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            category.levelName,
                            style: TextStyle(
                              fontSize: 10,
                              color: _getLevelColor(category.level),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    if (!category.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Inactive',
                          style: TextStyle(fontSize: 9, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                      ),
                    const SizedBox(width: 4),
                    // Reparent handle -- a SECOND, independent drag affordance
                    // (own hit-test region, own Draggable/DragTarget pair)
                    // from the reorder handle below: dragging THIS icon onto
                    // another row (or the tree header, for top level) crosses
                    // sibling groups; the plain drag_indicator_rounded handle
                    // below still only reorders within the current
                    // ReorderableListView (CAT-5, unchanged). No Tooltip
                    // wrapper: a bare Tooltip's own long-press-to-show
                    // recognizer would contend with LongPressDraggable's
                    // long-press-to-drag on a touch device -- the existing
                    // reorder handle beside it is also tooltip-less.
                    LongPressDraggable<CategoryModel>(
                      data: category,
                      feedback: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        color: isDark ? AdminColors.cardBackgroundDark : Colors.white,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accentColor, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _getLevelIcon(category.level),
                                size: 16,
                                color: _getLevelColor(category.level),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                category.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: Icon(
                          Icons.open_with_rounded,
                          size: 18,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                      ),
                      onDragStarted: () => setState(() => _draggingCategory = category),
                      onDragEnd: (_) => setState(() => _draggingCategory = null),
                      onDraggableCanceled: (_, __) => setState(() => _draggingCategory = null),
                      child: Icon(
                        Icons.open_with_rounded,
                        size: 18,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Drag handle -- grabbing this, not tapping the row or the
                    // chevron, is what starts a reorder (ReorderableDragStartListener
                    // needs this item's own index within its immediate
                    // ReorderableListView, which is siblingIndex, not depth).
                    ReorderableDragStartListener(
                      index: siblingIndex,
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 18,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        // Children -- a nested, non-scrolling ReorderableListView per expanded
        // parent, not a plain Column spread: nesting one per sibling group is
        // what makes a drag structurally unable to cross into a different
        // parent (each level is its own separate ReorderableListView instance)
        // and keeps _expandedCategories (keyed by id, not index) unaffected.
        if (hasChildren && isExpanded)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (oldIndex, newIndex) =>
                _onReorderCategories(children, oldIndex, newIndex),
            children: [
              for (var i = 0; i < children.length; i++)
                _buildCategoryTreeItem(
                  children[i],
                  allCategories,
                  isDark,
                  accentColor,
                  depth + 1,
                  i,
                ),
            ],
          ),
      ],
    );
  }

  /// displayOrder-then-id -- must match AdminProvider.reorderCategory's own
  /// sibling sort exactly, since the index a ReorderableListView reports in
  /// onReorder is only meaningful if it refers to the same ordering
  /// reorderCategory itself uses to resolve "index N" when resequencing.
  int _compareSiblings(CategoryModel a, CategoryModel b) {
    final byOrder = a.displayOrder.compareTo(b.displayOrder);
    return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
  }

  Future<void> _onReorderCategories(
    List<CategoryModel> siblings,
    int oldIndex,
    int newIndex,
  ) async {
    // onReorderItem (unlike the deprecated onReorder) hands newIndex already
    // adjusted for the removed item at oldIndex -- no manual +/-1 correction.
    final category = siblings[oldIndex];
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    try {
      await adminProvider.reorderCategory(category, newIndex);
      _loadCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
        );
      }
    }
  }

  /// True if dropping [dragged] onto [targetParentId] (null = top level)
  /// would not actually change anything -- dragged is already there. Kept
  /// separate from [_reparentRejectionReason] so a drop target can decline
  /// the "no-op" case silently (no highlight, no snackbar) rather than
  /// showing it as a rejection.
  bool _isNoOpReparent(CategoryModel dragged, String? targetParentId) =>
      dragged.parentId == targetParentId;

  /// Null if dropping [dragged] onto [targetParentId] (null = top level) is
  /// a valid reparent; otherwise the user-facing reason it is rejected.
  /// Checked live during drag-hover (DragTarget.onWillAcceptWithDetails, for
  /// the highlight) and again just before writing (onAcceptWithDetails, for
  /// the error message) -- allCategories can shift between the two moments
  /// via the realtime listener, so both checks matter.
  String? _reparentRejectionReason(
    CategoryModel dragged,
    String? targetParentId,
    List<CategoryModel> allCategories,
    AdminProvider adminProvider,
  ) {
    // wouldCreateCategoryCycle already covers targetParentId == dragged.id
    // (a category "parented onto itself"), so there is no separate check
    // for that here.
    if (adminProvider.wouldCreateCategoryCycle(dragged.id, targetParentId)) {
      final targetName =
          allCategories.where((c) => c.id == targetParentId).firstOrNull?.name ?? 'that category';
      return 'Cannot make "${dragged.name}" a subcategory of "$targetName" — "$targetName" is already inside "${dragged.name}".';
    }
    if (targetParentId != null) {
      final targetLevel = allCategories.where((c) => c.id == targetParentId).firstOrNull?.level ?? 0;
      if (targetLevel + 1 + adminProvider.subtreeHeightOf(dragged.id) > 3) {
        return 'Moving "${dragged.name}" here would push its own subcategories past the maximum nesting depth.';
      }
    }
    return null;
  }

  Future<void> _reparentCategory(
    CategoryModel dragged,
    String? targetParentId,
    List<CategoryModel> allCategories,
  ) async {
    if (_isNoOpReparent(dragged, targetParentId)) return;
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final rejection = _reparentRejectionReason(dragged, targetParentId, allCategories, adminProvider);
    if (rejection != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text(rejection)),
        );
      }
      return;
    }
    final newLevel = targetParentId == null
        ? 0
        : (allCategories.where((c) => c.id == targetParentId).firstOrNull?.level ?? 0) + 1;
    try {
      await adminProvider.updateCategory(dragged.copyWith(parentId: targetParentId, level: newLevel));
      if (targetParentId != null) {
        _expandedCategories.add(targetParentId);
      }
      _loadCategories();
      if (mounted) {
        final destinationName = targetParentId == null
            ? 'top level'
            : (allCategories.where((c) => c.id == targetParentId).firstOrNull?.name ?? 'that category');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Moved "${dragged.name}" to $destinationName'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.redAccent, content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildCategoryDetails(
    CategoryModel category,
    bool isDark,
    Color accentColor,
    List<CategoryModel> allCategories,
  ) {
    final children = allCategories.where((c) => c.parentId == category.id).toList();
    final parent = category.parentId != null
        ? allCategories.where((c) => c.id == category.parentId).firstOrNull
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Actions
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getLevelColor(category.level).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        category.levelName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _getLevelColor(category.level),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Row(
                children: [
                  if (category.canHaveChildren)
                    _buildActionButton(
                      icon: Icons.add_rounded,
                      label: 'Add Sub',
                      color: Colors.green,
                      onTap: () => _showCategoryDialog(parentCategory: category),
                    ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    color: accentColor,
                    onTap: () => _showCategoryDialog(categoryToEdit: category),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.delete_rounded,
                    label: 'Delete',
                    color: Colors.red,
                    onTap: () => _confirmDelete(category, children.length),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Banner & Icon Preview
          _buildImagePreviewSection(category, isDark, accentColor),
          const SizedBox(height: 24),
          // Details Card
          _buildDetailsCard(category, parent, isDark, accentColor),
          const SizedBox(height: 24),
          // Subcategories
          if (children.isNotEmpty)
            _buildSubcategoriesCard(children, isDark, accentColor),
        ],
      ),
    );
  }

  Widget _buildImagePreviewSection(CategoryModel category, bool isDark, Color accentColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon Preview
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Icon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            const SizedBox(height: 8),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
              ),
              child: category.iconUrl != null && category.iconUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(imageUrl: category.iconUrl!, fit: BoxFit.cover),
                    )
                  : Icon(Icons.image_outlined, color: Colors.grey[400], size: 32),
            ),
          ],
        ),
        const SizedBox(width: 24),
        // Banner Preview
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Banner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 8),
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
                child: category.bannerImageUrl != null && category.bannerImageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(imageUrl: category.bannerImageUrl!, fit: BoxFit.cover),
                      )
                    : Center(child: Icon(Icons.panorama_outlined, color: Colors.grey[400], size: 32)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(CategoryModel category, CategoryModel? parent, bool isDark, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AdminColors.cardBackgroundDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          _buildDetailRow('Description', category.description.isNotEmpty ? category.description : 'No description', isDark),
          _buildDetailRow('Status', category.isActive ? 'Active' : 'Inactive', isDark, valueColor: category.isActive ? Colors.green : Colors.orange),
          _buildDetailRow('Visible to Customers', category.isVisible ? 'Yes' : 'No', isDark, valueColor: category.isVisible ? Colors.green : Colors.orange),
          _buildDetailRow('Featured', category.isFeatured ? 'Yes' : 'No', isDark, valueColor: category.isFeatured ? Colors.blue : null),
          _buildDetailRow('Display Order', category.displayOrder.toString(), isDark),
          if (parent != null)
            _buildDetailRow('Parent Category', parent.name, isDark),
          _buildDetailRow('Products', '${category.productCount} products', isDark),
          _buildDetailRow('Created', '${category.createdAt.day}/${category.createdAt.month}/${category.createdAt.year}', isDark),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[600])),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: valueColor ?? (isDark ? Colors.white : Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoriesCard(List<CategoryModel> children, bool isDark, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AdminColors.cardBackgroundDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subcategories (${children.length})', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: children.map((child) {
              return ActionChip(
                label: Text(child.name, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)),
                avatar: Icon(_getLevelIcon(child.level), size: 16, color: _getLevelColor(child.level)),
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                onPressed: () => setState(() => _selectedCategory = child),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      style: TextButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildSelectCategoryPrompt(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 64, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Select a category to view details',
            style: TextStyle(fontSize: 16, color: isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color accentColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.category_outlined, size: 80, color: isDark ? Colors.grey[700] : Colors.grey[300]),
          const SizedBox(height: 24),
          Text(
            'No Categories Yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first category to get started',
            style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCategoryDialog(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Main Category'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog({CategoryModel? categoryToEdit, CategoryModel? parentCategory}) {
    final allCategories = Provider.of<AdminProvider>(context, listen: false).categories;
    showDialog(
      context: context,
      builder: (context) => _CategoryFormDialog(
        categoryToEdit: categoryToEdit,
        parentCategory: parentCategory,
        allCategories: allCategories,
        onSave: (category) async {
          debugPrint('💾 Saving category: ${category.name}');
          debugPrint('   iconUrl: ${category.iconUrl}');
          debugPrint('   bannerImageUrl: ${category.bannerImageUrl}');
          
          final adminProvider = Provider.of<AdminProvider>(context, listen: false);
          if (categoryToEdit != null) {
            debugPrint('   → Updating existing category: ${category.id}');
            await adminProvider.updateCategory(category);
          } else {
            debugPrint('   → Adding new category');
            await adminProvider.addCategory(category);
          }
          debugPrint('✅ Category saved successfully');
          _loadCategories();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmDelete(CategoryModel category, int childCount) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AdminColors.cardBackgroundDark : Colors.white,
        title: Text('Delete Category?', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        content: Text(
          childCount > 0
              ? 'This category has $childCount subcategories. Deleting it will also delete all subcategories.'
              : 'Are you sure you want to delete "${category.name}"?',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              final adminProvider = Provider.of<AdminProvider>(context, listen: false);
              await adminProvider.deleteCategory(category.id);
              _loadCategories();
              if (_selectedCategory?.id == category.id) {
                setState(() => _selectedCategory = null);
              }
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 0: return Colors.blue;
      case 1: return Colors.purple;
      case 2: return Colors.orange;
      case 3: return Colors.teal;
      default: return Colors.grey;
    }
  }

  IconData _getLevelIcon(int level) {
    switch (level) {
      case 0: return Icons.folder_rounded;
      case 1: return Icons.folder_open_rounded;
      case 2: return Icons.description_rounded;
      case 3: return Icons.article_rounded;
      default: return Icons.category_rounded;
    }
  }
}

/// Category Form Dialog with image uploads
class _CategoryFormDialog extends StatefulWidget {
  final CategoryModel? categoryToEdit;
  final CategoryModel? parentCategory;
  final List<CategoryModel> allCategories;
  final Function(CategoryModel) onSave;

  const _CategoryFormDialog({
    this.categoryToEdit,
    this.parentCategory,
    this.allCategories = const [],
    required this.onSave,
  });

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _orderController = TextEditingController();

  bool _isActive = true;
  bool _isVisible = true;
  bool _isFeatured = false;
  String? _iconUrl;
  String? _bannerUrl;
  PlatformFile? _iconFile;  // ✅ Changed from XFile
  PlatformFile? _bannerFile;  // ✅ Changed from XFile
  bool _isLoading = false;

  // Only editable when editing an existing category -- at creation time the
  // parent is already fixed by which button the admin pressed ("Add Main
  // Category" vs. "Add Sub" under a specific category), so a redundant
  // picker there would just invite a mismatch with that choice.
  String? _selectedParentId;

  @override
  void initState() {
    super.initState();
    if (widget.categoryToEdit != null) {
      _nameController.text = widget.categoryToEdit!.name;
      _descriptionController.text = widget.categoryToEdit!.description;
      _orderController.text = widget.categoryToEdit!.displayOrder.toString();
      _isActive = widget.categoryToEdit!.isActive;
      _isVisible = widget.categoryToEdit!.isVisible;
      _isFeatured = widget.categoryToEdit!.isFeatured;
      _iconUrl = widget.categoryToEdit!.iconUrl;
      _bannerUrl = widget.categoryToEdit!.bannerImageUrl;
      _selectedParentId = widget.categoryToEdit!.parentId;
    } else {
      _selectedParentId = widget.parentCategory?.id;
    }
  }

  /// Descendants of [rootId] (children, grandchildren, ...) by walking
  /// parentId forward through widget.allCategories -- used only to keep
  /// invalid choices out of the dropdown; AdminProvider's own cycle check
  /// (walking backward from the chosen candidate) is the actual guard.
  Set<String> _descendantsOf(String rootId) {
    final result = <String>{};
    final queue = [rootId];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final c in widget.allCategories) {
        if (c.parentId == current && result.add(c.id)) {
          queue.add(c.id);
        }
      }
    }
    return result;
  }

  /// Candidate parents for the dropdown: excludes the category itself and
  /// its own descendants (cycle-safety, backstopped by AdminProvider's own
  /// upward cycle-walk on save), and excludes any candidate whose own level
  /// would push the deepest node in the category's CURRENT subtree past the
  /// model's documented 4-level cap. `c.level + 1 + ownSubtreeHeight <= 3`
  /// subsumes the simpler `c.canHaveChildren` (level < 3) this replaced --
  /// the two are identical whenever the category being edited is a leaf
  /// (ownSubtreeHeight == 0) and only the new check is stricter once it has
  /// descendants of its own, which `canHaveChildren` alone never accounted
  /// for (CAT-7 added this exact guard to the tree's drag-and-drop reparent
  /// path but, disclosed there as deferred, never to this dropdown -- the
  /// two reparent paths could disagree on the same move until now).
  List<CategoryModel> _validParentChoices() {
    final editingId = widget.categoryToEdit?.id;
    final excluded = editingId == null ? <String>{} : {editingId, ..._descendantsOf(editingId)};
    final ownSubtreeHeight = editingId == null
        ? 0
        : Provider.of<AdminProvider>(context, listen: false).subtreeHeightOf(editingId);
    return widget.allCategories
        .where((c) => !excluded.contains(c.id) && c.level + 1 + ownSubtreeHeight <= 3)
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  // ✅ Using file_picker for reliable web byte handling
  Future<void> _pickImage(bool isIcon) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // ✅ Important: get bytes directly
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        debugPrint('📷 Picked: ${file.name}, size: ${file.bytes?.length ?? 0} bytes');
        setState(() {
          if (isIcon) {
            _iconFile = file;
          } else {
            _bannerFile = file;
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error picking file: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final accentColor = isDark ? AdminColors.primaryLight : AdminColors.primary;

    final isEditing = widget.categoryToEdit != null;
    final level = widget.parentCategory != null ? widget.parentCategory!.level + 1 : 0;

    return Dialog(
      backgroundColor: isDark ? AdminColors.cardBackgroundDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(isEditing ? Icons.edit_rounded : Icons.add_rounded, color: accentColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Category' : 'Add Category',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                          ),
                          if (widget.parentCategory != null)
                            Text(
                              'Under: ${widget.parentCategory!.name}',
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Image Uploads Row
                Row(
                  children: [
                    // Icon Upload
                    Expanded(
                      child: _buildImageUpload(
                        label: 'Icon (512x512)',
                        imageUrl: _iconUrl,
                        file: _iconFile,
                        onPick: () => _pickImage(true),
                        isDark: isDark,
                        size: 80,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Banner Upload
                    Expanded(
                      flex: 2,
                      child: _buildImageUpload(
                        label: 'Banner (1920x400)',
                        imageUrl: _bannerUrl,
                        file: _bannerFile,
                        onPick: () => _pickImage(false),
                        isDark: isDark,
                        size: 80,
                        isBanner: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    prefixIcon: const Icon(Icons.category_outlined),
                    filled: true,
                    fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                // Description Field
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    prefixIcon: const Icon(Icons.description_outlined),
                    filled: true,
                    fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                if (widget.categoryToEdit != null) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedParentId,
                    isExpanded: true, // without this, the selected item's Text has no bounded width to ellipsize into and overflows instead
                    decoration: InputDecoration(
                      labelText: 'Parent Category',
                      prefixIcon: const Icon(Icons.account_tree_outlined),
                      filled: true,
                      fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('None (main category)')),
                      for (final c in _validParentChoices())
                        DropdownMenuItem<String?>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _selectedParentId = v),
                  ),
                ],
                const SizedBox(height: 16),
                // Order & Active Row
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _orderController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Display Order',
                          prefixIcon: const Icon(Icons.sort_rounded),
                          filled: true,
                          fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Active Toggle
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text('Active', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                          const SizedBox(width: 8),
                          Switch(
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                            activeColor: accentColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Visible & Featured Row -- independent of Active: a category
                // can stay active (manageable, keeps its products) while
                // temporarily hidden from customers, or vice versa.
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Visible', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                            Switch(
                              value: _isVisible,
                              onChanged: (v) => setState(() => _isVisible = v),
                              activeThumbColor: accentColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Featured', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                            Switch(
                              value: _isFeatured,
                              onChanged: (v) => setState(() => _isFeatured = v),
                              activeThumbColor: accentColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveCategory,
                      icon: _isLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(isEditing ? 'Update' : 'Create'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageUpload({
    required String label,
    String? imageUrl,
    PlatformFile? file,  // ✅ Changed from XFile
    required VoidCallback onPick,
    required bool isDark,
    double size = 80,
    bool isBanner = false,
  }) {
    Widget preview;
    if (file != null && file.bytes != null) {
      // ✅ Use Image.memory for file_picker bytes
      preview = Image.memory(file.bytes!, fit: BoxFit.cover);
    } else if (imageUrl != null && imageUrl.isNotEmpty) {
      preview = CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover);
    } else {
      preview = Icon(isBanner ? Icons.panorama_outlined : Icons.image_outlined, color: Colors.grey[400], size: 32);
    }

    return GestureDetector(
      onTap: onPick,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600])),
          const SizedBox(height: 6),
          Container(
            height: size,
            width: isBanner ? double.infinity : size,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  preview,
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Upload image to Firebase Storage using PlatformFile (file_picker)
  Future<String?> _uploadImage(PlatformFile file, String folder, String fileName) async {
    try {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        debugPrint('❌ No bytes in file');
        return null;
      }
      
      // Detect MIME type from bytes magic number
      final contentType = _detectMimeType(bytes);
      debugPrint('📸 Uploading ${bytes.length} bytes as $contentType');
      
      // Match file extension to content type
      String ext = 'jpg';
      if (contentType.contains('png')) ext = 'png';
      else if (contentType.contains('webp')) ext = 'webp';
      else if (contentType.contains('gif')) ext = 'gif';
      
      final actualFileName = fileName.replaceAll('.jpg', '.$ext');
      final ref = FirebaseStorage.instance.ref().child('categories/$folder/$actualFileName');
      
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      
      final url = await ref.getDownloadURL();
      debugPrint('✅ Image uploaded: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      return null;
    }
  }
  
  // Detect MIME type from bytes magic number
  String _detectMimeType(Uint8List bytes) {
    if (bytes.length < 4) return 'image/jpeg';
    
    // PNG: 89 50 4E 47
    if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
      return 'image/png';
    }
    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    // GIF: 47 49 46 38
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
      return 'image/gif';
    }
    // WEBP: 52 49 46 46 ... 57 45 42 50
    if (bytes.length > 12 && bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) {
      return 'image/webp';
    }
    
    return 'image/jpeg'; // Default fallback
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final categorySlug = CategoryModel.generateSlug(_nameController.text.trim());
      
      // ✅ Upload icon if selected
      String? iconUrl = _iconUrl;
      if (_iconFile != null) {
        iconUrl = await _uploadImage(_iconFile!, 'icons', '${categorySlug}_$timestamp.jpg');
      }
      
      // ✅ Upload banner if selected
      String? bannerUrl = _bannerUrl;
      if (_bannerFile != null) {
        bannerUrl = await _uploadImage(_bannerFile!, 'banners', '${categorySlug}_$timestamp.jpg');
      }

      // Resolve level from the ACTUAL selected parent, not from
      // widget.parentCategory -- that field is only ever set on the "Add
      // Sub" creation path, so computing level from it unconditionally
      // (the previous behavior) silently reset every edited subcategory's
      // parentId and level back to top-level on every save, regardless of
      // its real position. _selectedParentId reflects the real choice on
      // both the edit and the add path.
      final resolvedParent = _selectedParentId == null
          ? null
          : widget.allCategories.where((c) => c.id == _selectedParentId).firstOrNull;
      final level = resolvedParent != null ? resolvedParent.level + 1 : 0;

      final category = CategoryModel(
        id: widget.categoryToEdit?.id ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        iconUrl: iconUrl,
        bannerImageUrl: bannerUrl,
        displayOrder: int.tryParse(_orderController.text) ?? 0,
        isActive: _isActive,
        isVisible: _isVisible,
        isFeatured: _isFeatured,
        createdAt: widget.categoryToEdit?.createdAt ?? DateTime.now(),
        // Neither field has a form control of its own -- productCount is
        // computed elsewhere and subcategoryIds is bookkept by AdminProvider's
        // own add/update/delete logic (admin_provider.dart), never by this
        // dialog. Carrying the existing category's values forward on edit
        // (rather than defaulting to 0/[]) avoids silently discarding them --
        // updateCategoryModel does a Firestore .update() with this object's
        // FULL toMap(), so an omitted value here is a real overwrite, not a
        // no-op.
        productCount: widget.categoryToEdit?.productCount ?? 0,
        subcategoryIds: widget.categoryToEdit?.subcategoryIds ?? const [],
        parentId: _selectedParentId,
        level: level,
        slug: categorySlug,
      );

      await widget.onSave(category);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}