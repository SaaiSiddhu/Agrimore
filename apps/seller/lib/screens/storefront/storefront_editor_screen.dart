import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
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
    if (_highlight.text.trim().isEmpty) return;
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
    if (ok) {
      SellerToast.show(context, AppLocalizations.of(context).storefrontSaved, tone: SellerToastTone.success);
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop(true);
    }
  }

  void _preview() {
    final d = _draft!.copyWith(shopName: _name.text, description: _description.text);
    Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => StorefrontPreviewScreen(draft: d)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.colors;
    final text = context.text;
    final d = _draft;
    Widget body;
    if (_loadFailed) {
      body = SellerErrorState(title: l10n.storefrontLoadFailed, onRetry: () {
        setState(() => _loadFailed = false);
        _load();
      });
    } else if (d == null) {
      body = SellerLoadingView(label: l10n.dsLoading);
    } else {
      final cover = d.coverImageUrl;
      const logoSize = SellerSize.storefrontLogo;
      body = SellerPage(
        gap: SellerSpace.s16,
        footer: SellerButton(label: l10n.storefrontSave, expand: true, loading: _saving, loadingLabel: l10n.saving, onPressed: _save),
        children: [
          // Cover with the logo overlapping its bottom-left corner.
          Padding(
            padding: const EdgeInsets.only(bottom: SellerSize.storefrontLogoOverlap),
            child: Stack(clipBehavior: Clip.none, children: [
              Semantics(
                button: true,
                label: cover == null ? l10n.storefrontAddCover : l10n.storefrontChangeCover,
                onTap: _uploading == null ? () => _pick('cover') : null,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: _uploading == null ? () => _pick('cover') : null,
                  child: AspectRatio(
                    aspectRatio: _coverAspect,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(SellerRadius.card),
                      child: Stack(fit: StackFit.expand, children: [
                        if (cover == null)
                          ColoredBox(color: c.primarySubtle, child: Icon(SellerIcons.imageAdd, size: SellerIconSize.xxl, color: c.primary))
                        else
                          SellerImage(url: cover, size: double.infinity, height: double.infinity, radius: 0),
                        if (_uploading == 'cover') ColoredBox(color: c.scrim, child: Center(child: SellerSpinner(color: c.onPrimary))),
                      ]),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: SellerSpace.s12,
                bottom: SellerSpace.s12,
                child: SellerButton.tonal(label: l10n.storefrontEditPhoto, icon: SellerIcons.camera, compact: true, expand: false, onPressed: _uploading == null ? () => _pick('cover') : null),
              ),
              Positioned(
                left: SellerSpace.s16,
                bottom: -SellerSize.storefrontLogoOverlap,
                child: Semantics(
                  button: true,
                  label: d.logoUrl == null ? l10n.storefrontAddLogo : l10n.storefrontChangeLogo,
                  onTap: _uploading == null ? () => _pick('logo') : null,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: _uploading == null ? () => _pick('logo') : null,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.surface, width: SellerSpace.s4)),
                        child: SellerAvatar(imageUrl: d.logoUrl, name: _name.text, size: logoSize),
                      ),
                      if (_uploading == 'logo')
                        Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: c.scrim, shape: BoxShape.circle), child: Center(child: SellerSpinner(color: c.onPrimary)))),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(SellerSpace.s6),
                          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle, border: Border.all(color: c.surface, width: SellerSize.focus)),
                          child: Icon(SellerIcons.camera, size: SellerIconSize.sm, color: c.onPrimary),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          Text(l10n.storefrontLogoHint, style: text.bodyMedium),
          SellerTextField(
            fieldKey: const ValueKey('storefrontName'),
            label: l10n.storefrontName,
            required: true,
            controller: _name,
            maxLength: kStorefrontNameMax,
            onChanged: (_) => setState(() {}),
            errorText: d.nameValid || _name.text.trim().isNotEmpty ? null : l10n.storefrontNameRequired,
          ),
          SellerTextField(
            fieldKey: const ValueKey('storefrontDescription'),
            label: l10n.storefrontDescription,
            controller: _description,
            maxLength: kStorefrontDescriptionMax,
            showCounter: true,
            minLines: 3,
            maxLines: 6,
          ),
          SellerSectionHeader(
            title: l10n.storefrontHighlights(kStorefrontHighlightsMax),
            subtitle: l10n.storefrontHighlightCount(d.highlights.length, kStorefrontHighlightsMax),
          ),
          if (d.highlights.isNotEmpty)
            Wrap(spacing: SellerSpace.s8, runSpacing: SellerSpace.s4, children: [
              for (final h in d.highlights)
                SellerChip(
                  label: h,
                  selected: true,
                  style: SellerChipStyle.toggle,
                  onSelected: null,
                  onRemove: () => setState(() => _draft = d.withoutHighlight(h)),
                  removeLabel: l10n.storefrontRemoveHighlight(h),
                ),
            ]),
          if (d.highlights.length < kStorefrontHighlightsMax)
            SellerTextField(
              fieldKey: const ValueKey('storefrontHighlight'),
              label: l10n.storefrontAddHighlight,
              hint: l10n.storefrontHighlightHint,
              controller: _highlight,
              maxLength: kStorefrontHighlightChars,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addHighlight(),
              trailing: IconButton(tooltip: l10n.storefrontAddHighlight, icon: const Icon(SellerIcons.add), onPressed: _addHighlight),
            ),
          if (_saveFailed) SellerBanner(tone: SellerTone.danger, message: l10n.storefrontSaveFailed, announce: true),
        ],
      );
    }
    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.storefrontTitle, actions: [
        if (d != null) SellerButton.tertiary(label: l10n.storefrontPreview, icon: SellerIcons.eye, compact: true, onPressed: _preview),
      ]),
      body: body,
    );
  }
}

