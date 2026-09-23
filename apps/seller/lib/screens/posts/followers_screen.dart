import 'package:agrimore_ui/agrimore_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/seller_auth_provider.dart';
import 'create_post_screen.dart';

/// One of the seller's posts (business_posts).
@immutable
class SellerPost {
  const SellerPost({required this.id, this.text, this.imageUrl, this.productId, this.createdAt});

  factory SellerPost.fromDoc(String id, Map<String, dynamic> d) {
    final at = d['createdAt'];
    return SellerPost(
      id: id,
      text: d['text'] as String?,
      imageUrl: d['imageUrl'] as String?,
      productId: d['productId'] as String?,
      createdAt: at is Timestamp ? at.toDate() : null,
    );
  }

  final String id;
  final String? text;
  final String? imageUrl;
  final String? productId;
  final DateTime? createdAt;
}

/// Loads counts and posts; injected in tests.
abstract class FollowersSource {
  Future<int> followers();
  Future<int> newFollowersSince(DateTime since);
  Stream<List<SellerPost>> posts();
  Future<void> deletePost(String id);
}

class _FirestoreFollowers implements FollowersSource {
  _FirestoreFollowers(this.uid);
  final String uid;
  static const int _postLimit = 50;
  final _db = FirebaseFirestore.instance;

  Query<Map<String, dynamic>> get _follows => _db.collection('follows').where('sellerId', isEqualTo: uid);

  @override
  Future<int> followers() async => (await _follows.count().get()).count ?? 0;

  @override
  Future<int> newFollowersSince(DateTime since) async =>
      (await _follows.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(since)).count().get()).count ?? 0;

  @override
  Stream<List<SellerPost>> posts() => _db
      .collection('business_posts')
      .where('sellerId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(_postLimit)
      .snapshots()
      .map((s) => [for (final d in s.docs) SellerPost.fromDoc(d.id, d.data())]);

  @override
  Future<void> deletePost(String id) => _db.collection('business_posts').doc(id).delete();
}

/// M-04 Followers & posts (ADR §10.6, SELLER-FOLLOWERS-1): how many buyers
/// follow the store (and how many joined in 30 days) and the seller's own
/// posts, with delete and a way to write a new one. Follower identities are
/// not shown — only counts.
class FollowersScreen extends StatefulWidget {
  const FollowersScreen({super.key, this.source, this.now});
  final FollowersSource? source;
  final DateTime? now;

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  static const Duration _window = Duration(days: 30);
  FollowersSource? _source;
  Future<(int, int)>? _counts;

  @override
  void initState() {
    super.initState();
    _source = widget.source;
    if (_source == null) {
      final uid = context.read<SellerAuthProvider>().currentUser?.uid;
      if (uid != null) _source = _FirestoreFollowers(uid);
    }
    _loadCounts();
  }

  void _loadCounts() {
    final s = _source;
    if (s == null) return;
    final since = (widget.now ?? DateTime.now()).subtract(_window);
    _counts = Future.wait([s.followers(), s.newFollowersSince(since)]).then((v) => (v[0], v[1]));
  }

  Future<void> _delete(SellerPost post) async {
    final l10n = AppLocalizations.of(context);
    final yes = await wsConfirm(
      context,
      title: l10n.postsDeleteTitle,
      message: l10n.postsDeleteBody,
      confirmLabel: l10n.productDelete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!yes || !mounted) return;
    try {
      await _source!.deletePost(post.id);
      if (mounted) WsToast.show(context, l10n.postsDeleted, tone: WsToastTone.success);
    } catch (e) {
      debugPrint('Post delete failed: $e');
      if (mounted) WsToast.show(context, l10n.postFailed, tone: WsToastTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = context.ws;
    final text = context.wsText;
    final source = _source;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: l10n.back, icon: const Icon(AgIcons.arrowLeft), onPressed: () => Navigator.of(context).maybePop()),
        title: Text(l10n.followersTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreatePostScreen())),
        icon: const Icon(AgIcons.add),
        label: Text(l10n.productNewPost),
      ),
      body: source == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(WsSpace.page, WsSpace.page, WsSpace.page, WsSpace.s64 + WsSpace.s32),
              children: [
                FutureBuilder<(int, int)>(
                  future: _counts,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      debugPrint('Follower counts failed: ${snap.error}');
                      return SaInfoBanner(variant: SaBannerVariant.error, message: l10n.followersLoadFailed);
                    }
                    final c = snap.data;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(WsSpace.s16),
                        child: Row(children: [
                          Icon(AgIcons.users, color: t.primary, size: WsIconSize.feature),
                          const SizedBox(width: WsSpace.s16),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c == null ? '—' : AgFormat.count(c.$1),
                                  style: text.headlineMedium!.copyWith(fontFeatures: WsType.tabularFigures)),
                              Text(l10n.followersCount, style: text.bodySmall!.copyWith(color: t.textSecondary)),
                              if (c != null && c.$2 > 0)
                                Text(l10n.followersNew(c.$2), style: text.labelMedium!.copyWith(color: t.successFg)),
                            ]),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
                const SizedBox(height: WsSpace.s24),
                Text(l10n.postsTitle, style: text.titleMedium),
                const SizedBox(height: WsSpace.s8),
                StreamBuilder<List<SellerPost>>(
                  stream: source.posts(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      debugPrint('Posts failed: ${snap.error}');
                      return SaInfoBanner(variant: SaBannerVariant.error, message: l10n.followersLoadFailed);
                    }
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final posts = snap.data!;
                    if (posts.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: WsSpace.s24),
                        child: Text(l10n.postsEmpty, style: text.bodyMedium!.copyWith(color: t.textSecondary), textAlign: TextAlign.center),
                      );
                    }
                    return Column(children: [
                      for (final p in posts)
                        Card(
                          margin: const EdgeInsets.only(bottom: WsSpace.s8),
                          clipBehavior: Clip.antiAlias,
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            if (p.imageUrl != null)
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.network(p.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => ColoredBox(color: t.surfaceSunken)),
                              ),
                            ListTile(
                              title: Text(p.text?.isNotEmpty == true ? p.text! : l10n.postsNoText, style: text.bodyMedium),
                              subtitle: p.createdAt == null ? null : Text(AgFormat.dateTime(p.createdAt!), style: text.bodySmall),
                              trailing: IconButton(
                                tooltip: l10n.productDelete,
                                icon: Icon(AgIcons.delete, color: t.errorFg),
                                onPressed: () => _delete(p),
                              ),
                            ),
                          ]),
                        ),
                    ]);
                  },
                ),
              ],
            ),
    );
  }
}
