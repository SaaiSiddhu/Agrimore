import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../design_system/design_system.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/seller_application_provider.dart';
import '../application_rules.dart';
import '../application_screen.dart';
import '../widgets/application_copy.dart';
import '../widgets/step_footer.dart';

/// Step 3 — KYC photos to seller_documents/{uid}/ (owner write, image only,
/// ≤ 10 MB; owner + admin read — storage.rules, unchanged).
class DocumentsStep extends StatefulWidget {
  const DocumentsStep({super.key});

  @override
  State<DocumentsStep> createState() => _DocumentsStepState();
}

class _DocumentsStepState extends State<DocumentsStep> {
  static const int _imageQuality = 70;
  static const double _maxDimension = 1600;

  bool _showMissing = false;

  Future<void> _pick(String key, ImageSource source) async {
    final app = context.read<SellerApplicationProvider>();
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: _imageQuality,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
    );
    if (file == null) return;
    await app.uploadDocument(key, await file.readAsBytes());
  }

  Future<void> _continue() async {
    final app = context.read<SellerApplicationProvider>();
    final missing = ApplicationRules.documents(app.data, app.uid ?? '');
    if (missing.isNotEmpty) {
      setState(() => _showMissing = true);
      return;
    }
    await app.saveAndAdvance(const {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final app = context.watch<SellerApplicationProvider>();
    final keys = [...ApplicationRules.requiredDocuments, ...ApplicationRules.optionalDocuments];
    final anyMissing = _showMissing && ApplicationRules.requiredDocuments.any((k) => app.documents[k] is! String);

    return StepBody(
      footer: StepFooter(primaryLabel: l10n.saveContinue, busyLabel: l10n.saving, busy: app.isSaving, onPrimary: _continue, onBack: app.back),
      children: [
        Text(l10n.documentsHelp, style: context.text.bodyLarge),
        const SizedBox(height: SellerSpace.s16),
        if (anyMissing) ...[
          SellerBanner(tone: SellerTone.danger, message: l10n.errDocument, announce: true),
          const SizedBox(height: SellerSpace.s12),
        ],
        for (final key in keys) ...[
          _DocumentTile(
            label: ApplicationCopy.document(l10n, key),
            // The ID-proof and GST labels already name what is accepted.
            hint: key == 'shopPhoto' ? l10n.docShopPhotoHint : null,
            optional: !ApplicationRules.requiredDocuments.contains(key),
            uploaded: app.documents[key] is String,
            uploading: app.isUploading(key),
            missing: _showMissing && ApplicationRules.requiredDocuments.contains(key) && app.documents[key] is! String,
            onCamera: () => _pick(key, ImageSource.camera),
            onGallery: () => _pick(key, ImageSource.gallery),
          ),
          const SizedBox(height: SellerSpace.s12),
        ],
        Text(l10n.docUploadedNote, style: context.text.bodySmall),
      ],
    );
  }
}

/// Document card (board 16-04): icon or ✓, title (+ optional), what it is,
/// state (Uploading… / ✓ Uploaded / missing), Take photo · Choose from gallery.
class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.label,
    required this.hint,
    required this.optional,
    required this.uploaded,
    required this.uploading,
    required this.missing,
    required this.onCamera,
    required this.onGallery,
  });

  final String label;
  final String? hint;
  final bool optional;
  final bool uploaded;
  final bool uploading;
  final bool missing;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    return Container(
      padding: const EdgeInsets.all(SellerSpace.s16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SellerRadius.card),
        border: Border.all(color: missing ? c.danger : c.border, width: missing ? SellerSize.focus : SellerSize.hairline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MergeSemantics(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SellerIconTile(
              icon: uploaded ? SellerIcons.success : SellerIcons.document,
              tone: missing ? SellerTone.danger : (uploaded ? SellerTone.success : SellerTone.brand),
              size: SellerSize.thumbMd,
            ),
            const SizedBox(width: SellerSpace.s12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: text.titleSmall),
                if (hint != null) Text(hint!, style: text.bodyMedium),
                const SizedBox(height: SellerSpace.s4),
                if (uploading)
                  SellerProgressLabel(label: l10n.docUploading, center: false)
                else if (uploaded)
                  SellerStatusBadge(label: l10n.docUploaded, tone: SellerTone.success, icon: SellerIcons.success)
                else if (missing)
                  SellerFieldMessage(message: l10n.errDocument),
              ]),
            ),
          ]),
        ),
        if (!uploading) ...[
          const SizedBox(height: SellerSpace.s12),
          Wrap(spacing: SellerSpace.s8, runSpacing: SellerSpace.s8, children: [
            SellerButton.secondary(label: uploaded ? l10n.docReplace : l10n.docTakePhoto, icon: uploaded ? SellerIcons.replace : SellerIcons.camera, compact: true, expand: false, onPressed: onCamera),
            SellerButton.secondary(label: l10n.docChoosePhoto, icon: SellerIcons.image, compact: true, expand: false, onPressed: onGallery),
          ]),
        ],
      ]),
    );
  }
}
