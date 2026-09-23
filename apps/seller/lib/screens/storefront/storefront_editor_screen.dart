import 'dart:typed_data';

import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import 'storefront_rules.dart';

/// Saves a draft; injected in tests.
typedef StorefrontSaver = Future<bool> Function(StorefrontDraft draft);

/// Uploads an image and returns its URL; injected in tests.
typedef StorefrontUploader = Future<String?> Function(String kind, Uint8List bytes);

/// M-02 Storefront editor (ADR §10.6, SELLER-STOREFRONT-EDIT-1): cover,
/// logo, shop name, description, up to three highlights, and a live
/// "Preview as buyer". Writes only the owner-editable keys on sellers/{uid}.
class StorefrontEditorScreen extends StatefulWidget {
  const StorefrontEditorScreen({super.key, this.initial, this.saver, this.uploader});

  final StorefrontDraft? initial;
  final StorefrontSaver? saver;
  final StorefrontUploader? uploader;

  @override
  State<StorefrontEditorScreen> createState() => _StorefrontEditorScreenState();
}

class _StorefrontEditorScreenState extends State<StorefrontEditorScreen> {
  static const double _coverAspect = 16 / 9;
  static const int _imageQuality = 82;
  static const double _coverMaxWidth = 1600;
  static const double _logoMaxWidth = 600;

  StorefrontDraft? _draft;
  bool _loadFailed = false;
  bool _saving = false;
  bool _saveFailed = false;
  String? _uploading;
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _highlight = TextEditingController();

  String? get _uid => context.read<SellerAuthProvider>().currentUser?.uid;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _apply(initial);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  void _apply(StorefrontDraft d) {
    _draft = d;
    _name.text = d.shopName;
    _description.text = d.description;
  }

