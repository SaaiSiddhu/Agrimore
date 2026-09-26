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
export 'themes/sales_associate_tokens.dart';
export 'themes/sales_associate_theme_extension.dart';
export 'themes/sales_associate_theme.dart';
export 'themes/sales_associate_icons.dart';
// UI-TEAL-0: the brand-parameterised Workspace system (Sales Associate + Seller).
export 'workspace/ws_foundation.dart';
export 'workspace/ws_tokens.dart';
export 'workspace/ws_theme.dart';
export 'workspace/ws_icons.dart';
export 'workspace/ws_format.dart';
// Workspace kit (ADR §7) — components live here, never in an app.
export 'workspace/kit/ws_otp_input.dart';
export 'workspace/kit/ws_timeline.dart';
export 'workspace/kit/ws_test_mode_ribbon.dart';
export 'workspace/kit/ws_step_header.dart';
export 'workspace/kit/ws_feedback.dart';
export 'workspace/kit/ws_countdown_ring.dart';

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
export 'widgets/common/custom_bottom_nav.dart' hide ButtonType, CustomButton;
export 'widgets/common/loading_overlay.dart';
export 'widgets/common/empty_state_widget.dart';
export 'widgets/common/error_view.dart';
export 'widgets/common/sticky_photo_header.dart';
export 'widgets/common/sa_loading_button.dart';
export 'widgets/common/sa_info_banner.dart';
export 'widgets/premium_splash_screen.dart';

// ============================================
// HELPERS
// ============================================
export 'widgets/snackbar_helper.dart';
export 'widgets/dialog_helper.dart';
