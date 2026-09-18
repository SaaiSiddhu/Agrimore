import 'package:flutter/material.dart';
import 'catalogue_app.dart';

/// Developer-only entry point for the AgriMore Sales Associate Design Catalogue.
///
/// Runs completely standalone without Firebase, authentication, or network
/// services.
///
/// Launch using:
/// ```bash
/// flutter run -t lib/catalogue/main_catalogue.dart
/// ```
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SaCatalogueApp());
}
