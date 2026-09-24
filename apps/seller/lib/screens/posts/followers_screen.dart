import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design_system/design_system.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/seller_product_provider.dart';
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
    final yes = await sellerConfirm(
      context,
      icon: SellerIcons.delete,
      title: l10n.postsDeleteTitle,
      message: l10n.postsDeleteBody,
      confirmLabel: l10n.productDelete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!yes || !mounted) return;
    try {
      await _source!.deletePost(post.id);
      if (mounted) SellerToast.show(context, l10n.postsDeleted, tone: SellerToastTone.success);
    } catch (e) {
      debugPrint('Post delete failed: $e');
      if (mounted) SellerToast.show(context, l10n.postFailed, tone: SellerToastTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = context.text;
    final source = _source;
    final products = context.watch<SellerProductProvider>().allProducts;
    String? productName(String? id) => id == null ? null : products.where((p) => p.id == id).firstOrNull?.name;
    return Scaffold(
      appBar: SellerAppBar.detail(context, title: l10n.followersTitle),
      body: source == null
          ? const SizedBox.shrink()
          : SellerPage(
              gap: SellerSpace.s16,
              footer: SellerButton.tonal(
                label: l10n.productNewPost,
                icon: SellerIcons.add,
                expand: true,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => const CreatePostScreen())),
              ),
              children: [
                FutureBuilder<(int, int)>(
                  future: _counts,
                  builder: (context, snap) {
                    if (snap.hasError) {
                      debugPrint('Follower counts failed: ${snap.error}');
                      return SellerBanner(tone: SellerTone.danger, message: l10n.followersLoadFailed);
                    }
                    final c = snap.data;
                    return SellerCard(
                      tone: SellerCardTone.mint,
                      child: Row(children: [
                        const SellerIconTile(icon: SellerIcons.users, circle: true, size: SellerSize.avatarLg),
                        const SizedBox(width: SellerSpace.s16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c == null ? '—' : SellerFormat.count(c.$1), style: text.displayLarge!.tabular),
                            Text(l10n.followersCount, style: text.bodyMedium!.copyWith(color: context.colors.textPrimary)),
                            if (c != null && c.$2 > 0) ...[
                              const SizedBox(height: SellerSpace.s4),
                              SellerDelta(trend: SellerTrend.up, label: l10n.followersNew(c.$2)),
                            ],
                          ]),
                        ),
                      ]),
                    );
                  },
                ),
                SellerSectionHeader(title: l10n.postsTitle),
                StreamBuilder<List<SellerPost>>(
                  stream: source.posts(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      debugPrint('Posts failed: ${snap.error}');
                      return SellerBanner(tone: SellerTone.danger, message: l10n.followersLoadFailed);
                    }
                    if (!snap.hasData) return SellerSkeletonList(count: 2, label: l10n.dsLoading);
                    final posts = snap.data!;
                    if (posts.isEmpty) return SellerEmptyState(icon: SellerIcons.post, title: l10n.postsEmpty, compact: true);
                    return Column(children: [
                      for (final p in posts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: SellerSpace.s12),
                          child: SellerCard(
                            padding: EdgeInsets.zero,
                            clip: true,
                            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              if (p.imageUrl != null)
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: SellerImage(url: p.imageUrl, size: double.infinity, height: double.infinity, radius: 0),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(SellerSpace.s16, SellerSpace.s12, SellerSpace.s4, SellerSpace.s12),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(p.text?.isNotEmpty == true ? p.text! : l10n.postsNoText, style: text.bodyLarge),
                                      if (p.createdAt != null) ...[
                                        const SizedBox(height: SellerSpace.s4),
                                        Text(SellerFormat.dateTime(p.createdAt!), style: text.bodyMedium),
                                      ],
                                      if (productName(p.productId) != null) ...[
                                        const SizedBox(height: SellerSpace.s8),
                                        SellerStatusBadge(label: l10n.postTaggedProduct(productName(p.productId)!), tone: SellerTone.brand, icon: SellerIcons.tag),
                                      ],
                                    ]),
                                  ),
                                  SellerIconButton(icon: SellerIcons.delete, label: l10n.productDelete, color: context.colors.danger, onPressed: () => _delete(p)),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                    ]);
                  },
                ),
              ],
            ),
    );
  }
}
