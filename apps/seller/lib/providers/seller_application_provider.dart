import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../screens/onboarding/application_rules.dart';

/// Outcome of a submit attempt.
enum SubmitOutcome { submitted, invalid, failed }

/// The seller's in-app application (ADR-S12, A-05): a `draft` in
/// sellerRequests/{uid}, saved step by step; KYC photos in
/// seller_documents/{uid}/; submitted only through the
/// `submitSellerApplication` callable (firestore.rules never let the client
/// set anything but `draft`).
class SellerApplicationProvider with ChangeNotifier {
  SellerApplicationProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  /// Frozen in-memory state for widget tests — no Firebase behind it.
  @visibleForTesting
  SellerApplicationProvider.preview({Map<String, dynamic>? data, String uid = 'preview-uid', int step = 0})
      : _auth = null,
        _firestore = null,
        _storage = null,
        _functions = null,
        _previewUid = uid {
    _data = {...?data};
    _step = step;
    _loaded = true;
  }

  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final FirebaseStorage? _storage;
  final FirebaseFunctions? _functions;
  String? _previewUid;

  static const int stepCount = 5;
  static const String _collection = 'sellerRequests';
  static const String _documentsRoot = 'seller_documents';
  static const String _imageContentType = 'image/jpeg';

  Map<String, dynamic> _data = {};
  int _step = 0;
  bool _loaded = false;
  bool _saving = false;
  final Set<String> _uploading = {};
  List<String> _serverProblems = const [];
  bool _failed = false;

  Map<String, dynamic> get data => Map.unmodifiable(_data);
  int get step => _step;
  bool get isLoaded => _loaded;
  bool get isSaving => _saving;
  bool isUploading(String key) => _uploading.contains(key);
  List<String> get serverProblems => _serverProblems;
  bool get lastActionFailed => _failed;
  String? get uid => _previewUid ?? _auth?.currentUser?.uid;

  Map<String, dynamic> get documents => (_data['documents'] as Map?)?.cast<String, dynamic>() ?? {};

  DocumentReference<Map<String, dynamic>>? get _ref {
    final id = uid;
    final db = _firestore;
    if (id == null || db == null) return null;
    return db.collection(_collection).doc(id);
  }

  /// Loads an existing draft, or creates one prefilled from the signed-in
  /// account. Resumes at the first step that still has problems.
  Future<void> loadOrStart() async {
    final ref = _ref;
    final user = _auth?.currentUser;
    if (ref == null || user == null) return;
    try {
      final snap = await ref.get();
      if (snap.exists) {
        _data = snap.data()!;
      } else {
        _data = {
          'userId': user.uid,
          'status': 'draft',
          'name': user.displayName ?? '',
          'mobile': user.phoneNumber ?? '',
          'email': user.email ?? '',
          'deliveryRadiusKm': ApplicationRules.defaultRadiusKm,
          'payoutMethod': 'bank',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };
        await ref.set(_data);
        _data = (await ref.get()).data() ?? _data;
      }
      _step = _firstIncompleteStep();
      _failed = false;
    } catch (e) {
      debugPrint('Application load failed: $e');
      _failed = true;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  int _firstIncompleteStep() {
    final id = uid ?? '';
    if (ApplicationRules.business(_data).isNotEmpty) return 0;
    if (ApplicationRules.location(_data).isNotEmpty) return 1;
    if (ApplicationRules.documents(_data, id).isNotEmpty) return 2;
    if (ApplicationRules.payout(_data).isNotEmpty) return 3;
    return 4;
  }

  /// Merges [fields] into the draft and saves it (always as `draft`).
  Future<bool> save(Map<String, dynamic> fields) async {
    _data = {..._data, ...fields};
    final ref = _ref;
    if (ref == null) {
      notifyListeners();
      return true;
    }
    _saving = true;
    _failed = false;
    notifyListeners();
    try {
      await ref.set({
        ...fields,
        'userId': uid,
        'status': 'draft',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Application save failed: $e');
      _failed = true;
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> saveAndAdvance(Map<String, dynamic> fields) async {
    final ok = await save(fields);
    if (ok && _step < stepCount - 1) {
      _step++;
      notifyListeners();
    }
    return ok;
  }

  void back() {
    if (_step > 0) {
      _step--;
      notifyListeners();
    }
  }

  void goTo(int step) {
    _step = step.clamp(0, stepCount - 1);
    notifyListeners();
  }

  /// Uploads one KYC photo to the seller's own folder and records its path.
  Future<bool> uploadDocument(String key, Uint8List bytes) async {
    final id = uid;
    final storage = _storage;
    if (id == null || storage == null) return false;
    _uploading.add(key);
    _failed = false;
    notifyListeners();
    try {
      final path = '$_documentsRoot/$id/${key}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await storage.ref(path).putData(bytes, SettableMetadata(contentType: _imageContentType));
      final docs = {...documents, key: path};
      return await save({'documents': docs});
    } catch (e) {
      debugPrint('Document upload failed: $e');
      _failed = true;
      return false;
    } finally {
      _uploading.remove(key);
      notifyListeners();
    }
  }

  /// Submits through the callable. On `invalid`, [serverProblems] lists the
  /// fields the server rejected.
  Future<SubmitOutcome> submit() async {
    final functions = _functions;
    if (functions == null) return SubmitOutcome.failed;
    _saving = true;
    _serverProblems = const [];
    _failed = false;
    notifyListeners();
    try {
      await functions.httpsCallable('submitSellerApplication').call<dynamic>();
      return SubmitOutcome.submitted;
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      if (e.code == 'invalid-argument' && details is Map && details['problems'] is List) {
        _serverProblems = (details['problems'] as List).map((p) => '$p').toList();
        _step = _stepForProblem(_serverProblems.first);
        return SubmitOutcome.invalid;
      }
      _failed = true;
      return SubmitOutcome.failed;
    } catch (e) {
      debugPrint('Submit failed: $e');
      _failed = true;
      return SubmitOutcome.failed;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  static int _stepForProblem(String key) {
    if (['name', 'shopName', 'businessCategory', 'gstin'].contains(key)) return 0;
    if (['shopAddress', 'city', 'state', 'pincode', 'deliveryRadiusKm'].contains(key)) return 1;
    if (key.startsWith('documents.')) return 2;
    if (['payoutMethod', 'accountHolder', 'bankName', 'accountNumber', 'ifsc', 'upiId'].contains(key)) return 3;
    return 4;
  }

  /// Rejected → draft, so the seller can fix and resubmit (rules allow it).
  Future<bool> reopenAfterRejection() async {
    final ref = _ref;
    if (ref == null) return false;
    try {
      await ref.update({'status': 'draft', 'userId': uid, 'updatedAt': FieldValue.serverTimestamp()});
      return true;
    } catch (e) {
      debugPrint('Reopen failed: $e');
      return false;
    }
  }
}
