import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

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
    final text = context.wsText;
    final keys = [...ApplicationRules.requiredDocuments, ...ApplicationRules.optionalDocuments];

    return StepBody(
      footer: StepFooter(
        primaryLabel: l10n.saveContinue,
        busyLabel: l10n.saving,
        busy: app.isSaving,
        onPrimary: _continue,
        onBack: app.back,
      ),
      children: [
        Text(l10n.documentsHelp, style: text.bodyLarge),
        const SizedBox(height: WsSpace.s16),
        for (final key in keys) ...[
          _DocumentTile(
            label: ApplicationCopy.document(l10n, key),
            uploaded: app.documents[key] is String,
            uploading: app.isUploading(key),
            missing: _showMissing &&
                ApplicationRules.requiredDocuments.contains(key) &&
                app.documents[key] is! String,
            onCamera: () => _pick(key, ImageSource.camera),
            onGallery: () => _pick(key, ImageSource.gallery),
          ),
          const SizedBox(height: WsSpace.s12),
        ],
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.label,
    required this.uploaded,
    required this.uploading,
    required this.missing,
    required this.onCamera,
    required this.onGallery,
  });

  final String label;
  final bool uploaded;
  final bool uploading;
  final bool missing;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final Color accent = missing ? t.errorFg : (uploaded ? t.successFg : t.textSecondary);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(WsRadius.card),
        side: BorderSide(color: missing ? t.errorFg : t.divider, width: WsSize.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(WsSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(uploaded ? AgIcons.success : AgIcons.document, color: accent, size: WsIconSize.control),
                const SizedBox(width: WsSpace.s12),
                Expanded(child: Text(label, style: text.titleSmall)),
              ],
            ),
            const SizedBox(height: WsSpace.s8),
            if (uploading)
              Row(
                children: [
                  const SizedBox.square(
                    dimension: WsIconSize.supporting,
                    child: CircularProgressIndicator(strokeWidth: WsSize.focusRing),
                  ),
                  const SizedBox(width: WsSpace.s8),
                  Text(l10n.docUploading, style: text.bodySmall),
                ],
              )
            else ...[
              if (uploaded) Text(l10n.docUploaded, style: text.bodySmall!.copyWith(color: t.successFg)),
              if (missing) Text(l10n.errDocument, style: text.bodySmall!.copyWith(color: t.errorFg)),
              Wrap(
                spacing: WsSpace.s8,
                children: [
                  TextButton.icon(
                    onPressed: onCamera,
                    icon: const Icon(AgIcons.camera, size: WsIconSize.control),
                    label: Text(uploaded ? l10n.docReplace : l10n.docTakePhoto),
                  ),
                  TextButton.icon(
                    onPressed: onGallery,
                    icon: const Icon(AgIcons.image, size: WsIconSize.control),
                    label: Text(l10n.docChoosePhoto),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
