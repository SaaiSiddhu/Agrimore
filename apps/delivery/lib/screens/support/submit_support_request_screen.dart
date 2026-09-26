// lib/screens/support/submit_support_request_screen.dart
//
// Phase DLVSUP1 -- the submit-a-request form (31.4 panel 3). Category
// starts as whichever topic was tapped on HelpSupportScreen but stays
// changeable, matching the mockup's own dropdown. "Related to" (a specific
// order or statement) is NOT offered here -- no picker screen exists yet;
// see this phase's ledger row for why. Message + an optional single
// attachment (uploaded immediately on pick, matching delivery_problems.dart's
// own upload-then-attach convention).
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../support/rider_support.dart';
import 'support_request_status_screen.dart';

String _categoryLabel(AppLocalizations l, String category) => switch (category) {
      kSupportCategoryEarningsPayouts => l.helpTopicEarningsPayouts,
      kSupportCategoryAccountDocuments => l.helpTopicAccountDocuments,
      _ => l.helpTopicDeliveryIssue,
    };

class SubmitSupportRequestScreen extends StatefulWidget {
  const SubmitSupportRequestScreen({
    super.key,
    required this.category,
    this.backend,
    this.pickImage,
  });
  final String category;

  /// Injectable for tests; defaults to the real callable-backed service.
  final RiderSupportBackend? backend;

  /// Injectable for tests (image_picker has no test-friendly platform
  /// channel); defaults to a real gallery pick.
  final Future<XFile?> Function()? pickImage;

  @override
  State<SubmitSupportRequestScreen> createState() => _SubmitSupportRequestScreenState();
}

class _SubmitSupportRequestScreenState extends State<SubmitSupportRequestScreen> {
  late final RiderSupportBackend _backend = widget.backend ?? CallableRiderSupportBackend();
  late final Future<XFile?> Function() _pickImage = widget.pickImage ??
      () => ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1200);
  final _requestId = newSupportRequestId();
  final _messageController = TextEditingController();
  late String _category = widget.category;
  String? _attachmentPath;
  String? _messageError;
  bool _saving = false;
  bool _pickingAttachment = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _addAttachment() async {
    setState(() => _pickingAttachment = true);
    try {
      final photo = await _pickImage();
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      final path = await _backend.uploadAttachment(_requestId, bytes, 'image/jpeg');
      if (mounted) setState(() => _attachmentPath = path);
    } catch (e) {
      if (mounted) {
        showDeliveryToast(
          context,
          message: AppLocalizations.of(context).supportAttachmentFailed,
          tone: DeliveryBannerTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _pickingAttachment = false);
    }
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final message = _messageController.text.trim();
    if (message.length < 3 || message.length > 500) {
      setState(() => _messageError = l.errSupportMessage);
      return;
    }
    setState(() {
      _saving = true;
      _messageError = null;
    });
    try {
      final ticketId = await _backend.submit(
        requestId: _requestId,
        category: _category,
        message: message,
        attachmentPath: _attachmentPath,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => SupportRequestStatusScreen(ticketId: ticketId, backend: widget.backend),
          ),
        );
      }
    } on SupportRequestException catch (e) {
      if (mounted) {
        showDeliveryToast(
          context,
          message: switch (e.failure) {
            SupportRequestFailure.network => l.identityChangeNetworkError,
            _ => l.identityChangeInvalid,
          },
          tone: DeliveryBannerTone.danger,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text(l.supportSubmitTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(DeliverySpace.page),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('support-category'),
              initialValue: _category,
              decoration: InputDecoration(labelText: l.supportCategoryLabel),
              items: [
                for (final cat in kSupportCategories)
                  DropdownMenuItem(value: cat, child: Text(_categoryLabel(l, cat))),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: DeliverySpace.md),
            TextField(
              key: const ValueKey('support-message'),
              controller: _messageController,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: l.supportMessageLabel,
                hintText: l.supportMessageHint,
                errorText: _messageError,
                errorMaxLines: 2,
              ),
            ),
            const SizedBox(height: DeliverySpace.sm),
            Text(l.supportAttachmentLabel, style: t.labelMedium.copyWith(color: c.textSecondary)),
            const SizedBox(height: DeliverySpace.sm),
            if (_attachmentPath != null)
              DeliveryCard(
                padding: const EdgeInsets.symmetric(horizontal: DeliverySpace.md, vertical: DeliverySpace.sm),
                child: Row(
                  children: [
                    Icon(DeliveryIcons.document, size: DeliveryIconSize.md, color: c.textSecondary),
                    const SizedBox(width: DeliverySpace.sm),
                    Expanded(child: Text(_attachmentPath!.split('/').last, style: t.bodyMedium.copyWith(color: c.textPrimary))),
                    IconButton(
                      key: const ValueKey('support-remove-attachment'),
                      icon: Icon(DeliveryIcons.close, size: DeliveryIconSize.md),
                      tooltip: l.supportRemoveAttachment,
                      onPressed: () => setState(() => _attachmentPath = null),
                    ),
                  ],
                ),
              )
            else
              DeliveryButton.secondary(
                key: const ValueKey('support-add-attachment'),
                label: l.supportAddAttachment,
                icon: DeliveryIcons.document,
                isLoading: _pickingAttachment,
                onPressed: _pickingAttachment ? null : _addAttachment,
              ),
            const SizedBox(height: DeliverySpace.lg),
            DeliveryButton.primary(
              key: const ValueKey('support-submit'),
              label: l.supportSubmitButton,
              isLoading: _saving,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
