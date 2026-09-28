// lib/screens/profile/document_submission_screen.dart
//
// Phase DLVC3 -- the rider-facing destination a document-review notification
// (`document_review_approved`/`document_review_rejected`) actually names:
// the EXACT submission that notification was about, not "whichever
// document is currently pending" (Profile's own Documents section already
// shows that, and stays the right place for a rider who did not arrive via
// a specific notification). Mirrors IdentityChangeScreen's own by-id
// precedent -- the same RequestStatusCard shape, the same
// missing-means-honestly-unavailable behaviour for a deleted/legacy/
// not-this-rider's id (ownership itself is enforced by firestore.rules,
// never re-derived here).
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../design_system/design_system.dart';
import '../../identity/rider_document_review.dart';
import '../../l10n/app_localizations.dart';
import 'identity_change_screen.dart' show RequestStatusCard;

String _docLabel(AppLocalizations l, String docType) => switch (docType) {
      'aadhaarFront' => l.docAadhaarFront,
      'aadhaarBack' => l.docAadhaarBack,
      'selfie' => l.docSelfie,
      'license' => l.docLicense,
      _ => docType,
    };

class DocumentSubmissionScreen extends StatefulWidget {
  const DocumentSubmissionScreen({
    super.key,
    required this.submissionId,
    this.backend,
    this.pickReplacementPhoto,
  });

  /// DLVC3: pins this screen to the EXACT submission a notification named --
  /// never "whichever is latest", which can silently be a different, newer
  /// submission for the same document made since the notification arrived.
  final String submissionId;

  /// Injectable for tests; defaults to the real callable-backed service.
  final RiderDocumentReviewBackend? backend;

  /// Injectable for tests; defaults to the real image picker.
  final Future<({Uint8List bytes, String contentType})?> Function(String docType)? pickReplacementPhoto;

  @override
  State<DocumentSubmissionScreen> createState() => _DocumentSubmissionScreenState();
}

class _DocumentSubmissionScreenState extends State<DocumentSubmissionScreen> {
  late final RiderDocumentReviewBackend _backend = widget.backend ?? CallableRiderDocumentReviewBackend();
  bool _replacing = false;

  Future<({Uint8List bytes, String contentType})?> _defaultPick(String docType) async {
    final file = await ImagePicker().pickImage(
      source: docType == 'selfie' ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) return null;
    return (bytes: await file.readAsBytes(), contentType: file.mimeType ?? 'image/jpeg');
  }

  /// DLVC3: resubmitting from here creates a NEW, separate submission this
  /// screen's own by-id stream (pinned to the OLD, now-superseded id) would
  /// never see reflected -- pop rather than keep showing the old, decided
  /// one. Profile's own Documents section already shows the fresh pending
  /// state under the ordinary "current status per document" view.
  Future<void> _replace(String docType) async {
    final l = AppLocalizations.of(context);
    final pick = widget.pickReplacementPhoto ?? _defaultPick;
    final photo = await pick(docType);
    if (photo == null || !mounted) return;
    setState(() => _replacing = true);
    try {
      await _backend.submitReplacement(docType: docType, bytes: photo.bytes, contentType: photo.contentType);
      if (mounted) {
        showDeliveryToast(context, message: l.docReplaceSubmitted, tone: DeliveryBannerTone.success);
        Navigator.of(context).pop();
      }
    } on DocumentReplacementException catch (e) {
      if (!mounted) return;
      final message = switch (e.failure) {
        DocumentReplacementFailure.alreadyPending => l.docReplaceAlreadyPending,
        DocumentReplacementFailure.network => l.docReplaceNetworkError,
        _ => l.docReplaceFailed,
      };
      showDeliveryToast(context, message: message, tone: DeliveryBannerTone.warning);
    } finally {
      if (mounted) setState(() => _replacing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(l.documentSubmissionTitle)),
      body: StreamBuilder<DocumentSubmission?>(
        stream: _backend.submissionById(widget.submissionId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // A permission-denied read (not this rider's submission -- the
          // security rule's own job, never re-checked here) and a genuinely
          // deleted/missing document both read as the SAME honest "not
          // available" card: neither is safe or useful to distinguish to
          // the rider, and distinguishing them would mean guessing at a
          // reason this client cannot actually confirm.
          final sub = snap.hasError ? null : snap.data;
          if (sub == null) {
            return RequestStatusCard(
              icon: DeliveryIcons.close,
              title: l.documentSubmissionUnavailable,
              body: l.documentSubmissionUnavailableBody,
            );
          }
          final label = _docLabel(l, sub.docType);
          final card = switch (sub.status) {
            DocumentReviewStatus.approved => RequestStatusCard(
                icon: DeliveryIcons.checkCircle,
                title: l.documentSubmissionApprovedTitle,
                body: sub.reviewedAt != null
                    ? l.documentSubmissionReviewedOn(DeliveryFormat.dateTime(sub.reviewedAt!.toLocal()))
                    : '',
              ),
            DocumentReviewStatus.rejected => RequestStatusCard(
                icon: DeliveryIcons.close,
                title: l.documentSubmissionRejectedTitle,
                body: sub.rejectionReason ?? '',
                action: DeliveryButton.primary(
                  key: const ValueKey('document-submission-replace'),
                  label: l.docReplaceAction,
                  isLoading: _replacing,
                  onPressed: _replacing ? null : () => _replace(sub.docType),
                ),
              ),
            _ => RequestStatusCard(
                icon: DeliveryIcons.clock,
                title: l.documentSubmissionPendingTitle,
                body: l.documentSubmissionPendingBody,
              ),
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(DeliverySpace.page, DeliverySpace.md, DeliverySpace.page, 0),
                child: Text(label, style: t.titleMedium.copyWith(color: c.textPrimary)),
              ),
              Expanded(child: card),
            ],
          );
        },
      ),
    );
  }
}
