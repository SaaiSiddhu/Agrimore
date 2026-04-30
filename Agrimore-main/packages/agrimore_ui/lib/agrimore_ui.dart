/// Agrimore UI Package
/// 
/// Contains shared themes, widgets, and responsive utilities
/// used across all Agrimore applications.
library agrimore_ui;

// Re-export core package for convenience
export 'package:agrimore_core/agrimore_core.dart';

// ============================================
// THEMES
// ============================================
export 'themes/app_theme.dart';
export 'themes/app_colors.dart';
export 'themes/app_text_styles.dart';

// ============================================
// RESPONSIVE
// ============================================
export 'responsive/responsive_helper.dart';
export 'responsive/responsive.dart';
export 'responsive/breakpoints.dart';
export 'responsive/size_config.dart';

// ============================================
// COMMON WIDGETS
// ============================================
export 'widgets/common/custom_button.dart';
export 'widgets/common/custom_text_field.dart';
export 'widgets/common/custom_app_bar.dart';
export 'widgets/common/custom_bottom_nav.dart' hide ButtonType, CustomButton;
export 'widgets/common/custom_drawer.dart';
export 'widgets/common/loading_indicator.dart';
export 'widgets/common/loading_overlay.dart';
export 'widgets/common/shimmer_loading.dart';
export 'widgets/common/empty_state_widget.dart';
export 'widgets/common/error_view.dart';
export 'widgets/common/error_widget.dart';
export 'widgets/common/rating_widget.dart';
export 'widgets/common/badge_widget.dart';
export 'widgets/common/search_bar_widget.dart';
export 'widgets/common/network_image_widget.dart';
export 'widgets/common/confirmation_dialog.dart';
export 'widgets/premium_splash_screen.dart';

// ============================================
// HELPERS
// ============================================
export 'widgets/snackbar_helper.dart';
export 'widgets/dialog_helper.dart';