  Future<void> _load() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('sellers').doc(uid).get();
      if (mounted) setState(() => _apply(StorefrontDraft.fromSeller(snap.data())));
    } catch (e) {
      debugPrint('Storefront load failed: $e');
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _highlight.dispose();
    super.dispose();
  }

  Future<bool> _defaultSave(StorefrontDraft d) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      await FirebaseFirestore.instance
          .collection('sellers')
          .doc(uid)
          .update({...d.toUpdate(), 'updatedAt': FieldValue.serverTimestamp()});
      return true;
    } catch (e) {
      debugPrint('Storefront save failed: $e');
      return false;
    }
  }

  Future<String?> _defaultUpload(String kind, Uint8List bytes) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref(storefrontImagePath(uid, kind, DateTime.now().millisecondsSinceEpoch));
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Storefront upload failed: $e');
      return null;
    }
  }

  Future<void> _pick(String kind) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: _imageQuality,
      maxWidth: kind == 'cover' ? _coverMaxWidth : _logoMaxWidth,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _uploading = kind;
      _saveFailed = false;
    });
    final url = await (widget.uploader ?? _defaultUpload)(kind, bytes);
    if (!mounted) return;
    setState(() {
      _uploading = null;
      if (url == null) {
        _saveFailed = true;
      } else {
        _draft = kind == 'cover' ? _draft!.copyWith(coverImageUrl: url) : _draft!.copyWith(logoUrl: url);
      }
    });
  }

  void _addHighlight() {
    setState(() => _draft = _draft!.withHighlight(_highlight.text));
    _highlight.clear();
  }

  Future<void> _save() async {
    final d = _draft!.copyWith(shopName: _name.text, description: _description.text);
    if (!d.isValid) {
      setState(() => _draft = d);
      return;
    }
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    final ok = await (widget.saver ?? _defaultSave)(d);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveFailed = !ok;
      _draft = d;
    });
    if (ok) Navigator.of(context).maybePop(true);
  }

  void _preview() {
    final d = _draft!.copyWith(shopName: _name.text, description: _description.text);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(child: SingleChildScrollView(child: StorefrontPreview(draft: d))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final d = _draft;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.back,
          icon: const Icon(AgIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.storefrontTitle),
        actions: [
          if (d != null) TextButton(onPressed: _preview, child: Text(l10n.storefrontPreview)),
        ],
      ),
      body: _loadFailed
          ? Padding(
              padding: const EdgeInsets.all(WsSpace.page),
              child: SaInfoBanner(variant: SaBannerVariant.error, message: l10n.storefrontLoadFailed),
            )
          : d == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(WsSpace.page),
                  children: [
                    Text(l10n.storefrontCover, style: text.labelLarge),
                    const SizedBox(height: WsSpace.s8),
                    _ImageSlot(
                      aspectRatio: _coverAspect,
                      url: d.coverImageUrl,
                      busy: _uploading == 'cover',
                      label: d.coverImageUrl == null ? l10n.storefrontAddCover : l10n.storefrontChangeCover,
                      onTap: () => _pick('cover'),
                    ),
                    const SizedBox(height: WsSpace.s16),
                    Row(children: [
                      SizedBox.square(
                        dimension: WsSize.avatarLg * 2,
                        child: _ImageSlot(
                          aspectRatio: 1,
                          url: d.logoUrl,
                          busy: _uploading == 'logo',
                          label: d.logoUrl == null ? l10n.storefrontAddLogo : l10n.storefrontChangeLogo,
                          onTap: () => _pick('logo'),
                        ),
                      ),
                      const SizedBox(width: WsSpace.s16),
                      Expanded(child: Text(l10n.storefrontLogoHint, style: text.bodySmall!.copyWith(color: t.textSecondary))),
                    ]),
                    const SizedBox(height: WsSpace.s24),
                    TextField(
                      key: const ValueKey('storefrontName'),
                      controller: _name,
                      maxLength: kStorefrontNameMax,
                      decoration: InputDecoration(
                        labelText: l10n.storefrontName,
                        errorText: d.nameValid || _name.text.trim().isNotEmpty ? null : l10n.storefrontNameRequired,
                      ),
                    ),
                    const SizedBox(height: WsSpace.s8),
                    TextField(
                      key: const ValueKey('storefrontDescription'),
                      controller: _description,
                      maxLength: kStorefrontDescriptionMax,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(labelText: l10n.storefrontDescription, alignLabelWithHint: true),
                    ),
                    const SizedBox(height: WsSpace.s16),
                    Text(l10n.storefrontHighlights(kStorefrontHighlightsMax), style: text.labelLarge),
                    const SizedBox(height: WsSpace.s8),
                    Wrap(spacing: WsSpace.s8, runSpacing: WsSpace.s8, children: [
                      for (final h in d.highlights)
                        InputChip(
                          label: Text(h),
                          onDeleted: () => setState(() => _draft = d.withoutHighlight(h)),
                          deleteButtonTooltipMessage: l10n.storefrontRemoveHighlight(h),
                        ),
                    ]),
                    if (d.highlights.length < kStorefrontHighlightsMax) ...[
                      const SizedBox(height: WsSpace.s8),
                      TextField(
                        key: const ValueKey('storefrontHighlight'),
                        controller: _highlight,
                        maxLength: kStorefrontHighlightChars,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addHighlight(),
                        decoration: InputDecoration(
                          labelText: l10n.storefrontAddHighlight,
                          hintText: l10n.storefrontHighlightHint,
                          suffixIcon: IconButton(
                            tooltip: l10n.storefrontAddHighlight,
                            icon: const Icon(AgIcons.add),
                            onPressed: _addHighlight,
                          ),
                        ),
                      ),
                    ],
                    if (_saveFailed) ...[
                      const SizedBox(height: WsSpace.s8),
                      SaInfoBanner(variant: SaBannerVariant.error, message: l10n.storefrontSaveFailed),
                    ],
                    const SizedBox(height: WsSpace.s24),
                    SaLoadingButton(text: l10n.storefrontSave, isLoading: _saving, onPressed: _saving ? null : _save),
                  ],
                ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  const _ImageSlot({required this.aspectRatio, required this.url, required this.busy, required this.label, required this.onTap});
  final double aspectRatio;
  final String? url;
  final bool busy;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ws;
    final image = url;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(WsRadius.card),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(WsRadius.card),
            child: Stack(fit: StackFit.expand, children: [
              if (image == null)
                ColoredBox(color: t.surfaceSunken, child: Icon(AgIcons.image, color: t.textTertiary, size: WsIconSize.feature))
              else
                Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: t.surfaceSunken)),
              if (busy) ColoredBox(color: t.scrim, child: const Center(child: CircularProgressIndicator())),
              Positioned(
                right: WsSpace.s8,
                bottom: WsSpace.s8,
                child: ExcludeSemantics(
                  child: CircleAvatar(
                    radius: WsIconSize.control,
                    backgroundColor: t.surface,
                    child: Icon(AgIcons.camera, size: WsIconSize.supporting, color: t.primary),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// How the marketplace storefront header will look to a buyer.
class StorefrontPreview extends StatelessWidget {
  const StorefrontPreview({super.key, required this.draft});
  final StorefrontDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final cover = draft.coverImageUrl;
    final logo = draft.logoUrl;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.all(WsSpace.page),
        child: Text(l10n.storefrontPreviewTitle, style: text.titleMedium),
      ),
      AspectRatio(
        aspectRatio: 16 / 9,
        child: cover == null
            ? ColoredBox(color: t.primarySubtle)
            : Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: t.primarySubtle)),
      ),
      Padding(
        padding: const EdgeInsets.all(WsSpace.page),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: WsSize.avatarLg / 2,
              backgroundColor: t.surfaceSunken,
              backgroundImage: logo == null ? null : NetworkImage(logo),
              child: logo == null ? Icon(AgIcons.store, color: t.textTertiary) : null,
            ),
            const SizedBox(width: WsSpace.s12),
            Expanded(child: Text(draft.shopName.trim().isEmpty ? l10n.storefrontName : draft.shopName, style: text.titleLarge)),
          ]),
          if (draft.highlights.isNotEmpty) ...[
            const SizedBox(height: WsSpace.s12),
            Wrap(spacing: WsSpace.s8, runSpacing: WsSpace.s8, children: [
              for (final h in draft.highlights) Chip(label: Text(h), avatar: Icon(AgIcons.success, size: WsIconSize.supporting, color: t.primary)),
            ]),
          ],
          if (draft.description.trim().isNotEmpty) ...[
            const SizedBox(height: WsSpace.s12),
            Text(draft.description.trim(), style: text.bodyMedium),
          ],
        ]),
      ),
    ]);
  }
}
