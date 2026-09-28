// ADMR-89 — typed models and an injectable repository boundary for the
// finance reconciliation screen, replacing untyped Map<String,dynamic>
// access scattered through the widget's own build method. The scan cursor
// itself stays an opaque Map<String,dynamic> deliberately: ADMR-88's own
// finding was that the client must never reach into a specific cursor
// field, only store what it received and hand back exactly that — giving
// it a concrete Dart type here would invite exactly the reconstruction
// this contract depends on never happening.
import 'package:cloud_functions/cloud_functions.dart';

class FinanceFinding {
  const FinanceFinding({
    required this.id,
    required this.kind,
    required this.actorType,
    required this.recordId,
    required this.actorId,
    required this.amountRupees,
    required this.summary,
    required this.detail,
    required this.confirmation,
  });

  final String id;
  final String kind;
  final String actorType;
  final String recordId;
  final String actorId;
  final double amountRupees;
  final String summary;
  final Map<String, dynamic> detail;

  /// 'confirmed' or 'unconfirmed' — financeReconciliation.ts's own contract
  /// (ADMR-85/88): never omitted, never a third value.
  final String confirmation;

  factory FinanceFinding.fromMap(Map<String, dynamic> m) => FinanceFinding(
        id: (m['id'] ?? '').toString(),
        kind: (m['kind'] ?? '').toString(),
        actorType: (m['actorType'] ?? '').toString(),
        recordId: (m['recordId'] ?? '').toString(),
        actorId: (m['actorId'] ?? '').toString(),
        amountRupees: (m['amountRupees'] as num?)?.toDouble() ?? 0,
        summary: (m['summary'] ?? '').toString(),
        detail: (m['detail'] as Map?)?.cast<String, dynamic>() ?? const {},
        confirmation: (m['confirmation'] ?? '').toString(),
      );
}

class ScanCoverageGroup {
  const ScanCoverageGroup({
    required this.inspected,
    required this.statusesCovered,
    required this.totalInStatuses,
    required this.truncated,
  });

  final int inspected;
  final List<String> statusesCovered;
  final int totalInStatuses;
  final bool truncated;

  static const ScanCoverageGroup empty =
      ScanCoverageGroup(inspected: 0, statusesCovered: [], totalInStatuses: 0, truncated: false);

  factory ScanCoverageGroup.fromMap(Map<String, dynamic>? m) {
    if (m == null) return empty;
    return ScanCoverageGroup(
      inspected: (m['inspected'] as num?)?.toInt() ?? 0,
      statusesCovered: ((m['statusesCovered'] as List?) ?? const []).map((e) => e.toString()).toList(),
      totalInStatuses: (m['totalInStatuses'] as num?)?.toInt() ?? 0,
      truncated: m['truncated'] == true,
    );
  }

  String line(String label) {
    final statuses = statusesCovered.join('/');
    final totalText = totalInStatuses == 0 && inspected == 0
        ? ''
        : (truncated ? ' of $totalInStatuses — more exist, not all inspected' : ' of $totalInStatuses');
    return '$label: $inspected$totalText ($statuses)';
  }
}

class ScanCoverage {
  const ScanCoverage({required this.sellerWithdrawals, required this.riderPayouts, required this.employeePayouts});

  final ScanCoverageGroup sellerWithdrawals;
  final ScanCoverageGroup riderPayouts;
  final ScanCoverageGroup employeePayouts;

  static const ScanCoverage empty = ScanCoverage(
    sellerWithdrawals: ScanCoverageGroup.empty,
    riderPayouts: ScanCoverageGroup.empty,
    employeePayouts: ScanCoverageGroup.empty,
  );

  factory ScanCoverage.fromMap(Map<String, dynamic>? m) => ScanCoverage(
        sellerWithdrawals: ScanCoverageGroup.fromMap((m?['sellerWithdrawals'] as Map?)?.cast<String, dynamic>()),
        riderPayouts: ScanCoverageGroup.fromMap((m?['riderPayouts'] as Map?)?.cast<String, dynamic>()),
        employeePayouts: ScanCoverageGroup.fromMap((m?['employeePayouts'] as Map?)?.cast<String, dynamic>()),
      );
}

/// One page of a scan — the repository's own return type.
class ScanPage {
  const ScanPage({
    required this.findings,
    required this.coverage,
    required this.incomplete,
    required this.incompleteReasons,
    required this.observedAt,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<FinanceFinding> findings;
  final ScanCoverage coverage;
  final bool incomplete;
  final List<String> incompleteReasons;
  final DateTime? observedAt;

  /// Opaque — see this file's own header comment. Store and replay only.
  final Map<String, dynamic>? nextCursor;
  final bool hasMore;

  factory ScanPage.fromMap(Map<String, dynamic> m) => ScanPage(
        findings: ((m['findings'] as List?) ?? const [])
            .map((e) => FinanceFinding.fromMap((e as Map).cast<String, dynamic>()))
            .toList(),
        coverage: ScanCoverage.fromMap((m['coverage'] as Map?)?.cast<String, dynamic>()),
        incomplete: m['incomplete'] == true,
        incompleteReasons: ((m['incompleteReasons'] as List?) ?? const []).map((e) => e.toString()).toList(),
        observedAt:
            m['observedAt'] is num ? DateTime.fromMillisecondsSinceEpoch((m['observedAt'] as num).toInt()) : null,
        nextCursor: (m['nextCursor'] as Map?)?.cast<String, dynamic>(),
        hasMore: m['hasMore'] == true,
      );
}

/// Thrown when the server's response doesn't parse as a ScanPage at all —
/// kept distinct from a real network/callable error so the UI can show
/// honest, different language for each ("couldn't reach the server" vs "the
/// server sent something this screen doesn't understand") instead of
/// flattening every failure into the same generic message or, worse, into
/// an empty findings list that reads as "all clear".
class MalformedScanResponseException implements Exception {
  MalformedScanResponseException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Injectable so a widget test can supply a fake without a real Firebase
/// app — mirrors FinancialRecordDetailScreen's own already-established
/// FirebaseFirestore-injection convention (ADMR-86).
abstract class FinanceReconciliationRepository {
  Future<ScanPage> scan({Map<String, dynamic>? cursor});
}

class CallableFinanceReconciliationRepository implements FinanceReconciliationRepository {
  const CallableFinanceReconciliationRepository();

  @override
  Future<ScanPage> scan({Map<String, dynamic>? cursor}) async {
    // Deliberately <dynamic>, not <Map<String, dynamic>> — the callable SDK does not actually
    // guarantee the response shape at the platform-channel boundary the way a static generic
    // parameter implies; declaring it dynamic keeps the runtime shape check below meaningful
    // instead of provably unreachable to the analyzer.
    final result =
        await FirebaseFunctions.instance.httpsCallable('financeReconciliationScan').call<dynamic>(cursor == null ? null : {'cursor': cursor});
    final data = result.data;
    if (data is! Map) {
      throw MalformedScanResponseException("The server's response could not be read.");
    }
    try {
      return ScanPage.fromMap(data.cast<String, dynamic>());
    } catch (_) {
      throw MalformedScanResponseException("The server's response could not be read.");
    }
  }
}