/// Full-screen buyer preview (board 22-07). Nothing is published from here.
class StorefrontPreviewScreen extends StatelessWidget {
  const StorefrontPreviewScreen({super.key, required this.draft});
  final StorefrontDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.storefrontPreviewTitle, close: true),
      body: SellerPage(
        gap: SellerSpace.s16,
        children: [
          StorefrontPreview(draft: draft),
          SellerBanner(tone: SellerTone.info, title: l10n.storefrontPreviewOnly, message: l10n.storefrontPreviewNote),
        ],
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
    final c = context.colors;
    final text = context.text;
    final cover = draft.coverImageUrl;
    return SellerCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: cover == null ? ColoredBox(color: c.primarySubtle) : SellerImage(url: cover, size: double.infinity, height: double.infinity, radius: 0),
        ),
        Padding(
          padding: const EdgeInsets.all(SellerSpace.s16),
          child: Column(children: [
            SellerAvatar(imageUrl: draft.logoUrl, name: draft.shopName, size: SellerSize.avatarXl),
            const SizedBox(height: SellerSpace.s8),
            Text(draft.shopName.trim().isEmpty ? l10n.storefrontName : draft.shopName, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: SellerSpace.s8),
            SellerStatusBadge(label: l10n.storefrontPreview, tone: SellerTone.brand, icon: SellerIcons.eye),
            if (draft.description.trim().isNotEmpty) ...[
              const SizedBox(height: SellerSpace.s12),
              Text(draft.description.trim(), style: text.bodyLarge, textAlign: TextAlign.center),
            ],
            if (draft.highlights.isNotEmpty) ...[
              const SizedBox(height: SellerSpace.s12),
              Wrap(alignment: WrapAlignment.center, spacing: SellerSpace.s8, runSpacing: SellerSpace.s8, children: [
                for (final h in draft.highlights) SellerStatusBadge(label: h, tone: SellerTone.brand, icon: SellerIcons.check),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}
