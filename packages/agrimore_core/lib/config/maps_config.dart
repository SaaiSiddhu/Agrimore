// lib/config/maps_config.dart
//
// Phase 15, Workstream 5: the Google Maps/Geocoding API key literal was
// duplicated across three files in apps/marketplace. Consolidated here so
// rotation is a one-line change — this is a MAINTAINABILITY fix, not a
// security fix. An API key shipped in a Flutter client cannot be hidden:
// this constant is compiled into the binary exactly as the three duplicated
// literals were, and is equally extractable. The real mitigation is
// provider-side key restriction — see this phase's completion report for
// the exact Google Cloud Console steps.
class MapsConfig {
  static const String apiKey = 'AIzaSyCKL5RYJ39x93yz1Km59KwpYybRod3IOeg';
}
